import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:roozaneh/core/model/constants.dart';
import 'package:roozaneh/core/router/dialog/dialog_notifier.dart';
import 'package:roozaneh/features/connection/model/connection_status.dart';
import 'package:roozaneh/features/connection/notifier/connection_notifier.dart';
import 'package:roozaneh/features/home/widget/sun_widget.dart';
import 'package:roozaneh/features/profile/notifier/active_profile_notifier.dart';
import 'package:roozaneh/features/profile/notifier/profile_notifier.dart';
import 'package:roozaneh/features/settings/notifier/config_option/config_option_notifier.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;
    final stepMessage = ref.watch(connectionStepMessageProvider);
    final isVerifying = stepMessage.isNotEmpty;

    final isConnecting = connectionStatus.isLoading || connectionStatus.valueOrNull is Connecting || isVerifying;
    final isDisconnecting = connectionStatus.valueOrNull is Disconnecting;
    final isConnected = connectionStatus.valueOrNull == const Connected() && !isVerifying;

    return _ConnectionButton(
      isConnecting: isConnecting,
      isDisconnecting: isDisconnecting,
      isConnected: isConnected,
      enabled: !isConnecting && !isDisconnecting,
      stepMessage: stepMessage,
      onTap: () async {
        if (isConnecting || isDisconnecting) return;

        if (isConnected) {
          if (requiresReconnect == true &&
              await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            final activeProfile = await ref.read(activeProfileProvider.future);
            return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        } else {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            await ref.read(addProfileNotifierProvider.notifier).addClipboard(Constants.defaultSubUrl);
          }
          if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
          }
        }
      },
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.isConnecting,
    required this.isDisconnecting,
    required this.isConnected,
    this.stepMessage = "",
  });

  final VoidCallback onTap;
  final bool enabled;
  final bool isConnecting;
  final bool isDisconnecting;
  final bool isConnected;
  final String stepMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final SunConnectionState sunState;
    if (isConnecting) {
      sunState = SunConnectionState.connecting;
    } else if (isDisconnecting) {
      sunState = SunConnectionState.disconnecting;
    } else if (isConnected) {
      sunState = SunConnectionState.connected;
    } else {
      sunState = SunConnectionState.disconnected;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Central 3D Glowing Sun with Orbital Rings & Sparkles
        RoozanehSunWidget(
          key: const ValueKey("home_connection_button"),
          connectionState: sunState,
          enabled: enabled,
          onTap: onTap,
          size: 175,
        ),

        const Gap(8),

        // 2. Status Dot & Text (Matching Mockup)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected
                    ? const Color(0xFF10B981)
                    : isConnecting
                        ? const Color(0xFFFF9E66)
                        : const Color(0xFFFF7A3C),
                boxShadow: [
                  BoxShadow(
                    color: (isConnected
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFF7A3C))
                        .withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const Gap(8),
            Text(
              isConnecting
                  ? (stepMessage.isNotEmpty ? stepMessage : "در حال اتصال...")
                  : isDisconnecting
                      ? "در حال قطع اتصال..."
                      : isConnected
                          ? "متصل است"
                          : "متصل نیست",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.3,
                color: isConnected
                    ? const Color(0xFF10B981)
                    : isConnecting
                        ? const Color(0xFFFF9E66)
                        : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),

        const Gap(4),

        // Subtitle
        Text(
          isConnecting
              ? (stepMessage.isNotEmpty ? "لطفاً چند لحظه صبر کنید..." : "در حال برقراری ارتباط امن و انتخاب سرور...")
              : isDisconnecting
                  ? "لطفاً چند لحظه صبر کنید"
                  : isConnected
                      ? "اتصال شما امن و پایدار است"
                      : "برای اتصال ضربه بزنید",
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),

        const Gap(14),

        // 3. Primary Action Button
        ElevatedButton(
          onPressed: (isConnecting || isDisconnecting) ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected
                ? const Color(0xFFF43F5E)
                : const Color(0xFFFF7A3C),
            disabledBackgroundColor: const Color(0xFFFF7A3C).withValues(alpha: 0.7),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            minimumSize: const Size(220, 48),
            elevation: (isConnecting || isDisconnecting) ? 0 : 3,
            shadowColor: (isConnected
                    ? const Color(0xFFF43F5E)
                    : const Color(0xFFFF7A3C))
                .withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: (isConnecting || isDisconnecting)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const Gap(10),
                    Text(
                      isConnecting ? "در حال اتصال..." : "در حال قطع...",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              : Text(
                  isConnected ? "قطع اتصال" : "اتصال",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
        ),
      ],
    );
  }
}
