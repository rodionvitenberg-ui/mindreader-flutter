import '../l10n/app_strings.dart';

/// The three authentic divination systems supported by the Digital Table,
/// Oracle Chat, Session History and Almanac. Pure Dart — no Flutter imports.
enum DivinationSystem { tarot, lenormand, runes }

extension DivinationSystemX on DivinationSystem {
  /// Uppercase segment label, e.g. 'TAROT'.
  String get label => AppStrings.g('content.system.$name.label');

  /// Full canonical dataset size: 78 tarot cards, 36 Lenormand cards,
  /// 24 Elder Futhark runes.
  int get deckSize => switch (this) {
        DivinationSystem.tarot => 78,
        DivinationSystem.lenormand => 36,
        DivinationSystem.runes => 24,
      };

  /// What a single drawn piece is called (used in pills and prompts).
  String get unit => AppStrings.g(
    this == DivinationSystem.runes ? 'common.unit.rune' : 'common.unit.card',
  );

  /// Pill glyph prefix: cards for Tarot/Lenormand, stones for Runes.
  String get packGlyph => switch (this) {
        DivinationSystem.tarot => '🎴',
        DivinationSystem.lenormand => '🎴',
        DivinationSystem.runes => '🪨',
      };

  /// True when drawn pieces of this system may land reversed.
  /// Lenormand is always upright; tarot and (non-symmetrical) runes flip.
  bool get systemSupportsReversals => switch (this) {
        DivinationSystem.tarot => true,
        DivinationSystem.lenormand => false,
        DivinationSystem.runes => true,
      };
}
