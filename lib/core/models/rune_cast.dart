import 'dart:ui' show Offset;

import '../l10n/app_strings.dart';

/// The canonical Elder Futhark rune casts — all open without subscription.
/// Pure Dart; real board geometry lives in `shuffle_physics.dart`.
enum RuneCast {
  one(
    'content.spread.runes.one.label',

    1,

    false,
    ['content.spread.runes.one.role.0'],
    'content.spread.runes.one.focus',
    ['content.spread.runes.one.short.0'],

    [Offset(0.5, 0.5)],
  ),
  three(
    'content.spread.runes.three.label',

    3,

    false,
    [
      'content.spread.runes.three.role.0',
      'content.spread.runes.three.role.1',
      'content.spread.runes.three.role.2',
    ],
    'content.spread.runes.three.focus',
    [
      'content.spread.runes.three.short.0',
      'content.spread.runes.three.short.1',
      'content.spread.runes.three.short.2',
    ],

    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  five(
    'content.spread.runes.five.label',

    5,

    false,
    [
      'content.spread.runes.five.role.0',
      'content.spread.runes.five.role.1',
      'content.spread.runes.five.role.2',
      'content.spread.runes.five.role.3',
      'content.spread.runes.five.role.4',
    ],
    'content.spread.runes.five.focus',
    [
      'content.spread.runes.five.short.0',
      'content.spread.runes.five.short.1',
      'content.spread.runes.five.short.2',
      'content.spread.runes.five.short.3',
      'content.spread.runes.five.short.4',
    ],

    [
      Offset(0.5, 0.5),
      Offset(0.5, 0.1),
      Offset(0.1, 0.5),
      Offset(0.9, 0.5),
      Offset(0.5, 0.9),
    ],
  ),
  seven(
    'content.spread.runes.seven.label',

    7,

    false,
    [
      'content.spread.runes.seven.role.0',
      'content.spread.runes.seven.role.1',
      'content.spread.runes.seven.role.2',
      'content.spread.runes.seven.role.3',
      'content.spread.runes.seven.role.4',
      'content.spread.runes.seven.role.5',
      'content.spread.runes.seven.role.6',
    ],
    'content.spread.runes.seven.focus',
    [
      'content.spread.runes.seven.short.0',
      'content.spread.runes.seven.short.1',
      'content.spread.runes.seven.short.2',
      'content.spread.runes.seven.short.3',
      'content.spread.runes.seven.short.4',
      'content.spread.runes.seven.short.5',
      'content.spread.runes.seven.short.6',
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
  worldTree(
    'content.spread.runes.worldTree.label',

    9,

    false,
    [
      'content.spread.runes.worldTree.role.0',
      'content.spread.runes.worldTree.role.1',
      'content.spread.runes.worldTree.role.2',
      'content.spread.runes.worldTree.role.3',
      'content.spread.runes.worldTree.role.4',
      'content.spread.runes.worldTree.role.5',
      'content.spread.runes.worldTree.role.6',
      'content.spread.runes.worldTree.role.7',
      'content.spread.runes.worldTree.role.8',
    ],
    'content.spread.runes.worldTree.focus',
    [
      'content.spread.runes.worldTree.short.0',
      'content.spread.runes.worldTree.short.1',
      'content.spread.runes.worldTree.short.2',
      'content.spread.runes.worldTree.short.3',
      'content.spread.runes.worldTree.short.4',
      'content.spread.runes.worldTree.short.5',
      'content.spread.runes.worldTree.short.6',
      'content.spread.runes.worldTree.short.7',
      'content.spread.runes.worldTree.short.8',
    ],

    [
      Offset(0.1, 0.1),
      Offset(0.5, 0.1),
      Offset(0.9, 0.1),
      Offset(0.1, 0.5),
      Offset(0.5, 0.5),
      Offset(0.9, 0.5),
      Offset(0.1, 0.9),
      Offset(0.5, 0.9),
      Offset(0.9, 0.9),
    ],
  );

  const RuneCast(
    this.labelKey,
    this.cardCount,
    this.isPro,
    this.slotRoleKeys,
    this.focusKey,
    this.slotRoleShortKeys,
    this.miniSlots,
  );

  final String labelKey;
  final int cardCount;

  /// Always false: all preset rune casts are open without subscription.
  final bool isPro;
  final List<String> slotRoleKeys;
  final String focusKey;

  /// Compact single-word role per slot for the overview slot labels.
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

/// Maps a scanned rune count to the closest canonical cast.
RuneCast runeCastForCount(int count) => switch (count) {
  1 => RuneCast.one,
  3 => RuneCast.three,
  5 => RuneCast.five,
  7 => RuneCast.seven,
  _ => RuneCast.three,
};
