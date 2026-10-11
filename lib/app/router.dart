import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/design/glass_panel.dart';
import '../core/design/vortex_tokens.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/splash_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createVortexRouter({required bool onboardingDone}) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/library',
        redirect: (_, __) => '/downloads',
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => VortexShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder: (_, __) => const DownloadsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class VortexShell extends StatelessWidget {
  const VortexShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _dockRadius = 34.0;
  static const _dockInset = 5.0;
  static const _pillRadius = _dockRadius - _dockInset;
  static const _dockHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 10 + bottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_dockRadius + 4),
              boxShadow: [
                BoxShadow(
                  color: (dark ? Colors.black : scheme.primary)
                      .withValues(alpha: dark ? 0.45 : 0.14),
                  blurRadius: dark ? 28 : 22,
                  offset: const Offset(0, 10),
                  spreadRadius: dark ? -4 : 0,
                ),
              ],
            ),
            child: GlassPanel(
              padding: const EdgeInsets.all(_dockInset),
              borderRadius: _dockRadius,
              child: SizedBox(
                height: _dockHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabWidth = constraints.maxWidth / 2;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: shell.currentIndex * tabWidth,
                          width: tabWidth,
                          top: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(_pillRadius - 2),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: dark
                                      ? [
                                          VortexTokens.brandViolet
                                              .withValues(alpha: 0.38),
                                          VortexTokens.brandVioletDeep
                                              .withValues(alpha: 0.22),
                                        ]
                                      : [
                                          scheme.primaryContainer
                                              .withValues(alpha: 0.95),
                                          scheme.primary
                                              .withValues(alpha: 0.12),
                                        ],
                                ),
                                border: Border.all(
                                  color: scheme.primary
                                      .withValues(alpha: dark ? 0.28 : 0.18),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _ShellTab(
                              selected: shell.currentIndex == 0,
                              icon: Icons.home_rounded,
                              selectedIcon: Icons.home_filled,
                              label: 'Accueil',
                              pillRadius: _pillRadius,
                              onTap: () => _goToTab(shell, 0),
                            ),
                            _ShellTab(
                              selected: shell.currentIndex == 1,
                              icon: Icons.download_rounded,
                              selectedIcon: Icons.download_for_offline_rounded,
                              label: 'Téléchargements',
                              pillRadius: _pillRadius,
                              onTap: () => _goToTab(shell, 1),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToTab(StatefulNavigationShell shell, int index) {
    if (shell.currentIndex != index) {
      HapticFeedback.lightImpact();
    }
    shell.goBranch(index, initialLocation: true);
  }
}

class _ShellTab extends StatelessWidget {
  const _ShellTab({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.pillRadius,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final double pillRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(pillRadius);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: scheme.primary.withValues(alpha: 0.14),
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.96,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Icon(
                      selected ? selectedIcon : icon,
                      key: ValueKey(selected),
                      color: fg,
                      size: selected ? 26 : 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: selected ? 0.1 : 0,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
