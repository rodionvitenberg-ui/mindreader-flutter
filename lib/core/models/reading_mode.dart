/// How a reading session is driven end-to-end.
///
/// * [standard] — the digital-table reading;
/// * [quickScan], [guidedSpread], [liveOracle] — the three physical
///   (camera-driven) flows introduced by the Physical Reading & Live Oracle
///   roadmap.
enum ReadingMode { standard, quickScan, guidedSpread, liveOracle }

extension ReadingModeX on ReadingMode {
  /// Uppercase badge label: 'STANDARD' | 'QUICK SCAN' | 'GUIDED SPREAD' |
  /// 'LIVE ORACLE'.
  String get label => switch (this) {
    ReadingMode.standard => 'STANDARD',
    ReadingMode.quickScan => 'QUICK SCAN',
    ReadingMode.guidedSpread => 'GUIDED SPREAD',
    ReadingMode.liveOracle => 'LIVE ORACLE',
  };
}
