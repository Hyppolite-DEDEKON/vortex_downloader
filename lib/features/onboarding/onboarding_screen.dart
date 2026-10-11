import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/glass_panel.dart';
import '../../core/design/vortex_orb.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const VortexOrb(size: 100),
              const SizedBox(height: 24),
              Text(
                'Bienvenue dans Vortex',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _step(Icons.copy_rounded, 'Copiez un lien dans n’importe quelle app.'),
                    const SizedBox(height: 12),
                    _step(Icons.bolt_rounded, 'Ouvrez Vortex — le lien est détecté.'),
                    const SizedBox(height: 12),
                    _step(
                      Icons.download_rounded,
                      'Appuyez sur Télécharger et suivez la progression.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final s = ref.read(settingsProvider);
                  await ref.read(settingsProvider.notifier).update(
                        s.copyWith(onboardingDone: true),
                      );
                  if (context.mounted) context.go('/');
                },
                child: const Text('Commencer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
