import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Dark Sanctuary ThemeData. Body: Plus Jakarta Sans; display: Cormorant
/// Garamond (arcane editorial serif, Cyrillic + Latin); labels: JetBrains
/// Mono. Google Fonts falls back to the system serif/sans offline.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lavender,
      secondary: AppColors.indigo,
      surface: AppColors.surface,
      onPrimary: AppColors.canvas,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textMuted,
    ),
  );

  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        letterSpacing: 1.8,
        color: AppColors.textMuted,
      ),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.border,
  );
}
