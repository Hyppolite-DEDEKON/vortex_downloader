import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/design/glass_panel.dart';
import '../../core/design/vortex_tokens.dart';

/// Fond immersif (audio + erreur).
class VortexPlayerBackdrop extends StatelessWidget {
  const VortexPlayerBackdrop({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      VortexTokens.darkBg,
                      const Color(0xFF12102A),
                      VortexTokens.darkBg2,
                    ]
                  : [
                      VortexTokens.lightBg,
                      const Color(0xFFE4E0F5),
                      VortexTokens.lightBg2,
                    ],
            ),
          ),
        ),
        if (imageUrl != null && imageUrl!.isNotEmpty)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox.shrink();
            },
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (dark ? VortexTokens.darkBg : VortexTokens.lightBg)
                      .withValues(alpha: 0.55),
                  (dark ? VortexTokens.darkBg2 : VortexTokens.lightBg2)
                      .withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.1,
              colors: [
                VortexTokens.brandViolet.withValues(alpha: dark ? 0.35 : 0.22),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.9, 0.95),
              radius: 0.65,
              colors: [
                VortexTokens.brandCyan.withValues(alpha: dark ? 0.12 : 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class VortexPlayerTopBar extends StatelessWidget {
  const VortexPlayerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.lightForeground = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final bool lightForeground;

  @override
  Widget build(BuildContext context) {
    final fg = lightForeground
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final muted = lightForeground
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: fg,
              iconSize: 32,
              tooltip: 'Fermer',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lecture en cours',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 0.4,
                        ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de transport partagée (audio / vidéo).
class VortexPlayerTransport extends StatelessWidget {
  const VortexPlayerTransport({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.progress,
    required this.onPlayPause,
    required this.onSeek,
    this.onRewind,
    this.onForward,
    this.dark = false,
    this.compact = false,
    this.loading = false,
  });

  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final double progress;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = dark
        ? Colors.white.withValues(alpha: 0.72)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final trackBg = dark
        ? Colors.white.withValues(alpha: 0.22)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _format(position),
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Text(
              _format(duration),
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _PremiumSeekBar(
          value: progress,
          onChanged: onSeek,
          dark: dark,
          trackBg: trackBg,
          enabled: onSeek != null,
        ),
        SizedBox(height: compact ? 8 : 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SideControl(
              icon: Icons.replay_10_rounded,
              onPressed: onRewind,
              dark: dark,
            ),
            const SizedBox(width: 8),
            VortexPlayPauseOrb(
              playing: playing,
              loading: loading,
              onPressed: onPlayPause,
              size: compact ? 56 : 72,
            ),
            const SizedBox(width: 8),
            _SideControl(
              icon: Icons.forward_10_rounded,
              onPressed: onForward,
              dark: dark,
            ),
          ],
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: content,
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      borderRadius: VortexTokens.radiusL,
      child: content,
    );
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

class _PremiumSeekBar extends StatelessWidget {
  const _PremiumSeekBar({
    required this.value,
    required this.onChanged,
    required this.dark,
    required this.trackBg,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final bool dark;
  final Color trackBg;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = dark ? VortexTokens.brandCyan : VortexTokens.brandViolet;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        activeTrackColor: accent,
        inactiveTrackColor: trackBg,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.18),
      ),
      child: Slider(
        value: value.clamp(0.0, 1.0),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({
    required this.icon,
    required this.onPressed,
    required this.dark,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark
        ? Colors.white.withValues(alpha: onPressed == null ? 0.35 : 0.92)
        : Theme.of(context).colorScheme.onSurface.withValues(
              alpha: onPressed == null ? 0.35 : 0.88,
            );
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 32,
      color: color,
    );
  }
}

class VortexPlayPauseOrb extends StatelessWidget {
  const VortexPlayPauseOrb({
    super.key,
    required this.playing,
    required this.onPressed,
    required this.size,
    this.loading = false,
  });

  final bool playing;
  final VoidCallback? onPressed;
  final double size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: VortexTokens.brandViolet.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VortexTokens.brandViolet,
            VortexTokens.brandVioletDeep,
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: loading ? null : onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: loading
                ? Padding(
                    padding: EdgeInsets.all(size * 0.28),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: size * 0.46,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Visualiseur léger pour l’audio.
class VortexAudioVisualizer extends StatefulWidget {
  const VortexAudioVisualizer({super.key, required this.active});

  final bool active;

  @override
  State<VortexAudioVisualizer> createState() => _VortexAudioVisualizerState();
}

class _VortexAudioVisualizerState extends State<VortexAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant VortexAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.2;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = VortexTokens.brandCyan;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final phase = (_controller.value + i * 0.15) % 1.0;
            final h = 8 + (phase * 22);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 4,
                height: widget.active ? h : 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      accent.withValues(alpha: 0.35),
                      accent,
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Pochette audio (vignette réseau ou placeholder premium).
class VortexAudioArtwork extends StatelessWidget {
  const VortexAudioArtwork({
    super.key,
    this.thumbnailUrl,
    this.localPath,
  });

  final String? thumbnailUrl;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Widget image;
    if (localPath != null && localPath!.isNotEmpty) {
      image = Image.file(
        File(localPath!),
        key: ValueKey(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(dark),
      );
    } else if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      image = Image.network(
        thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(dark),
      );
    } else {
      image = _placeholder(dark);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: VortexTokens.brandViolet.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.12 : 0.65),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AspectRatio(aspectRatio: 1, child: image),
      ),
    );
  }

  Widget _placeholder(bool dark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VortexTokens.brandViolet.withValues(alpha: 0.85),
            VortexTokens.brandVioletDeep,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          size: 88,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
