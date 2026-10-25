import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:roozaneh/core/haptic/haptic_service.dart';
import 'package:roozaneh/core/localization/translations.dart';
import 'package:roozaneh/core/preferences/general_preferences.dart';
import 'package:roozaneh/core/router/dialog/dialog_notifier.dart';
import 'package:roozaneh/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:roozaneh/features/common/general_pref_tiles.dart';
import 'package:roozaneh/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:roozaneh/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:roozaneh/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
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
            colorFilter: Theme.of(context).brightness == Brightness.dark
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
                _buildCardSection(
                  context: context,
                  title: "ظاهر و زبان",
                  children: const [
                    LocalePrefTile(),
                    Divider(height: 1, indent: 16, endIndent: 16),
                    ThemeModePrefTile(),
                  ],
                ),
                if (PlatformUtils.isDesktop || PlatformUtils.isAndroid)
                  _buildCardSection(
                    context: context,
                    title: "رفتار برنامه",
                    children: [
                      if (PlatformUtils.isDesktop) ...[
                        const ClosingPrefTile(),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile.adaptive(
                          title: Text(t.pages.settings.general.autoStart),
                          secondary: const Icon(Icons.auto_mode_rounded),
                          value: ref.watch(autoStartNotifierProvider).asData?.value ?? false,
                          onChanged: (value) async => value
                              ? await ref.read(autoStartNotifierProvider.notifier).enable()
                              : await ref.read(autoStartNotifierProvider.notifier).disable(),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile.adaptive(
                          title: Text(t.pages.settings.general.silentStart),
                          secondary: const Icon(Icons.visibility_off_rounded),
                          value: ref.watch(Preferences.silentStart),
                          onChanged: ref.read(Preferences.silentStart.notifier).update,
                        ),
                      ],
                      if (PlatformUtils.isAndroid) ...[
                        SwitchListTile.adaptive(
                          title: Text(t.pages.settings.general.dynamicNotification),
                          secondary: const Icon(Icons.speed_rounded),
                          value: ref.watch(Preferences.dynamicNotification),
                          onChanged: ref.read(Preferences.dynamicNotification.notifier).update,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile.adaptive(
                          title: Text(t.pages.settings.general.hapticFeedback),
                          secondary: const Icon(Icons.vibration_rounded),
                          value: ref.watch(hapticServiceProvider),
                          onChanged: ref.read(hapticServiceProvider.notifier).updatePreference,
                        ),
                      ],
                    ],
                  ),
                _buildCardSection(
                  context: context,
                  title: "شبکه و اتصال",
                  children: [
                    SwitchListTile.adaptive(
                      title: Text(t.pages.settings.general.autoIpCheck),
                      value: ref.watch(Preferences.autoCheckIp),
                      secondary: const Icon(Icons.flag_rounded),
                      onChanged: ref.read(Preferences.autoCheckIp.notifier).update,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    const EnableAnalyticsPrefTile(),
                  ],
                ),
                if (PlatformUtils.isIOS)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)
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
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(t.pages.settings.resetTunnel),
                      leading: const Icon(Icons.autorenew_rounded),
                      onTap: () async {
                        await ref.read(resetTunnelNotifierProvider.notifier).run();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCardSection({
  required BuildContext context,
  required String title,
  required List<Widget> children,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7A3C),
              ),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF7A3C).withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: const Color(0xFFFF7A3C), size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: subtitle != null
              ? DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: subtitle!,
                )
              : null,
          trailing: Icon(
            Icons.chevron_left_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () => context.go(namedLocation),
        ),
      ),
    );
  }
}
