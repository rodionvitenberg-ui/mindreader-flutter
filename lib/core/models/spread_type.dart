import 'dart:ui' show Offset;

import 'tarot_card_model.dart';

/// The canonical Tarot spread templates — Free + PRO. Pure Dart; the
/// [miniSlots] values are NORMALIZED (0..1) slot coordinates used only by
/// the miniature wireframe preview in the blueprint carousel.
enum SpreadType {
  one(
    '1 · Daily Anchor',
    1,
    false,
    ['Core Daily Impulse'],
    'A single card to anchor the day — one question, one answer.',
    ['Impulse'],
    [Offset(0.5, 0.5)],
  ),
  three(
    '3 · Triad Flow',
    3,
    false,
    ['Current State / Essence', 'Hidden Shadow / Block', 'Vector / Action'],
    'Where you stand, what quietly blocks you, and the move that unlocks it.',
    ['State', 'Shadow', 'Vector'],
    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  four(
    '4 · Target & Shadow',
    4,
    false,
    [
      'Your Shore',
      'The Other / Environment',
      'What Bridges or Blocks',
      'Turning Point',
    ],
    'The Two Shores Cross: the person on your mind and the bridge between you.',
    ['Shore', 'Other', 'Bridge', 'Turning'],
    [
      Offset(0.5, 0.1),
      Offset(0.1, 0.5),
      Offset(0.9, 0.5),
      Offset(0.5, 0.9),
    ],
  ),
  seven(
    '7 · Horseshoe Synthesis',
    7,
    false,
    [
      'Past',
      'Present',
      'Hidden Influences',
      'Obstacle',
      'External Forces',
      'Advice',
      'Outcome',
    ],
    'The Horseshoe: a deep vertical synthesis of the forces moving through the situation.',
    ['Past', 'Present', 'Hidden', 'Obstacle', 'Forces', 'Advice', 'Outcome'],
    [
      Offset(0.1, 0.12),
      Offset(0.5, 0.12),
      Offset(0.9, 0.12),
      Offset(0.5, 0.5),
      Offset(0.1, 0.88),
      Offset(0.5, 0.88),
      Offset(0.9, 0.88),
    ],
  ),
  loveBridge(
    '5 · Love & Relationship Bridge',
    5,
    true,
    [
      'Your Shore',
      'Their Shore',
      'The Bridge',
      'What Flows Between',
      'The Union',
    ],
    'Two shores and the bridge between: how two hearts meet, cross and join.',
    ['You', 'Them', 'Bridge', 'Flow', 'Union'],
    [
      Offset(0.12, 0.2),
      Offset(0.12, 0.8),
      Offset(0.5, 0.5),
      Offset(0.88, 0.2),
      Offset(0.88, 0.8),
    ],
  ),
  careerCrossroads(
    '6 · Career & Path Crossroads',
    6,
    true,
    [
      'The Root',
      'Present Path',
      'Alternate Path',
      'What Blocks',
      'The Reward',
      'The Destination',
    ],
    'A branching tree of paths: where the road splits and where each leads.',
    ['Root', 'Path A', 'Path B', 'Block', 'Reward', 'Destiny'],
    [
      Offset(0.5, 0.1),
      Offset(0.2, 0.45),
      Offset(0.8, 0.45),
      Offset(0.12, 0.88),
      Offset(0.5, 0.88),
      Offset(0.88, 0.88),
    ],
  ),
  celticCross(
    '10 · Celtic Cross',
    10,
    true,
    [
      'Significator',
      'Crossing',
      'Crown',
      'Foundation',
      'Past',
      'Future',
      'Self',
      'Environment',
      'Hopes & Fears',
      'Outcome',
    ],
    'The classic Celtic Cross: the situation crossed by its challenge, crowned and rooted.',
    ['Self', 'Cross', 'Crown', 'Root', 'Past', 'Future', 'You', 'World', 'Hopes', 'Outcome'],
    [
      Offset(0.375, 0.375),
      Offset(0.46, 0.29),
      Offset(0.375, 0.125),
      Offset(0.375, 0.625),
      Offset(0.125, 0.375),
      Offset(0.625, 0.375),
      Offset(0.875, 0.125),
      Offset(0.875, 0.375),
      Offset(0.875, 0.625),
      Offset(0.875, 0.875),
    ],
  );

  const SpreadType(
    this.label,
    this.cardCount,
    this.isPro,
    this.slotRoles,
    this.focusLine,
    this.slotRoleShorts,
    this.miniSlots,
  );

  /// Short pill label, e.g. "3 · Triad Flow".
  final String label;
  final int cardCount;

  /// True for the PRO-gated spreads (locked behind the shared PRO flag).
  final bool isPro;

  /// The role each slot plays in the reading, top to bottom.
  final List<String> slotRoles;

  /// What the reading focuses on (used by the oracle synthesis).
  final String focusLine;

  /// Compact single-word role per slot for the overview slot labels
  /// (`1 · State`, `2 · Shadow`, `3 · Vector`).
  final List<String> slotRoleShorts;

  /// Normalized (0..1) slot coordinates for the miniature wireframe.
  final List<Offset> miniSlots;
}

/// Suit ↔ element for minor arcana is defined on [SuitX.element].

/// Maps a scanned card count to the closest spread template (7 as the safe
/// fallback for non-standard counts).
SpreadType spreadTypeForCount(int count) => switch (count) {
      1 => SpreadType.one,
      3 => SpreadType.three,
      4 => SpreadType.four,
      5 => SpreadType.loveBridge,
      6 => SpreadType.careerCrossroads,
      10 => SpreadType.celticCross,
      _ => SpreadType.seven,
    };
