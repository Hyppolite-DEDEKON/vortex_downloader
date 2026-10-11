import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/vortex_orb.dart';
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [VortexTokens.darkBg2, VortexTokens.darkBg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VortexOrb(size: 120),
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
                      color: VortexTokens.brandCyan,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
