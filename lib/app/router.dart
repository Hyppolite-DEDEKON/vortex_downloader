import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/glass_panel.dart';
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

  static const _barInset = 6.0;
  static const _barRadius = 32.0;
  static const _tabRadius = _barRadius - _barInset;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
          child: GlassPanel(
            padding: const EdgeInsets.all(_barInset),
            borderRadius: _barRadius,
            child: Row(
              children: [
                _ShellTab(
                  selected: shell.currentIndex == 0,
                  icon: Icons.home_rounded,
                  label: 'Accueil',
                  tabRadius: _tabRadius,
                  onTap: () => shell.goBranch(0, initialLocation: true),
                ),
                const SizedBox(width: 4),
                _ShellTab(
                  selected: shell.currentIndex == 1,
                  icon: Icons.download_rounded,
                  label: 'Téléchargements',
                  tabRadius: _tabRadius,
                  onTap: () => shell.goBranch(1, initialLocation: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTab extends StatelessWidget {
  const _ShellTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.tabRadius,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final double tabRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(tabRadius);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: selected ? scheme.secondaryContainer : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
