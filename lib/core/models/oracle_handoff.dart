import 'natal_chart.dart';
import 'zodiac_forecast.dart';

/// What kind of ASTRAL reading the handoff carries — drives the history
/// badge, the session title and the Oracle fallback branch.
enum OracleHandoffKind { natalChart, synastry, horoscope, zodiac }

/// A cross-tab handoff payload: the ASTRAL tab asks the Oracle Chat pane
/// (Table tab, Pane 1) to stream a deep psychological reading of natal data.
/// Pure Dart — no Flutter imports.
class OracleHandoff {
  const OracleHandoff({
    required this.prompt,
    this.kind = OracleHandoffKind.natalChart,
    this.chart,
    this.otherChart,
    this.horoscope,
    this.zodiacSign,
    this.zodiacForecast,
  });

  /// The reader-facing structured summary (shown as the user's message).
  final String prompt;

  final OracleHandoffKind kind;

  /// The primary natal chart (or the first profile for synastry).
  final NatalChart? chart;

  /// The second profile — set for the 2-profile synastry handoff.
  final NatalChart? otherChart;

  final DailyHoroscopeReport? horoscope;

  /// Quick-sign mode: the chosen sign and its solar forecast (no chart).
  final ZodiacSign? zodiacSign;
  final ZodiacSignForecast? zodiacForecast;

  bool get isSynastry => otherChart != null;
}
