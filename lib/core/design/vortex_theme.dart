import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vortex_tokens.dart';

class VortexTheme {
  VortexTheme._();

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = dark ? _darkScheme() : _lightScheme();
    final text = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
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
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: dark ? 0 : 0.5,
        shadowColor: dark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          side: dark
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.55),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? VortexTokens.darkBg2 : VortexTokens.lightOnSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: dark ? Colors.white : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusL),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : VortexTokens.lightSurface,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          borderSide: BorderSide(
            color: dark
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          borderSide: BorderSide(
            color: dark
                ? Colors.transparent
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VortexTokens.radiusM),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }

  static ColorScheme _darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: VortexTokens.brandViolet,
      brightness: Brightness.dark,
      surface: VortexTokens.darkBg,
    );
  }

  static ColorScheme _lightScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: VortexTokens.brandVioletDeep,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE4DEFF),
      onPrimaryContainer: const Color(0xFF2A1F5C),
      secondary: const Color(0xFF6258A8),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE8E4F8),
      onSecondaryContainer: const Color(0xFF2D2640),
      tertiary: const Color(0xFF4A6FA5),
      onTertiary: Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: VortexTokens.lightBg,
      onSurface: VortexTokens.lightOnSurface,
      onSurfaceVariant: VortexTokens.lightOnSurfaceMuted,
      outline: const Color(0xFFCBD2DC),
      outlineVariant: const Color(0xFFDDE3ED),
      shadow: Colors.black.withValues(alpha: 0.12),
      surfaceContainerHighest: const Color(0xFFE2E7F0),
      surfaceContainerHigh: VortexTokens.lightSurface,
      surfaceContainer: VortexTokens.lightBg2,
      surfaceContainerLow: const Color(0xFFF0F3F9),
      surfaceContainerLowest: VortexTokens.lightSurface,
    );
  }
}
