import 'dart:ui' show Offset;

import '../l10n/app_strings.dart';

/// The canonical Petit Lenormand spread templates — all open without
/// subscription. Pure Dart; real board geometry lives in `shuffle_physics.dart`.
enum LenormandSpread {
  one(
    'content.spread.lenormand.one.label',

    1,

    false,
    ['content.spread.lenormand.one.role.0'],
    'content.spread.lenormand.one.focus',
    ['content.spread.lenormand.one.short.0'],

    [Offset(0.5, 0.5)],
  ),
  three(
    'content.spread.lenormand.three.label',

    3,

    false,
    [
      'content.spread.lenormand.three.role.0',
      'content.spread.lenormand.three.role.1',
      'content.spread.lenormand.three.role.2',
    ],
    'content.spread.lenormand.three.focus',
    [
      'content.spread.lenormand.three.short.0',
      'content.spread.lenormand.three.short.1',
      'content.spread.lenormand.three.short.2',
    ],

    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  five(
    'content.spread.lenormand.five.label',

    5,

    false,
    [
      'content.spread.lenormand.five.role.0',
      'content.spread.lenormand.five.role.1',
      'content.spread.lenormand.five.role.2',
      'content.spread.lenormand.five.role.3',
      'content.spread.lenormand.five.role.4',
    ],
    'content.spread.lenormand.five.focus',
    [
      'content.spread.lenormand.five.short.0',
      'content.spread.lenormand.five.short.1',
      'content.spread.lenormand.five.short.2',
      'content.spread.lenormand.five.short.3',
      'content.spread.lenormand.five.short.4',
    ],

    [
      Offset(0.5, 0.5),
      Offset(0.5, 0.1),
      Offset(0.1, 0.5),
      Offset(0.9, 0.5),
      Offset(0.5, 0.9),
    ],
  ),
  nine(
    'content.spread.lenormand.nine.label',

    9,

    false,
    [
      'content.spread.lenormand.nine.role.0',
      'content.spread.lenormand.nine.role.1',
      'content.spread.lenormand.nine.role.2',
      'content.spread.lenormand.nine.role.3',
      'content.spread.lenormand.nine.role.4',
      'content.spread.lenormand.nine.role.5',
      'content.spread.lenormand.nine.role.6',
      'content.spread.lenormand.nine.role.7',
      'content.spread.lenormand.nine.role.8',
    ],
    'content.spread.lenormand.nine.focus',
    [
      'content.spread.lenormand.nine.short.0',
      'content.spread.lenormand.nine.short.1',
      'content.spread.lenormand.nine.short.2',
      'content.spread.lenormand.nine.short.3',
      'content.spread.lenormand.nine.short.4',
      'content.spread.lenormand.nine.short.5',
      'content.spread.lenormand.nine.short.6',
      'content.spread.lenormand.nine.short.7',
      'content.spread.lenormand.nine.short.8',
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
  ),
  grandPortrait(
    'content.spread.lenormand.grandPortrait.label',

    9,

    false,
    [
      'content.spread.lenormand.grandPortrait.role.0',
      'content.spread.lenormand.grandPortrait.role.1',
      'content.spread.lenormand.grandPortrait.role.2',
      'content.spread.lenormand.grandPortrait.role.3',
      'content.spread.lenormand.grandPortrait.role.4',
      'content.spread.lenormand.grandPortrait.role.5',
      'content.spread.lenormand.grandPortrait.role.6',
      'content.spread.lenormand.grandPortrait.role.7',
      'content.spread.lenormand.grandPortrait.role.8',
    ],
    'content.spread.lenormand.grandPortrait.focus',
    [
      'content.spread.lenormand.grandPortrait.short.0',
      'content.spread.lenormand.grandPortrait.short.1',
      'content.spread.lenormand.grandPortrait.short.2',
      'content.spread.lenormand.grandPortrait.short.3',
      'content.spread.lenormand.grandPortrait.short.4',
      'content.spread.lenormand.grandPortrait.short.5',
      'content.spread.lenormand.grandPortrait.short.6',
      'content.spread.lenormand.grandPortrait.short.7',
      'content.spread.lenormand.grandPortrait.short.8',
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

  const LenormandSpread(
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

  /// Always false: all preset Lenormand spreads are open without subscription.
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

/// Maps a scanned Lenormand card count to the closest spread template.
LenormandSpread lenormandSpreadForCount(int count) => switch (count) {
  1 => LenormandSpread.one,
  3 => LenormandSpread.three,
  5 => LenormandSpread.five,
  9 => LenormandSpread.nine,
  _ => LenormandSpread.three,
};
