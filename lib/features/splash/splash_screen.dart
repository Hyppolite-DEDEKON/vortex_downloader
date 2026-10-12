import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/vortex_tokens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final done = ref.read(settingsProvider).onboardingDone;
    context.go(done ? '/' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.2,
            colors: dark
                ? [VortexTokens.darkBg2, VortexTokens.darkBg]
                : [const Color(0xFFE8E4F8), VortexTokens.lightBg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  width: 120,
                  height: 120,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vortex',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'One link. One tap.',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: dark ? VortexTokens.brandCyan : scheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
