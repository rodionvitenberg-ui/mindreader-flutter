import 'dart:ui' show Offset;

import '../l10n/app_strings.dart';
import 'tarot_card_model.dart';

/// The canonical Tarot spread templates — all open without subscription.
/// Pure Dart; real board geometry lives in `shuffle_physics.dart` and drives
/// both the active Table and the picker miniatures.
enum SpreadType {
  one(
    'content.spread.tarot.one.label',

    1,

    false,
    ['content.spread.tarot.one.role.0'],
    'content.spread.tarot.one.focus',
    ['content.spread.tarot.one.short.0'],

    [Offset(0.5, 0.5)],
  ),
  three(
    'content.spread.tarot.three.label',

    3,

    false,
    [
      'content.spread.tarot.three.role.0',
      'content.spread.tarot.three.role.1',
      'content.spread.tarot.three.role.2',
    ],
    'content.spread.tarot.three.focus',
    [
      'content.spread.tarot.three.short.0',
      'content.spread.tarot.three.short.1',
      'content.spread.tarot.three.short.2',
    ],

    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  four(
    'content.spread.tarot.four.label',

    4,

    false,
    [
      'content.spread.tarot.four.role.0',
      'content.spread.tarot.four.role.1',
      'content.spread.tarot.four.role.2',
      'content.spread.tarot.four.role.3',
    ],
    'content.spread.tarot.four.focus',
    [
      'content.spread.tarot.four.short.0',
      'content.spread.tarot.four.short.1',
      'content.spread.tarot.four.short.2',
      'content.spread.tarot.four.short.3',
    ],

    [Offset(0.5, 0.1), Offset(0.1, 0.5), Offset(0.9, 0.5), Offset(0.5, 0.9)],
  ),
  seven(
    'content.spread.tarot.seven.label',

    7,

    false,
    [
      'content.spread.tarot.seven.role.0',
      'content.spread.tarot.seven.role.1',
      'content.spread.tarot.seven.role.2',
      'content.spread.tarot.seven.role.3',
      'content.spread.tarot.seven.role.4',
      'content.spread.tarot.seven.role.5',
      'content.spread.tarot.seven.role.6',
    ],
    'content.spread.tarot.seven.focus',
    [
      'content.spread.tarot.seven.short.0',
      'content.spread.tarot.seven.short.1',
      'content.spread.tarot.seven.short.2',
      'content.spread.tarot.seven.short.3',
      'content.spread.tarot.seven.short.4',
      'content.spread.tarot.seven.short.5',
      'content.spread.tarot.seven.short.6',
    ],

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
    'content.spread.tarot.loveBridge.label',

    5,

    false,
    [
      'content.spread.tarot.loveBridge.role.0',
      'content.spread.tarot.loveBridge.role.1',
      'content.spread.tarot.loveBridge.role.2',
      'content.spread.tarot.loveBridge.role.3',
      'content.spread.tarot.loveBridge.role.4',
    ],
    'content.spread.tarot.loveBridge.focus',
    [
      'content.spread.tarot.loveBridge.short.0',
      'content.spread.tarot.loveBridge.short.1',
      'content.spread.tarot.loveBridge.short.2',
      'content.spread.tarot.loveBridge.short.3',
      'content.spread.tarot.loveBridge.short.4',
    ],

    [
      Offset(0.12, 0.2),
      Offset(0.12, 0.8),
      Offset(0.5, 0.5),
      Offset(0.88, 0.2),
      Offset(0.88, 0.8),
    ],
  ),
  careerCrossroads(
    'content.spread.tarot.careerCrossroads.label',

    6,

    false,
    [
      'content.spread.tarot.careerCrossroads.role.0',
      'content.spread.tarot.careerCrossroads.role.1',
      'content.spread.tarot.careerCrossroads.role.2',
      'content.spread.tarot.careerCrossroads.role.3',
      'content.spread.tarot.careerCrossroads.role.4',
      'content.spread.tarot.careerCrossroads.role.5',
    ],
    'content.spread.tarot.careerCrossroads.focus',
    [
      'content.spread.tarot.careerCrossroads.short.0',
      'content.spread.tarot.careerCrossroads.short.1',
      'content.spread.tarot.careerCrossroads.short.2',
      'content.spread.tarot.careerCrossroads.short.3',
      'content.spread.tarot.careerCrossroads.short.4',
      'content.spread.tarot.careerCrossroads.short.5',
    ],

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
    'content.spread.tarot.celticCross.label',

    10,

    false,
    [
      'content.spread.tarot.celticCross.role.0',
      'content.spread.tarot.celticCross.role.1',
      'content.spread.tarot.celticCross.role.2',
      'content.spread.tarot.celticCross.role.3',
      'content.spread.tarot.celticCross.role.4',
      'content.spread.tarot.celticCross.role.5',
      'content.spread.tarot.celticCross.role.6',
      'content.spread.tarot.celticCross.role.7',
      'content.spread.tarot.celticCross.role.8',
      'content.spread.tarot.celticCross.role.9',
    ],
    'content.spread.tarot.celticCross.focus',
    [
      'content.spread.tarot.celticCross.short.0',
      'content.spread.tarot.celticCross.short.1',
      'content.spread.tarot.celticCross.short.2',
      'content.spread.tarot.celticCross.short.3',
      'content.spread.tarot.celticCross.short.4',
      'content.spread.tarot.celticCross.short.5',
      'content.spread.tarot.celticCross.short.6',
      'content.spread.tarot.celticCross.short.7',
      'content.spread.tarot.celticCross.short.8',
      'content.spread.tarot.celticCross.short.9',
    ],

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
    this.labelKey,
    this.cardCount,
    this.isPro,
    this.slotRoleKeys,
    this.focusKey,
    this.slotRoleShortKeys,
    this.miniSlots,
  );

  /// Short pill label, e.g. "3 · Three Cards".
  final String labelKey;
  final int cardCount;

  /// Always false: all preset spread schemas are open without subscription.
  final bool isPro;

  /// The role each slot plays in the reading, top to bottom.
  final List<String> slotRoleKeys;

  /// What the reading focuses on (used by the oracle synthesis).
  final String focusKey;

  /// Compact single-word role per slot for the overview slot labels
  /// (`1 · State`, `2 · Shadow`, `3 · Vector`).
  final List<String> slotRoleShortKeys;

  /// Normalized (0..1) slot coordinates for the miniature wireframe.
  final List<Offset> miniSlots;

  String get label => AppStrings.g(labelKey);
  List<String> get slotRoles => [
    for (final key in slotRoleKeys) AppStrings.g(key),
  ];
  String get focusLine => AppStrings.g(focusKey);
  List<String> get slotRoleShorts => [
    for (final key in slotRoleShortKeys) AppStrings.g(key),
  ];
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
