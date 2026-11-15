import 'tarot_card_model.dart';

/// The four spread templates. Pure Dart — no Flutter imports.
enum SpreadType { one, three, four, seven }

extension SpreadTypeX on SpreadType {
  int get cardCount => switch (this) {
        SpreadType.one => 1,
        SpreadType.three => 3,
        SpreadType.four => 4,
        SpreadType.seven => 7,
      };

  /// Short pill label, e.g. "3 · Triad Flow".
  String get label => switch (this) {
        SpreadType.one => '1 · Daily Anchor',
        SpreadType.three => '3 · Triad Flow',
        SpreadType.four => '4 · Target & Shadow',
        SpreadType.seven => '7 · Deep Synthesis',
      };

  /// The role each slot plays in the reading, top to bottom.
  List<String> get slotRoles => switch (this) {
        SpreadType.one => const ['Daily Anchor'],
        SpreadType.three => const [
            'Current State',
            'Hidden Barrier',
            'Action Vector',
          ],
        SpreadType.four => const [
            'The Person / Target',
            'Their Visible Stance',
            'Their Hidden Shadow',
            'The Path Forward',
          ],
        SpreadType.seven => const [
            'The Heart of the Matter',
            'The Crossing Influence',
            'The Root',
            'The Recent Past',
            'The Potential',
            'The Near Future',
            'The Outcome',
          ],
      };

  /// What the reading focuses on (used by the oracle synthesis).
  String get focusLine => switch (this) {
        SpreadType.one =>
          'A single card to anchor the day — one question, one answer.',
        SpreadType.three =>
          'Where you stand, what quietly blocks you, and the move that unlocks it.',
        SpreadType.four =>
          'The person on your mind, seen through three analytical lenses.',
        SpreadType.seven =>
          'A deep vertical synthesis of the forces moving through the situation.',
      };
}

/// Suit ↔ element for minor arcana is defined on [SuitX.element].

/// Maps a scanned card count to the closest spread template (7 as the safe
/// fallback for non-standard counts).
SpreadType spreadTypeForCount(int count) => switch (count) {
      1 => SpreadType.one,
      3 => SpreadType.three,
      4 => SpreadType.four,
      _ => SpreadType.seven,
    };
