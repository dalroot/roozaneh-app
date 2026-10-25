import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:roozaneh/core/localization/translations.dart';
import 'package:roozaneh/core/model/constants.dart';
import 'package:roozaneh/core/preferences/general_preferences.dart';
import 'package:roozaneh/core/utils/country_helper.dart';
import 'package:roozaneh/features/connection/model/connection_status.dart';
import 'package:roozaneh/features/connection/notifier/connection_notifier.dart';
import 'package:roozaneh/features/proxy/active/ip_widget.dart';
import 'package:roozaneh/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:roozaneh/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:roozaneh/utils/utils.dart';

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final liveGroup = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final offlineGroup = ref.watch(offlineOutboundsProvider).valueOrNull;
    final group = liveGroup ?? offlineGroup;

    final isConnected = ref.watch(
      connectionNotifierProvider.select((value) => value.valueOrNull == const Connected()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("انتخاب کشور و لوکیشن"),
        centerTitle: true,
      ),
      floatingActionButton: isConnected
          ? FloatingActionButton.extended(
              onPressed: () async => await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest("select"),
              icon: const Icon(FluentIcons.flash_24_filled),
              label: const Text("تست پینگ زنده"),
            )
          : null,
      body: group != null && group.items.isNotEmpty
          ? _buildCountryList(context, ref, group, isConnected)
          : _buildEmptyState(context, t, isDark),
    );
  }

  Widget _buildCountryList(BuildContext context, WidgetRef ref, OutboundGroup group, bool isConnected) {
    final theme = Theme.of(context);

    final validItems = group.items.where((proxy) {
      if (proxy.tagDisplay.contains("ERROR") || proxy.tagDisplay.contains("Unknown parse")) return false;
      return true;
    }).toList();

    final countries = groupProxiesByCountry(validItems, group.selected);

    // Find auto-select proxy (lowest / balance / select)
    final autoProxy = validItems.firstWhere(
      (p) => p.tag.contains("lowest") || p.tag.contains("balance") || p.tag == "select" || p.type == "urltest",
      orElse: () => validItems.first,
    );

    final selectedCountryPref = ref.watch(Preferences.selectedCountryCode);
    final isAutoSelected = selectedCountryPref.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          children: [
            // 1. Smart Auto-Select Item
            _buildLocationCard(
              context: context,
              title: "⚡ سریع‌ترین اتصال (هوشمند خودکار)",
              subtitle: "اتصال به بهترین و کم‌ترین پینگ بدون قطعی",
              flagWidget: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A3C).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFF7A3C),
                  size: 22,
                ),
              ),
              delay: autoProxy.urlTestDelay,
              isSelected: isAutoSelected,
              onTap: () async {
                await ref.read(Preferences.selectedCountryCode.notifier).update("");
                if (isConnected) {
                  await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(group.tag, autoProxy.tag);
                }
                if (context.mounted) context.pop();
              },
            ),

            const Gap(14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                "کشورهای موجود در اشتراک شما (${countries.length} کشور)",
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Gap(6),

            // 2. Country-Level Rows
            ...countries.map((country) {
              final isCountrySelected = selectedCountryPref == country.code;
              return _buildLocationCard(
                context: context,
                title: country.nameFa,
                subtitle: country.nameEn.isNotEmpty && country.nameEn != country.nameFa
                    ? country.nameEn
                    : "${country.proxies.length} سرور فعال",
                flagWidget: IPCountryFlag(
                  countryCode: country.code,
                  size: 36,
                ),
                delay: country.bestDelay,
                isSelected: isCountrySelected,
                onTap: () async {
                  await ref.read(Preferences.selectedCountryCode.notifier).update(country.code);
                  if (isConnected) {
                    await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(group.tag, country.primaryProxy.tag);
                  }
                  if (context.mounted) context.pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TranslationsEn t, bool isDark) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.public_rounded,
                size: 54,
                color: Color(0xFFFF7A3C),
              ),
              const Gap(14),
              Text(
                "اشتراک فعالی یافت نشد",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Text(
                "برای مشاهده لیست کشورها و اتصال، ابتدا لینک اشتراک خود را اضافه کنید.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(20),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text("بازگشت به صفحه اصلی"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A3C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget flagWidget,
    required int delay,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPing = ConnectionConst.isValidDelay(delay);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFFFF7A3C).withValues(alpha: 0.18) : const Color(0xFFFFF0E6))
            : (isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF7A3C)
              : theme.colorScheme.outline.withValues(alpha: 0.12),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFF7A3C).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: flagWidget,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? const Color(0xFFFF7A3C) : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (delay > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasPing ? Colors.green : Colors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: hasPing ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      hasPing ? "$delay ms" : "خطا",
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasPing ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFFFF7A3C) : theme.colorScheme.outline.withValues(alpha: 0.4),
              size: 22,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
