import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class YTColors {
  static const Color background = Color(0xFF030303);
  static const Color surface = Color(0xFF212121);
  static const Color surfaceLight = Color(0xFF383838);
  static const Color primary = Colors.white;
  static const Color secondary = Colors.white70;
  static const Color disabled = Colors.white30;
  static const Color divider = Color(0xFF2C2C2C);
  static const Color accent = Colors.white; 
}

class YTTheme {
  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: YTColors.primary,
      scaffoldBackgroundColor: YTColors.background,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: YTColors.primary,
        surface: YTColors.surface,
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
        bodyColor: YTColors.primary,
        displayColor: YTColors.primary,
      ).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: -1.0, color: YTColors.primary),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5, color: YTColors.primary),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: YTColors.primary),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14, color: YTColors.secondary),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: YTColors.primary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: YTColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: YTColors.surface,
        selectedItemColor: YTColors.primary,
        unselectedItemColor: YTColors.secondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: YTColors.surfaceLight,
        contentTextStyle: TextStyle(color: YTColors.primary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: YTColors.primary,
        inactiveTrackColor: YTColors.disabled,
        thumbColor: YTColors.primary,
        overlayColor: YTColors.primary.withValues(alpha: 0.12),
        trackHeight: 2.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
    );
  }
}
