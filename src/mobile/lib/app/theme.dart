import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HanglyTheme {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static bool get isDark => themeNotifier.value == ThemeMode.dark;

  static Color get background => isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
  static Color get surface => isDark ? const Color(0xFF151D2F) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get primary => const Color(0xFFFFD700); // Hangly Gold
  static Color get primaryGlow => const Color(0xFFFFA000);
  static Color get secondary => isDark ? const Color(0xFF00E5FF) : const Color(0xFF0096C7); // Cyan
  static Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get border => isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  static ThemeData? _darkTheme;
  static ThemeData? _lightTheme;

  static ThemeData get darkTheme => _darkTheme ??= _buildDarkTheme();
  static ThemeData get lightTheme => _lightTheme ??= _buildLightTheme();

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      primaryColor: const Color(0xFFFFD700),
      textTheme: GoogleFonts.cinzelTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFF8FAFC),
        displayColor: const Color(0xFFF8FAFC),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFD700),
        secondary: Color(0xFF00E5FF),
        surface: Color(0xFF151D2F),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151D2F),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFFFD700),
        inactiveTrackColor: Color(0xFF334155),
        thumbColor: Color(0xFFFFD700),
        overlayColor: Color(0x33FFD700),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFFFFD700);
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFFFD700).withAlpha(100);
          }
          return const Color(0xFF334155);
        }),
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: const Color(0xFFFFD700),
      textTheme: GoogleFonts.cinzelTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFFD700),
        secondary: Color(0xFF0096C7),
        surface: Color(0xFFFFFFFF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFFFD700),
        inactiveTrackColor: Color(0xFFCBD5E1),
        thumbColor: Color(0xFFFFD700),
        overlayColor: Color(0x33FFD700),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFFFFD700);
          return const Color(0xFF475569);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFFFD700).withAlpha(100);
          }
          return const Color(0xFFCBD5E1);
        }),
      ),
    );
  }
}
