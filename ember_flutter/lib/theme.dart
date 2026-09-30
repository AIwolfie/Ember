import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/database_service.dart';

class EmberThemeOption {
  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceLight;

  const EmberThemeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceLight,
  });
}

class EmberThemes {
  static const amber = EmberThemeOption(
    id: 'amber',
    name: 'Amber',
    description: 'Warm golden amber & deep roasted espresso',
    primary: Color(0xFFFFB300),
    accent: Color(0xFFFFCA28),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceLight: Color(0xFF1A1A1A),
  );

  static const emerald = EmberThemeOption(
    id: 'emerald',
    name: 'Emerald',
    description: 'Forest moss, midnight pine & radiant emerald glow',
    primary: Color(0xFF00E676),
    accent: Color(0xFF69F0AE),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceLight: Color(0xFF1A1A1A),
  );

  static const amethyst = EmberThemeOption(
    id: 'amethyst',
    name: 'Amethyst',
    description: 'Velvet twilight & mystical violet luminescence',
    primary: Color(0xFFB388FF),
    accent: Color(0xFFD1C4E9),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceLight: Color(0xFF1A1A1A),
  );

  static const solar = EmberThemeOption(
    id: 'solar',
    name: 'Solar',
    description: 'Sun-baked terracotta, warm earth & solar fire',
    primary: Color(0xFFFF6D00),
    accent: Color(0xFFFFAB40),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceLight: Color(0xFF1A1A1A),
  );

  static const rose = EmberThemeOption(
    id: 'rose',
    name: 'Rose',
    description: 'Smoky plum, evening rouge & soft blush accents',
    primary: Color(0xFFFF4081),
    accent: Color(0xFFFF80AB),
    background: Color(0xFF000000),
    surface: Color(0xFF121212),
    surfaceLight: Color(0xFF1A1A1A),
  );

  static const List<EmberThemeOption> all = [
    amber,
    emerald,
    amethyst,
    solar,
    rose,
  ];

  static EmberThemeOption fromId(String? id) {
    if (id == null) return amber;
    return all.firstWhere((t) => t.id == id, orElse: () => amber);
  }
}

class ThemeCubit extends Cubit<EmberThemeOption> {
  ThemeCubit() : super(EmberThemes.amber) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedId = await DatabaseService.instance.getCache('app_theme');
      if (savedId != null) {
        final theme = EmberThemes.fromId(savedId);
        YTColors.current = theme;
        emit(theme);
      }
    } catch (_) {}
  }

  Future<void> setTheme(EmberThemeOption theme) async {
    YTColors.current = theme;
    emit(theme);
    try {
      await DatabaseService.instance.setCache('app_theme', theme.id);
    } catch (_) {}
  }
}

class YTColors {
  static EmberThemeOption current = EmberThemes.amber;

  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get surfaceLight => current.surfaceLight;
  static Color get primary => current.primary;
  static Color get accent => current.accent;
  static const Color secondary = Colors.white70;
  static const Color disabled = Colors.white30;
  static const Color divider = Color(0xFF2C2C2C);
}

class YTTheme {
  static ThemeData getTheme(EmberThemeOption theme) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: theme.primary,
      scaffoldBackgroundColor: theme.background,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: theme.primary,
        surface: theme.surface,
        secondary: theme.accent,
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme)
          .apply(bodyColor: Colors.white, displayColor: Colors.white)
          .copyWith(
            displayLarge: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 32,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
            displayMedium: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
            bodyLarge: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Colors.white,
            ),
            bodyMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: YTColors.secondary,
            ),
            titleMedium: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: theme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.surface,
        selectedItemColor: theme.primary,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.surfaceLight,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.primary,
        inactiveTrackColor: YTColors.disabled,
        thumbColor: theme.primary,
        overlayColor: theme.primary.withValues(alpha: 0.12),
        trackHeight: 2.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
    );
  }

  static ThemeData get darkTheme => getTheme(EmberThemes.amber);
}
