import 'dart:io';

import 'package:dio/dio.dart';
import 'package:roozaneh/core/haptic/haptic_service.dart';
import 'package:roozaneh/core/localization/translations.dart';
import 'package:roozaneh/core/preferences/general_preferences.dart';
import 'package:roozaneh/core/router/dialog/dialog_notifier.dart';
import 'package:roozaneh/core/utils/country_helper.dart';
import 'package:roozaneh/features/connection/data/connection_data_providers.dart';
import 'package:roozaneh/features/connection/data/connection_repository.dart';
import 'package:roozaneh/features/connection/model/connection_status.dart';
import 'package:roozaneh/features/profile/model/profile_entity.dart';
import 'package:roozaneh/features/profile/notifier/active_profile_notifier.dart';
import 'package:roozaneh/features/proxy/data/proxy_data_providers.dart';
import 'package:roozaneh/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'connection_notifier.g.dart';

final connectionStepMessageProvider = StateProvider<String>((ref) => "");

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  @override
  Stream<ConnectionStatus> build() async* {
    if (Platform.isIOS) {
      await _connectionRepo.setup().mapLeft((l) {
        loggy.error("error setting up connection repository", l);
      }).run();
    }

    listenSelf((previous, next) async {
      if (previous == next) return;
      if (previous case AsyncData(:final value) when !value.isConnected) {
        if (next case AsyncData(value: final Connected _)) {
          if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
            if (await InAppReview.instance.isAvailable()) {
              InAppReview.instance.requestReview();
              ref.read(Preferences.storeReviewedByUser.notifier).update(true);
            }
          }
        }
      }
    });

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        await reconnect(next);
      }
    });

    yield* _connectionRepo.watchConnectionStatus().doOnData((event) {
      if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
        Future.microtask(() => ref.read(Preferences.startedByUser.notifier).update(false));
      }
      loggy.info("connection status: ${event.format()}");
    });
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  Future<void> mayConnect() async {
    if (state case AsyncData(:final value)) {
      if (value case Disconnected()) return _connect();
    }
  }

  Future<void> toggleConnection() async {
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (state case AsyncError()) {
      await haptic.lightImpact();
      await _connect();
    } else if (state case AsyncData(:final value)) {
      switch (value) {
        case Disconnected():
          await haptic.lightImpact();
          await ref.read(Preferences.startedByUser.notifier).update(true);
          await _connect();
        case Connected():
          // default:
          await haptic.mediumImpact();
          await ref.read(Preferences.startedByUser.notifier).update(false);
          await _disconnect();
        default:
          loggy.warning("switching status, debounce");
      }
    }
  }

  Future<void> reconnect(ProfileEntity? profile) async {
    if (state case AsyncData(:final value) when value == const Connected()) {
      if (profile == null) {
        loggy.info("no active profile, disconnecting");
        return _disconnect();
      }
      loggy.info("active profile changed, reconnecting");
      await ref.read(Preferences.startedByUser.notifier).update(true);
      await _connectionRepo.reconnect(profile, ref.read(Preferences.disableMemoryLimit)).mapLeft((err) async {
        loggy.warning("error reconnecting", err);
        state = AsyncError(err, StackTrace.current);
        await ref
            .read(dialogNotifierProvider.notifier)
            .showCustomAlertFromErr(err.present(ref.read(translationsProvider).requireValue));
      }).run();
    }
  }

  Future<void> abortConnection() async {
    if (state case AsyncData(:final value)) {
      switch (value) {
        case Connected() || Connecting():
          loggy.debug("aborting connection");
          await _disconnect();
        default:
      }
    }
  }

  final _singleStart = SingleCall();

  Future<void> _connect() async {
    _singleStart.run(
      () async {
        await _connectThrottled();
      },
      onIgnored: () {
        loggy.debug("connect called while another connect/disconnect is still running, ignoring");
      },
    );
  }

  Future<void> _connectThrottled() async {
    final activeProfile = await ref.read(activeProfileProvider.future);
    if (activeProfile == null) {
      loggy.info("no active profile, not connecting");
      return;
    }
    final t = ref.read(translationsProvider).requireValue;
    final dialogNotifier = ref.read(dialogNotifierProvider.notifier);
    final startedByUser = ref.read(Preferences.startedByUser.notifier);
    final stepNotifier = ref.read(connectionStepMessageProvider.notifier);
    final disableMemoryLimit = ref.read(Preferences.disableMemoryLimit);
    final selectedCountry = ref.read(Preferences.selectedCountryCode);
    final countryName = selectedCountry.isNotEmpty ? (kCountryNames[selectedCountry]?.$1 ?? selectedCountry) : "";
    final proxyRepo = ref.read(proxyRepositoryProvider);

    try {
      // 1. Starting core
      stepNotifier.state = "در حال راه‌اندازی هسته شبکه...";

      final connectResult = await _connectionRepo.connect(activeProfile, disableMemoryLimit).run();
      if (connectResult.isLeft()) {
        final err = connectResult.getLeft().toNullable()!;
        loggy.warning("error connecting: $err");
        stepNotifier.state = "";
        Future.microtask(() async {
          await dialogNotifier.showCustomAlertFromErr(err.present(t));
        });
        if (err.toString().contains("panic")) {
          await Sentry.captureException(Exception(err.toString()));
        }
        await startedByUser.update(false);
        state = AsyncData(Disconnected(err));
        return;
      }

      // 2. Finding fastest server (either overall or specifically for selected country)
      if (selectedCountry.isNotEmpty) {
        stepNotifier.state = "در حال یافتن سریع‌ترین سرور $countryName...";
      } else {
        stepNotifier.state = "در حال یافتن سریع‌ترین سرور...";
      }

      // Ping test on core
      await proxyRepo.urlTest("select").run();
      await Future.delayed(const Duration(milliseconds: 1000));

      // Auto-select from chosen country's configs
      if (selectedCountry.isNotEmpty) {
        try {
          final proxies = await proxyRepo.watchProxies().first;
          final group = proxies.getOrElse((_) => null);
          if (group != null && group.items.isNotEmpty) {
            final countryGroups = groupProxiesByCountry(group.items, group.selected);
            CountryGroup? match;
            for (final c in countryGroups) {
              if (c.code == selectedCountry) {
                match = c;
                break;
              }
            }
            if (match != null && match.primaryProxy.tag.isNotEmpty) {
              stepNotifier.state = "در حال برقراری اتصال به $countryName...";
              await proxyRepo.selectProxy(group.tag, match.primaryProxy.tag).run();
              await Future.delayed(const Duration(milliseconds: 600));
            }
          }
        } catch (e) {
          loggy.warning("error auto-selecting country proxy: $e");
        }
      } else {
        stepNotifier.state = "در حال برقراری اتصال امن...";
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 3. Verifying actual data flow (Real Connectivity Check)
      stepNotifier.state = "بررسی تبادل داده و سلامت اتصال...";

      bool isDataFlowing = false;
      final cancelToken = CancelToken();
      try {
        final ipResult = await proxyRepo
            .getCurrentIpInfo(cancelToken)
            .run()
            .timeout(const Duration(seconds: 8));
        if (ipResult.isRight()) {
          isDataFlowing = true;
        }
      } catch (_) {
        isDataFlowing = false;
      }

      stepNotifier.state = "";

      if (!isDataFlowing) {
        loggy.warning("connection verification failed: zero real data flow");
        await _disconnect();
        Future.microtask(() async {
          await dialogNotifier.showCustomAlertFromErr((
            message: "اتصال ناموفق: هیچ تبادل داده‌ای با سرورهای انتخابی برقرار نشد.\nلطفاً کشور یا سرور دیگری را انتخاب نمایید.",
            type: "ConnectionError",
          ));
        });
        await startedByUser.update(false);
        state = const AsyncData(Disconnected());
        return;
      }

      loggy.info("connection successfully verified with genuine data flow!");
    } catch (e, st) {
      loggy.error("unexpected error during connection stages: $e", e, st);
      stepNotifier.state = "";
      await _disconnect();
      Future.microtask(() async {
        await dialogNotifier.showCustomAlertFromErr((
          message: "خطا در فرآیند اتصال: $e",
          type: "ConnectionError",
        ));
      });
      await startedByUser.update(false);
      state = const AsyncData(Disconnected());
    }
  }

  Future<void> _disconnect() async {
    final t = ref.read(translationsProvider).requireValue;
    final dialogNotifier = ref.read(dialogNotifierProvider.notifier);
    final stepNotifier = ref.read(connectionStepMessageProvider.notifier);
    stepNotifier.state = "";

    await _singleStart.run(
      () async {
        await _connectionRepo.disconnect().mapLeft((err) {
          loggy.warning("error disconnecting", err);
          dialogNotifier.showCustomAlertFromErr(err.present(t));
          state = AsyncError(err, StackTrace.current);
        }).run();

        // Wait for OS socket release to prevent TUNSETIFF busy error
        if (Platform.isLinux) {
          await Future.delayed(const Duration(milliseconds: 600));
        } else {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      },
      onIgnored: () {
        loggy.debug("disconnect called while another operation is in progress, ignoring");
      },
    );
  }
}

@Riverpod(keepAlive: true)
bool serviceRunning(Ref ref) {
  // ref.watch(coreRestartSignalProvider);
  return ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
}

class SingleCall {
  bool _running = false;

  Future<T> run<T>(Future<T> Function() task, {required T onIgnored}) async {
    if (_running) return onIgnored;

    _running = true;
    try {
      return await task();
    } finally {
      _running = false;
    }
  }
}
