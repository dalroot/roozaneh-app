import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:roozaneh/core/app_info/app_info_provider.dart';
import 'package:roozaneh/core/localization/translations.dart';
import 'package:roozaneh/core/model/constants.dart';
import 'package:roozaneh/core/model/failures.dart';
import 'package:roozaneh/core/router/dialog/dialog_notifier.dart';
import 'package:roozaneh/core/widget/adaptive_icon.dart';
import 'package:roozaneh/features/app_update/notifier/app_update_notifier.dart';
import 'package:roozaneh/features/app_update/notifier/app_update_state.dart';
import 'package:roozaneh/gen/assets.gen.dart';
import 'package:roozaneh/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final appUpdate = ref.watch(appUpdateNotifierProvider);

    ref.listen(appUpdateNotifierProvider, (_, next) async {
      if (!context.mounted) return;
      switch (next) {
        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
          return await ref
              .read(dialogNotifierProvider.notifier)
              .showNewVersion(currentVersion: appInfo.presentVersion, newVersion: versionInfo, canIgnore: false);
        case AppUpdateStateError(:final error):
          return CustomToast.error(t.presentShortError(error)).show(context);
        case AppUpdateStateNotAvailable():
          return CustomToast.success(t.pages.about.notAvailableMsg).show(context);
      }
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget buildTileCard({
      required String title,
      required Widget trailing,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
                : const Color(0xFFF0E5DE),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: icon != null
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF7A3C).withValues(alpha: 0.1),
                    ),
                    child: Icon(icon, color: const Color(0xFFFF7A3C), size: 20),
                  )
                : null,
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.about.title),
        actions: [
          PopupMenuButton(
            icon: Icon(AdaptiveIcon(context).more),
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text(t.common.addToClipboard),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appInfo.format()));
                  },
                ),
              ];
            },
          ),
          const Gap(8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/world_map.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
            colorFilter: isDark
                ? ColorFilter.mode(Colors.white.withValues(alpha: .1), BlendMode.srcIn)
                : ColorFilter.mode(Colors.grey.withValues(alpha: 0.8), BlendMode.srcATop),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Top Header Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A3C).withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Assets.images.logo.svg(width: 56, height: 56),
                          const Gap(16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.common.appTitle,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                "ارتباط آزاد، امن و سریع با یک کلیک",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFF7A3C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : const Color(0xFFFFF7F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFE4D6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "روزنه یک ابزار متن‌باز، قدرتمند و بدون پیچیدگی است که هدف آن ایجاد دسترسی پایدار، امن و آزاد به اینترنت بدون نیاز به هیچ تنظیمات دشوار می‌باشد.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Items Cards
                if (appInfo.release.allowCustomUpdateChecker)
                  buildTileCard(
                    title: t.pages.about.checkForUpdate,
                    icon: FluentIcons.arrow_sync_24_regular,
                    trailing: switch (appUpdate) {
                      AppUpdateStateChecking() => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      _ => Icon(FluentIcons.arrow_sync_24_regular, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    },
                    onTap: () async {
                      final result = await ref.read(appUpdateNotifierProvider.notifier).check();
                      if (!context.mounted) return;
                      switch (result) {
                        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
                          await ref.read(dialogNotifierProvider.notifier).showNewVersion(
                                currentVersion: appInfo.presentVersion,
                                newVersion: versionInfo,
                                canIgnore: false,
                              );
                        case AppUpdateStateNotAvailable():
                          CustomToast.success(t.pages.about.notAvailableMsg).show(context);
                        case AppUpdateStateError(:final error):
                          CustomToast.error(t.presentShortError(error)).show(context);
                        default:
                          break;
                      }
                    },
                  ),
                buildTileCard(
                  title: "پشتیبانی و بازخورد",
                  icon: FluentIcons.chat_24_regular,
                  trailing: Icon(FluentIcons.open_24_regular, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async => await UriUtils.tryLaunch(Uri.parse("https://t.me/roozaneh_support")),
                ),
                buildTileCard(
                  title: t.pages.about.telegramChannel,
                  icon: FluentIcons.send_24_regular,
                  trailing: Icon(FluentIcons.open_24_regular, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async => await UriUtils.tryLaunch(Uri.parse(Constants.telegramChannelUrl)),
                ),
                buildTileCard(
                  title: t.pages.about.termsAndConditions,
                  icon: FluentIcons.document_text_24_regular,
                  trailing: Icon(FluentIcons.open_24_regular, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async => await UriUtils.tryLaunch(Uri.parse(Constants.termsAndConditionsUrl)),
                ),
                buildTileCard(
                  title: t.pages.about.privacyPolicy,
                  icon: FluentIcons.shield_24_regular,
                  trailing: Icon(FluentIcons.open_24_regular, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async => await UriUtils.tryLaunch(Uri.parse(Constants.privacyPolicyUrl)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
