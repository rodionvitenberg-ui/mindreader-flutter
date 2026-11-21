import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_tokens.dart';

/// Оптические параметры стекла Tarot Tree как [ThemeExtension], чтобы виджеты
/// могли читать токены [TaroOptics] из [ThemeData] при необходимости.
class TaroOpticsTheme extends ThemeExtension<TaroOpticsTheme> {
  const TaroOpticsTheme({
    this.refractionHeight = TaroOptics.refractionHeight,
    this.refractionAmount = TaroOptics.refractionAmount,
    this.frost = TaroOptics.frost,
    this.highlight = TaroOptics.highlight,
    this.contourStrength = TaroOptics.contourStrength,
    this.tintAmount = TaroOptics.tintAmount,
  });

  final double refractionHeight;
  final double refractionAmount;
  final double frost;
  final double highlight;
  final double contourStrength;
  final double tintAmount;

  @override
  TaroOpticsTheme copyWith({
    double? refractionHeight,
    double? refractionAmount,
    double? frost,
    double? highlight,
    double? contourStrength,
    double? tintAmount,
  }) => TaroOpticsTheme(
    refractionHeight: refractionHeight ?? this.refractionHeight,
    refractionAmount: refractionAmount ?? this.refractionAmount,
    frost: frost ?? this.frost,
    highlight: highlight ?? this.highlight,
    contourStrength: contourStrength ?? this.contourStrength,
    tintAmount: tintAmount ?? this.tintAmount,
  );

  @override
  TaroOpticsTheme lerp(covariant TaroOpticsTheme? other, double t) {
    if (other == null) return this;
    return TaroOpticsTheme(
      refractionHeight: lerpDouble(refractionHeight, other.refractionHeight, t)!,
      refractionAmount: lerpDouble(refractionAmount, other.refractionAmount, t)!,
      frost: lerpDouble(frost, other.frost, t)!,
      highlight: lerpDouble(highlight, other.highlight, t)!,
      contourStrength: lerpDouble(contourStrength, other.contourStrength, t)!,
      tintAmount: lerpDouble(tintAmount, other.tintAmount, t)!,
    );
  }
}

/// Основная тема дизайн-системы **Tarot Tree** (Phase G2).
///
/// Построена на токенах [TaroColors], [TaroOpacity], [TaroRadii], [TaroOptics]
/// и типографике [AppTypography] (шрифт Allo 1.0.3). Подключается в `main.dart`
/// за флагом `kTarotTreeThemeEnabled`; legacy [buildAppTheme] и [AppColors]
/// остаются для отката и непереведённых экранов до G7.
ThemeData buildTaroTheme() {
  final borderHairline = TaroColors.mist.withValues(alpha: TaroOpacity.border);
  final borderStrong = TaroColors.mist.withValues(
    alpha: TaroOpacity.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.familyStatic,
    fontFamilyFallback: AppTypography.fallback,
    scaffoldBackgroundColor: TaroColors.background,
    colorScheme: ColorScheme.dark(
      primary: TaroColors.lavender,
      secondary: TaroColors.indigo,
      tertiary: TaroColors.dawn,
      surface: TaroColors.surface,
      surfaceContainerHighest: TaroColors.canvas,
      error: TaroColors.error,
      onPrimary: TaroColors.background,
      onSecondary: TaroColors.textPrimary,
      onTertiary: TaroColors.background,
      onSurface: TaroColors.textPrimary,
      onSurfaceVariant: TaroColors.textSecondary,
      onError: TaroColors.background,
      outline: borderStrong,
      outlineVariant: borderHairline,
    ),
  );

  final text = base.textTheme.apply(
    fontFamily: AppTypography.familyStatic,
    fontFamilyFallback: AppTypography.fallback,
    bodyColor: TaroColors.textPrimary,
    displayColor: TaroColors.textPrimary,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: AppTypography.display(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: TaroColors.textPrimary,
      ),
      displayMedium: AppTypography.display(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: TaroColors.textPrimary,
      ),
      displaySmall: AppTypography.display(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: TaroColors.textPrimary,
      ),
      headlineLarge: AppTypography.display(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: TaroColors.textPrimary,
      ),
      headlineMedium: AppTypography.heading(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: TaroColors.textPrimary,
      ),
      headlineSmall: AppTypography.heading(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: TaroColors.textPrimary,
      ),
      titleLarge: AppTypography.heading(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: TaroColors.textPrimary,
      ),
      titleMedium: AppTypography.heading(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: TaroColors.textPrimary,
      ),
      titleSmall: AppTypography.body(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: TaroColors.textPrimary,
      ),
      bodyLarge: AppTypography.body(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.48,
        color: TaroColors.textPrimary,
      ),
      bodyMedium: AppTypography.body(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: TaroColors.textPrimary,
      ),
      bodySmall: AppTypography.body(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: TaroColors.textSecondary,
      ),
      labelLarge: AppTypography.label(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: TaroColors.textPrimary,
      ),
      labelMedium: AppTypography.label(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: TaroColors.textSecondary,
      ),
      labelSmall: AppTypography.label(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: TaroColors.textSecondary,
      ),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: borderHairline,
    iconTheme: const IconThemeData(color: TaroColors.textPrimary),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: TaroColors.lavender,
      selectionColor: TaroColors.lavender.withValues(alpha: 0.28),
      selectionHandleColor: TaroColors.lavender,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TaroColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaroRadii.panel),
        side: BorderSide(color: borderHairline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TaroColors.surface,
      contentTextStyle: AppTypography.body(
        fontSize: 13.5,
        color: TaroColors.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaroRadii.button),
        side: BorderSide(color: borderHairline),
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[TaroOpticsTheme()],
  );
}
