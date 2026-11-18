import 'natal_chart.dart';

/// A lightweight daily forecast for one zodiac sign — the quick-sign mode
/// used when no natal chart exists (Almanac → Astral). A whole-sign "solar
/// chart" is anchored on the sign itself, so the Moon/Sun houses are solar
/// houses (1..12 from the sign), not natal houses. Pure Dart.
class ZodiacSignForecast {
  const ZodiacSignForecast({
    required this.date,
    required this.sign,
    required this.moonPhaseName,
    required this.moonPhaseGlyph,
    required this.moonIllumination,
    required this.transitingMoonSign,
    required this.solarMoonHouse,
    required this.solarSunHouse,
    required this.sunDegreeInSign,
    required this.overallTheme,
    required this.energyScore,
    required this.focusSpheres,
  });

  final DateTime date;
  final ZodiacSign sign;
  final String moonPhaseName;
  final String moonPhaseGlyph;

  /// Illuminated fraction of the lunar disk, 0..1.
  final double moonIllumination;
  final ZodiacSign transitingMoonSign;

  /// Which solar house (1..12, counted from [sign]) the Moon is crossing.
  final int solarMoonHouse;

  /// Which solar house the Sun is crossing.
  final int solarSunHouse;

  /// The Sun's degree inside the sign it currently occupies, 0..29.99.
  final double sunDegreeInSign;

  final String overallTheme;

  /// Deterministic daily energy indicator, 1..100.
  final int energyScore;

  final List<FocusSphere> focusSpheres;
}
