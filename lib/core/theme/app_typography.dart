import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography built around the Allo 1.0.3 typeface family:
/// - **AlloVariable** (variable font with `wght`, `opsz`, `ROND` axes) drives
///   upright display headings, body copy and compact UI labels with optical
///   sizing matched to each text size (`opsz` 9..32).
/// - **Allo** (static weights 300–900 + true Obliques) serves as the app-wide
///   default `ThemeData.fontFamily` and handles italic/oblique styles.
/// - Because Allo currently ships Latin/Vietnamese/symbols without Cyrillic,
///   every style declares a clean geometric sans-serif fallback list so RU UI
///   strings stay cohesive and weight-matched.
/// - Oracle Chat AI & user message copy uses [chatOracle] / [chatUser]
///   (clean Gemini-style reading sans with full Latin + Cyrillic coverage),
///   kept in one place so switching chat copy to Allo later is a single edit.
class AppTypography {
  const AppTypography._();

  static const String familyStatic = 'Allo';
  static const String familyVariable = 'AlloVariable';

  static const List<String> fallback = <String>[
    'Plus Jakarta Sans',
    'Inter',
    'Roboto',
    'sans-serif',
  ];

  static double _weightToAxis(FontWeight weight) => switch (weight) {
    FontWeight.w100 => 100,
    FontWeight.w200 => 200,
    FontWeight.w300 => 300,
    FontWeight.w400 => 400,
    FontWeight.w500 => 500,
    FontWeight.w600 => 600,
    FontWeight.w700 => 700,
    FontWeight.w800 => 800,
    FontWeight.w900 => 900,
    _ => 400,
  };

  /// Core Allo builder. Uses `AlloVariable` with optical size (`opsz`) and
  /// weight (`wght`) axes for upright styles, and falls back to static `Allo`
  /// when `fontStyle == FontStyle.italic` (where real Oblique cuts live).
  static TextStyle allo({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    double? opticalSize,
    double roundness = 50,
    bool tabularFigures = false,
    TextDecoration? decoration,
    Color? decorationColor,
    List<Shadow>? shadows,
  }) {
    final isItalic = fontStyle == FontStyle.italic;
    final resolvedSize = fontSize ?? 14;
    final resolvedOpsz = (opticalSize ?? resolvedSize).clamp(9.0, 32.0);
    return TextStyle(
      fontFamily: isItalic ? familyStatic : familyVariable,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: decorationColor,
      shadows: shadows,
      fontFeatures: tabularFigures
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
      fontVariations: isItalic
          ? null
          : <FontVariation>[
              FontVariation.weight(_weightToAxis(fontWeight)),
              FontVariation.opticalSize(resolvedOpsz),
              FontVariation('ROND', roundness),
            ],
    );
  }

  /// Large, bold headings (screen headers, sheet titles, card/zodiac titles).
  /// Uses Allo's Display optical sizing (`opsz` up to 32) and thick weight
  /// (`w800` by default) with tight modern tracking.
  static TextStyle display({
    double fontSize = 26,
    FontWeight fontWeight = FontWeight.w800,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    double roundness = 44,
    List<Shadow>? shadows,
  }) {
    final defaultTracking = fontSize >= 24 ? -0.45 : -0.2;
    return allo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height ?? 1.08,
      letterSpacing: letterSpacing ?? defaultTracking,
      opticalSize: fontSize.clamp(18.0, 32.0),
      roundness: roundness,
      shadows: shadows,
    );
  }

  /// Section & card headings (16–22px), sturdy and crisp without shouting.
  static TextStyle heading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return allo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height ?? 1.16,
      letterSpacing: letterSpacing ?? -0.15,
      opticalSize: fontSize.clamp(16.0, 32.0),
    );
  }

  /// Neat, pleasant body and secondary UI copy.
  static TextStyle body({
    double fontSize = 13.5,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return allo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      opticalSize: fontSize.clamp(11.0, 16.0),
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// Compact UI eyebrows, pills, badges, buttons and metadata.
  /// Uses Allo's small optical size (`opsz` 9–12, which naturally opens up
  /// tracking for small labels) + tabular figures so numbers never jitter.
  static TextStyle label({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    bool tabularFigures = true,
  }) {
    return allo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? 0.6,
      opticalSize: fontSize.clamp(9.0, 14.0),
      tabularFigures: tabularFigures,
    );
  }

  /// Gemini-inspired Oracle AI response body text — larger, airy, comfortable
  /// for long-form reading across both Latin and Cyrillic.
  static TextStyle chatOracle({
    double fontSize = 15.5,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
    double height = 1.6,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Gemini-inspired user message bubble & input text.
  static TextStyle chatUser({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color? color,
    double height = 1.48,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
