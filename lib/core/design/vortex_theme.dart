import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vortex_tokens.dart';

class VortexTheme {
  VortexTheme._();

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: VortexTokens.brandViolet,
      brightness: brightness,
      surface: dark ? VortexTokens.darkBg : VortexTokens.lightBg,
    );
    final text = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? VortexTokens.darkBg : VortexTokens.lightBg,
      textTheme: text.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: VortexTokens.brandViolet.withValues(alpha: 0.25),
        backgroundColor: dark
            ? VortexTokens.darkBg2.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
