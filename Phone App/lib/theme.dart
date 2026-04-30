// lib/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ───────────────────────────────────────────
  static const Color bg          = Color(0xFF000000);
  static const Color surface     = Color(0xFF0D0D0D);
  static const Color surface2    = Color(0xFF1A1A1A);
  static const Color border      = Color(0xFF2A2A2A);
  static const Color accent      = Color(0xFF00E5FF);  // Cyan
  static const Color accentDim   = Color(0xFF006B75);
  static const Color success     = Color(0xFF00FF88);
  static const Color warning     = Color(0xFFFFB300);
  static const Color danger      = Color(0xFFFF4444);
  static const Color dangerDim   = Color(0xFF4A1010);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFF888888);
  static const Color textDim     = Color(0xFF444444);

  // Device colors
  static const Color colorFan    = Color(0xFF40C4FF);
  static const Color colorLight  = Color(0xFFFFD740);
  static const Color colorSocket = Color(0xFF69F0AE);
  static const Color colorRgb    = Color(0xFFEA80FC);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentDim,
      surface: surface,
      error: danger,
    ),
    textTheme: GoogleFonts.spaceGroteskTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecond),
        bodySmall: TextStyle(color: textDim),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: surface2,
      thumbColor: accent,
      overlayColor: accent.withOpacity(0.2),
      valueIndicatorColor: accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textSecond),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentDim : surface2),
    ),
    dividerColor: border,
    cardColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
  );
}
