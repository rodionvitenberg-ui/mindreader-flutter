import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Dark Sanctuary ThemeData powered by the Allo 1.0.3 typeface family:
/// - Display & headings: large, bold Allo Display (`opsz` up to 32, `w800`/`w700`).
/// - Body & UI: neat, friendly Allo Text (`opsz` 14, `w400`/`w500`).
/// - Labels & metadata: crisp Allo Small (`opsz` 9–12, `w600`, tabular digits).
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.familyStatic,
    fontFamilyFallback: AppTypography.fallback,
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

  final text = base.textTheme.apply(
    fontFamily: AppTypography.familyStatic,
    fontFamilyFallback: AppTypography.fallback,
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: AppTypography.display(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      displayMedium: AppTypography.display(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      displaySmall: AppTypography.display(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: AppTypography.display(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      headlineMedium: AppTypography.heading(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: AppTypography.heading(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: AppTypography.heading(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: AppTypography.heading(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: AppTypography.body(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: AppTypography.body(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.48,
        color: AppColors.textPrimary,
      ),
      bodyMedium: AppTypography.body(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodySmall: AppTypography.body(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textMuted,
      ),
      labelLarge: AppTypography.label(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: AppColors.textPrimary,
      ),
      labelMedium: AppTypography.label(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: AppColors.textMuted,
      ),
      labelSmall: AppTypography.label(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.border,
  );
}
