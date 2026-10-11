import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/glass_panel.dart';
import '../../core/design/vortex_orb.dart';
import '../../core/design/vortex_tokens.dart';

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
              _OnboardingStartButton(
                onPressed: () async {
                  final s = ref.read(settingsProvider);
                  await ref.read(settingsProvider.notifier).update(
                        s.copyWith(onboardingDone: true),
                      );
                  if (context.mounted) context.go('/');
                },
              ),
              const SizedBox(height: 8),
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

/// CTA d’accueil — même langage visuel que le bouton central de l’écran d’accueil.
class _OnboardingStartButton extends StatefulWidget {
  const _OnboardingStartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_OnboardingStartButton> createState() => _OnboardingStartButtonState();
}

class _OnboardingStartButtonState extends State<_OnboardingStartButton>
    with SingleTickerProviderStateMixin {
  static const _height = 56.0;
  static const _violetTop = Color(0xFF5C5280);
  static const _violetMid = Color(0xFF4A4268);
  static const _violetBottom = Color(0xFF38324F);

  bool _pressed = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = _pressed ? 0.98 : 1.0;

    return Semantics(
      button: true,
      label: 'Commencer',
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_glow.value);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VortexTokens.radiusL),
              boxShadow: [
                BoxShadow(
                  color: VortexTokens.brandViolet
                      .withValues(alpha: 0.14 + 0.10 * t),
                  blurRadius: 22 + 8 * t,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            borderRadius: BorderRadius.circular(VortexTokens.radiusL),
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              borderRadius: BorderRadius.circular(VortexTokens.radiusL),
              child: Ink(
                height: _height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VortexTokens.radiusL),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                    width: 1.2,
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_violetTop, _violetMid, _violetBottom],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Commencer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xE8FFFFFF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
