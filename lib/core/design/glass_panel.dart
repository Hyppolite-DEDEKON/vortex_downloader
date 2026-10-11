import 'dart:ui';

import 'package:flutter/material.dart';

import 'vortex_tokens.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = VortexTokens.radiusM,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final borderColor =
        dark ? VortexTokens.glassBorderDark : VortexTokens.lightGlassBorder;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: VortexTokens.blurSigma,
            sigmaY: VortexTokens.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.94),
                        VortexTokens.lightBg2.withValues(alpha: 0.88),
                      ],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
