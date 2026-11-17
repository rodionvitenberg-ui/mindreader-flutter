import 'natal_chart.dart';

/// A cross-tab handoff payload: the ASTRAL tab asks the Oracle Chat pane
/// (Table tab, Pane 1) to stream a deep psychological reading of natal data.
/// Pure Dart — no Flutter imports.
class OracleHandoff {
  const OracleHandoff({
    required this.prompt,
    this.chart,
    this.otherChart,
    this.horoscope,
  });

  /// The reader-facing structured summary (shown as the user's message).
  final String prompt;

  /// The primary natal chart (or the first profile for synastry).
  final NatalChart? chart;

  /// The second profile — set for the 2-profile synastry handoff.
  final NatalChart? otherChart;

  final DailyHoroscopeReport? horoscope;

  bool get isSynastry => otherChart != null;
}
