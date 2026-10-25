import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:roozaneh/core/localization/translations.dart';
import 'package:roozaneh/core/router/adaptive_layout/shell_route_action.dart';
import 'package:roozaneh/core/router/go_router/routing_config_notifier.dart';
import 'package:roozaneh/gen/assets.gen.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
  });

  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FocusScope(
      child: Scaffold(
        extendBody: isMobileBreakpoint,
        body: isMobileBreakpoint
            ? navigationShell
            : SelectionArea(
                child: Row(
                  children: [
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        right: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Assets.images.logo.svg(height: 28),
                                    const Gap(10),
                                    Text(
                                      t.common.appTitle,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(20),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _desktopActions(t).length,
                                  separatorBuilder: (_, __) => const Gap(4),
                                  itemBuilder: (context, index) {
                                    final action = _desktopActions(t)[index];
                                    final selectedIndex = _getDesktopSelectedIndex(
                                      context,
                                      isMobileBreakpoint,
                                      showProfilesAction,
                                      navigationShell.currentIndex,
                                    );
                                    final isSelected = selectedIndex == index;

                                    return Material(
                                      color: isSelected
                                          ? (isDark ? const Color(0xFFFF7A3C).withValues(alpha: 0.15) : const Color(0xFFFFE8D6))
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _onDesktopTap(context, ref, index, isMobileBreakpoint, showProfilesAction),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Icon(
                                                action.icon,
                                                size: 20,
                                                color: isSelected
                                                    ? const Color(0xFFFF7A3C)
                                                    : theme.colorScheme.onSurfaceVariant,
                                              ),
                                              const Gap(14),
                                              Text(
                                                action.title,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xFFFF7A3C)
                                                      : theme.colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: navigationShell),
                  ],
                ),
              ),
        bottomNavigationBar: isMobileBreakpoint ? _buildMobileBottomNav(context, ref, isDark) : null,
      ),
    );
  }

  Widget _buildMobileBottomNav(BuildContext context, WidgetRef ref, bool isDark) {
    final currentIndex = navigationShell.currentIndex;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Home Item
            _buildNavItem(
              context: context,
              icon: Icons.home_rounded,
              isSelected: currentIndex == 0,
              onTap: () {
                if (currentIndex != 0) {
                  navigationShell.goBranch(0);
                }
              },
            ),

            // 2. Servers / Locations Item
            _buildNavItem(
              context: context,
              icon: Icons.public_rounded,
              isSelected: false,
              onTap: () {
                context.pushNamed('proxies');
              },
            ),

            // 3. Settings Item
            _buildNavItem(
              context: context,
              icon: Icons.settings_rounded,
              isSelected: currentIndex == 1,
              onTap: () {
                if (currentIndex != 1) {
                  navigationShell.goBranch(1);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFFFF7A3C).withValues(alpha: 0.2) : const Color(0xFFFFF0E6))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isSelected ? const Color(0xFFFF7A3C) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  int _getDesktopSelectedIndex(
    BuildContext context,
    bool isMobileBreakpoint,
    bool showProfilesAction,
    int currentBranchIndex,
  ) {
    try {
      final location = GoRouterState.of(context).uri.path;
      if (location.contains('proxies')) {
        return 1;
      }
    } catch (_) {}
    final currentBranchName = getNameOfBranch(isMobileBreakpoint, showProfilesAction, currentBranchIndex);
    return switch (currentBranchName) {
      'home' => 0,
      'settings' => 2,
      'about' => 3,
      _ => 0,
    };
  }

  Future<void> _onDesktopTap(
    BuildContext context,
    WidgetRef ref,
    int actionIndex,
    bool isMobileBreakpoint,
    bool showProfilesAction,
  ) async {
    if (actionIndex == 1) {
      // Servers / Proxies overview
      context.pushNamed('proxies');
      return;
    }

    final targetBranchName = switch (actionIndex) {
      0 => 'home',
      2 => 'settings',
      3 => 'about',
      _ => 'home',
    };
    final realBranchIndex = getIndexOfBranch(isMobileBreakpoint, showProfilesAction, targetBranchName);
    if (realBranchIndex >= 0) {
      navigationShell.goBranch(realBranchIndex);
    }
  }

  List<ShellRouteAction> _desktopActions(Translations t) => [
    ShellRouteAction(Icons.home_rounded, t.pages.home.title),
    ShellRouteAction(Icons.public_rounded, t.pages.proxies.title),
    ShellRouteAction(Icons.settings_rounded, t.pages.settings.title),
    ShellRouteAction(Icons.info_outline_rounded, t.pages.about.title),
  ];
}
