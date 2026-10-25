import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:roozaneh/core/model/constants.dart';
import 'package:roozaneh/core/preferences/general_preferences.dart';
import 'package:roozaneh/core/utils/country_helper.dart';
import 'package:roozaneh/features/connection/model/connection_status.dart';
import 'package:roozaneh/features/connection/notifier/connection_notifier.dart';
import 'package:roozaneh/features/proxy/active/active_proxy_notifier.dart';
import 'package:roozaneh/features/proxy/active/ip_widget.dart';
import 'package:roozaneh/features/stats/notifier/stats_notifier.dart';
import 'package:roozaneh/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:roozaneh/utils/custom_loggers.dart';
import 'package:roozaneh/utils/number_formatters.dart';

class ActiveProxyFooter extends HookConsumerWidget with InfraLogger {
  const ActiveProxyFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(
      connectionNotifierProvider.select((value) => value.valueOrNull ?? const Disconnected()),
    );

    final activeProxy = ref.watch(activeProxyNotifierProvider.select((value) => value.valueOrNull));
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isConnected = connectionState == const Connected() && activeProxy != null;

    // Track connection session start time
    final connectionStart = useState<DateTime?>(null);
    useEffect(() {
      if (isConnected) {
        connectionStart.value ??= DateTime.now();
      } else {
        connectionStart.value = null;
      }
      return null;
    }, [isConnected]);

    // Timer that ticks every second while connected to update duration
    final ticker = useState<int>(0);
    useEffect(() {
      if (!isConnected) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        ticker.value++;
      });
      return timer.cancel;
    }, [isConnected]);

    final duration = connectionStart.value != null
        ? DateTime.now().difference(connectionStart.value!)
        : Duration.zero;

    final String durationText;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      durationText = "$hours:$minutes:$seconds";
    } else {
      durationText = "$minutes:$seconds";
    }

    final totalBytes = (stats.uplinkTotal + stats.downlinkTotal).toInt();
    final trafficText = totalBytes > 0 ? totalBytes.size() : "۰ B";

    final selectedCountryPref = ref.watch(Preferences.selectedCountryCode);
    final String countryCode;
    final String countryName;
    if (activeProxy != null) {
      countryCode = detectCountryCode(activeProxy.tagDisplay, activeProxy.ipinfo.countryCode);
      final countryInfo = kCountryNames[countryCode];
      if (countryInfo != null) {
        countryName = countryInfo.$1;
      } else if (activeProxy.tagDisplay.toLowerCase().contains("lowest") || activeProxy.tagDisplay.toLowerCase().contains("balance") || activeProxy.tagDisplay == "select") {
        countryName = "اتصال هوشمند (بهترین سرور)";
      } else if (activeProxy.tagDisplay.isNotEmpty) {
        countryName = activeProxy.tagDisplay;
      } else {
        countryName = "اتصال هوشمند (سریع‌ترین سرور)";
      }
    } else if (selectedCountryPref.isNotEmpty) {
      countryCode = selectedCountryPref;
      countryName = kCountryNames[selectedCountryPref]?.$1 ?? selectedCountryPref;
    } else {
      countryCode = "";
      countryName = "اتصال هوشمند (سریع‌ترین سرور)";
    }

    final hasPing = activeProxy != null && activeProxy.urlTestDelay > 0 && ConnectionConst.isValidDelay(activeProxy.urlTestDelay);
    final delayText = hasPing ? "${activeProxy.urlTestDelay} ms" : "---";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 6),
          child: Text(
            "موقعیت سرور",
            style: theme.textTheme.labelMedium?.copyWith(
              color: isConnected ? const Color(0xFFFF7A3C) : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outline.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.015),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Server Selector Tile
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(20),
                    bottom: Radius.circular(isConnected ? 0 : 20),
                  ),
                  onTap: () => context.goNamed('proxies'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.08),
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IPCountryFlag(
                              countryCode: countryCode,
                              organization: activeProxy?.ipinfo.org ?? "",
                              size: 32,
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                countryName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                isConnected && activeProxy.ipinfo.ip.isNotEmpty
                                    ? activeProxy.ipinfo.ip
                                    : "تغییر و انتخاب سرور",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Integrated Live Stats Strip (Ping, Duration, Traffic) when connected
              if (isConnected) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? theme.colorScheme.outline.withValues(alpha: 0.12)
                      : theme.colorScheme.outline.withValues(alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      // 1. Ping
                      Expanded(
                        child: _StatMetric(
                          label: "پینگ",
                          value: delayText,
                          valueColor: hasPing ? const Color(0xFF10B981) : null,
                          icon: Icons.speed_rounded,
                          iconColor: const Color(0xFF10B981),
                        ),
                      ),
                      const Gap(6),
                      // 2. Duration Timer
                      Expanded(
                        child: _StatMetric(
                          label: "زمان اتصال",
                          value: durationText,
                          valueColor: const Color(0xFFF59E0B),
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const Gap(6),
                      // 3. Total Data Traffic
                      Expanded(
                        child: _StatMetric(
                          label: "حجم مصرفی",
                          value: trafficText,
                          valueColor: const Color(0xFF3B82F6),
                          icon: Icons.data_usage_rounded,
                          iconColor: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const Gap(3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Gap(3),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// class _StatsColumn extends HookConsumerWidget {
//   const _StatsColumn();

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final t = ref.watch(translationsProvider).requireValue;
//     final stats = ref.watch(statsNotifierProvider).value;

//     return Directionality(
//       textDirection: TextDirection.values[(Directionality.of(context).index + 1) % TextDirection.values.length],
//       child: Flexible(
//         child: Column(
//           children: [
//             _InfoProp(
//               icon: FluentIcons.arrow_bidirectional_up_down_20_regular,
//               text: (stats?.downlinkTotal ?? 0).size(),
//               semanticLabel: t.stats.totalTransferred,
//             ),
//             const Gap(8),
//             _InfoProp(
//               icon: FluentIcons.arrow_download_20_regular,
//               text: (stats?.downlink ?? 0).speed(),
//               semanticLabel: t.stats.speed,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _InfoProp extends StatelessWidget {
//   const _InfoProp({
//     required this.icon,
//     required this.text,
//     this.semanticLabel,
//   });

//   final IconData icon;
//   final String text;
//   final String? semanticLabel;

//   @override
//   Widget build(BuildContext context) {
//     return Semantics(
//       label: semanticLabel,
//       child: Row(
//         children: [
//           Icon(icon),
//           const Gap(8),
//           Flexible(
//             child: Text(
//               text,
//               style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFamily: FontFamily.emoji),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
