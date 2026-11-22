import '../l10n/app_strings.dart';

import 'dealt_card_slot.dart';

/// Session-level origin of the whole reading.
///
/// Deliberately kept SEPARATE from [TableSourceMode] (defined in
/// `dealt_card_slot.dart`): that enum marks where ONE slot's card came from
/// (digital deck extraction vs. a photographed physical card), while this
/// enum marks where the WHOLE session came from. The correspondence is
/// mapped in exactly ONE place — [ReadingSourceX.tableSourceMode] and
/// [ReadingSourceX.fromTableSourceMode] — so consumers never hand-roll the
/// translation.
enum ReadingSource { digital, physical }

extension ReadingSourceX on ReadingSource {
  /// Uppercase session-level badge: 'DIGITAL' | 'PHYSICAL'.
  String get label => AppStrings.g('reading.source.$name');

  /// The slot-level counterpart of this session-level source.
  TableSourceMode get tableSourceMode => switch (this) {
    ReadingSource.digital => TableSourceMode.digitalDeck,
    ReadingSource.physical => TableSourceMode.physicalCameraSync,
  };

  /// Inverse of [tableSourceMode]: the session-level source for a slot that
  /// came from [mode].
  static ReadingSource fromTableSourceMode(TableSourceMode mode) =>
      switch (mode) {
        TableSourceMode.digitalDeck => ReadingSource.digital,
        TableSourceMode.physicalCameraSync => ReadingSource.physical,
      };
}
