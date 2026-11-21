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
    this.transit,
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
  final DailyTransitItem? transit;

  /// Quick-sign mode: the chosen sign and its solar forecast (no chart).
  final ZodiacSign? zodiacSign;
  final ZodiacSignForecast? zodiacForecast;

  bool get isSynastry => otherChart != null;
  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'kind': kind.name,
    if (chart != null) 'chart': chart!.toJson(),
    if (otherChart != null) 'otherChart': otherChart!.toJson(),
    if (horoscope != null) 'horoscope': horoscope!.toJson(),
    if (transit != null) 'transit': transit!.toJson(),
    if (zodiacSign != null) 'sign': zodiacSign!.name,
    if (zodiacForecast != null) 'forecast': zodiacForecast!.toJson(),
  };

  static OracleHandoff fromJson(Map<String, dynamic> json) {
    T? read<T>(String key, T Function(Map<String, dynamic>) decode) {
      final value = json[key];
      return value is Map<String, dynamic> ? decode(value) : null;
    }

    final sign = json['sign'] as String?;
    return OracleHandoff(
      prompt: json['prompt'] as String,
      kind: OracleHandoffKind.values.byName(json['kind'] as String),
      chart: read('chart', NatalChart.fromJson),
      otherChart: read('otherChart', NatalChart.fromJson),
      horoscope: read('horoscope', DailyHoroscopeReport.fromJson),
      transit: read('transit', DailyTransitItem.fromJson),
      zodiacSign: sign == null ? null : ZodiacSign.values.byName(sign),
      zodiacForecast: read('forecast', ZodiacSignForecast.fromJson),
    );
  }
}
