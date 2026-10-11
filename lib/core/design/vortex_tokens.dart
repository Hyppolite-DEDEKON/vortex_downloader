import 'package:flutter/material.dart';

abstract final class VortexTokens {
  static const brandViolet = Color(0xFF7B5CFF);
  static const brandVioletDeep = Color(0xFF5A4BD4);
  static const brandCyan = Color(0xFF3CE8FF);

  static const darkBg = Color(0xFF070A12);
  static const darkBg2 = Color(0xFF0E1424);

  static const lightBg = Color(0xFFF4F6FB);
  static const lightBg2 = Color(0xFFE8ECF5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF1A1D26);
  static const lightOnSurfaceMuted = Color(0xFF5C6370);

  static const glassBorder = Color(0x66FFFFFF);
  static const glassBorderDark = Color(0x33FFFFFF);
  static const lightGlassBorder = Color(0x332D2640);

  static const radiusL = 24.0;
  static const radiusM = 16.0;
  static const blurSigma = 18.0;

  /// Dégradé violet monochrome du bouton central (tous thèmes).
  static const heroGradient = [
    Color(0xFF5C5280),
    Color(0xFF4A4268),
    Color(0xFF38324F),
  ];
}
