/// The three authentic divination systems supported by the Digital Table,
/// Oracle Chat, Session History and Almanac. Pure Dart — no Flutter imports.
enum DivinationSystem { tarot, lenormand, runes }

extension DivinationSystemX on DivinationSystem {
  /// Uppercase segment label, e.g. 'TAROT'.
  String get label => switch (this) {
        DivinationSystem.tarot => 'TAROT',
        DivinationSystem.lenormand => 'LENORMAND',
        DivinationSystem.runes => 'RUNES',
      };

  /// Full canonical dataset size: 78 tarot cards, 36 Lenormand cards,
  /// 24 Elder Futhark runes.
  int get deckSize => switch (this) {
        DivinationSystem.tarot => 78,
        DivinationSystem.lenormand => 36,
        DivinationSystem.runes => 24,
      };

  /// What a single drawn piece is called (used in pills and prompts).
  String get unit => switch (this) {
        DivinationSystem.tarot => 'card',
        DivinationSystem.lenormand => 'card',
        DivinationSystem.runes => 'rune',
      };

  /// Pill glyph prefix: cards for Tarot/Lenormand, stones for Runes.
  String get packGlyph => switch (this) {
        DivinationSystem.tarot => '🎴',
        DivinationSystem.lenormand => '🎴',
        DivinationSystem.runes => '🪨',
      };

  /// Deal hint shown on the live counter badge under the deck/cluster.
  String get dealHint => switch (this) {
        DivinationSystem.tarot => 'SWIPE ↓ TO DEAL',
        DivinationSystem.lenormand => 'SWIPE ↓ TO DEAL',
        DivinationSystem.runes => 'SWIPE ↓ TO CAST',
      };

  /// True when drawn pieces of this system may land reversed.
  /// Lenormand is always upright; tarot and (non-symmetrical) runes flip.
  bool get systemSupportsReversals => switch (this) {
        DivinationSystem.tarot => true,
        DivinationSystem.lenormand => false,
        DivinationSystem.runes => true,
      };
}
