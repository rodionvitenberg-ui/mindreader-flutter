import '../l10n/app_strings.dart';
import 'reading_mode.dart';
import 'reading_source.dart';

/// The single combined badge for a saved reading session: `DIGITAL` /
/// `PHYSICAL` / `GUIDED` / `LIVE`.
///
/// One decision lives here so the Oracle meta bar and the History tiles never
/// hand-roll the source+mode translation. A digital reading is always
/// `DIGITAL`; a physical reading is `GUIDED` (guided spread), `LIVE` (live
/// oracle freeform) or `PHYSICAL` (quick scan / any other physical flow).
String readingSessionBadge({
  ReadingSource? source,
  ReadingMode? mode,
}) {
  if (source == ReadingSource.physical) {
    return switch (mode) {
      ReadingMode.guidedSpread => AppStrings.g('reading.badge.guided'),
      ReadingMode.liveOracle => AppStrings.g('reading.badge.live'),
      _ => AppStrings.g('reading.badge.physical'),
    };
  }
  return AppStrings.g('reading.badge.digital');
}
