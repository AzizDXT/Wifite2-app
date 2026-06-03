import 'package:flutter/material.dart';

/// A calm, professional light theme: muted slate-teal accent, soft off-white
/// canvas, bordered (not shadowed) cards, and generous corner radii.
class AppTheme {
  AppTheme._();

  // Palette
  static const seed = Color(0xFF4C6E7D); // calm slate-teal
  static const canvas = Color(0xFFF6F8FA); // soft off-white background
  static const ink = Color(0xFF1F2933); // primary text
  static const inkSoft = Color(0xFF52606D); // secondary text
  static const inkMuted = Color(0xFF7B8794); // tertiary / hints
  static const hairline = Color(0xFFE4E9EF); // borders / dividers
  static const fieldFill = Color(0xFFF1F4F7);

  static const ok = Color(0xFF3FAE6B);
  static const danger = Color(0xFFD64545);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(surface: Colors.white);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: hairline),
        ),
      ),
      textTheme: const TextTheme(
        titleSmall: TextStyle(
            color: ink, fontSize: 15, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: inkSoft, fontSize: 14, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        hintStyle: const TextStyle(color: inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: seed, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: ink,
          side: const BorderSide(color: Color(0xFFD3DAE3)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
