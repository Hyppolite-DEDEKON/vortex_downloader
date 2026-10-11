import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vortex_tokens.dart';

class VortexOrb extends StatefulWidget {
  const VortexOrb({super.key, this.size = 140, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<VortexOrb> createState() => _VortexOrbState();
}

class _VortexOrbState extends State<VortexOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _VortexPainter(_c.value),
        );
      },
    );
  }
}

class _VortexPainter extends CustomPainter {
  _VortexPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(
      center,
      r * 0.95,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VortexTokens.brandCyan.withValues(alpha: 0.35),
            VortexTokens.brandViolet.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    for (var i = 0; i < 3; i++) {
      final angle = (t + i / 3) * math.pi * 2;
      final path = Path();
      for (var a = 0.0; a < math.pi * 2; a += 0.18) {
        final spiral = (a / (math.pi * 2)) * r * 0.78;
        final x = center.dx + spiral * math.cos(a + angle);
        final y = center.dy + spiral * math.sin(a + angle);
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = VortexTokens.brandCyan.withValues(alpha: 0.45 - i * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VortexPainter oldDelegate) =>
      oldDelegate.t != t;
}
