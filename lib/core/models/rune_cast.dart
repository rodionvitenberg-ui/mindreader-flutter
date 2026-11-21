import 'dart:ui' show Offset;

/// The canonical Elder Futhark rune casts — all open without subscription.
/// Pure Dart; real board geometry lives in `shuffle_physics.dart`.
enum RuneCast {
  one(
    '1 · Odin’s Rune',
    1,
    false,
    ['The Whisper of Odin'],
    'One stone for one question — the oldest draw.',
    ['Odin'],
    [Offset(0.5, 0.5)],
  ),
  three(
    '3 · The Three Norns',
    3,
    false,
    ['Urd — What Was', 'Verdandi — What Is', 'Skuld — What Becomes'],
    'The Norns weave what was, what is, and what becomes.',
    ['Urd', 'Verdandi', 'Skuld'],
    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  five(
    '5 · Thor’s Cross',
    5,
    false,
    ['The Hammer', 'The Storm', 'The Shield', 'The Foe', 'The Lightning'],
    'Thor’s Cross: the storm, its defense, its foe and its strike.',
    ['Hammer', 'Storm', 'Shield', 'Foe', 'Lightning'],
    [
      Offset(0.5, 0.5),
      Offset(0.5, 0.1),
      Offset(0.1, 0.5),
      Offset(0.9, 0.5),
      Offset(0.5, 0.9),
    ],
  ),
  seven(
    '7 · Heimdall’s Bridge',
    7,
    false,
    [
      'The Gate',
      'The Watcher',
      'The Path',
      'The Toll',
      'The Dawn',
      'The Warning',
      'The Return',
    ],
    'Heimdall’s Bridge: seven stones across Bifröst.',
    ['Gate', 'Watcher', 'Path', 'Toll', 'Dawn', 'Warning', 'Return'],
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
    '9 · Yggdrasil’s World Tree',
    9,
    false,
    [
      'Asgard',
      'Midgard',
      'Hel',
      'The Roots',
      'The Trunk',
      'The Branches',
      'Fate',
      'Wyrd',
      'The Seed',
    ],
    'Yggdrasil’s World Tree: nine stones across the roots, trunk and branches of the cosmos.',
    ['Asgard', 'Midgard', 'Hel', 'Roots', 'Trunk', 'Branches', 'Fate', 'Wyrd', 'Seed'],
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
    this.label,
    this.cardCount,
    this.isPro,
    this.slotRoles,
    this.focusLine,
    this.slotRoleShorts,
    this.miniSlots,
  );

  final String label;
  final int cardCount;

  /// Always false: all preset rune casts are open without subscription.
  final bool isPro;
  final List<String> slotRoles;
  final String focusLine;

  /// Compact single-word role per slot for the overview slot labels.
  final List<String> slotRoleShorts;

  /// Normalized (0..1) slot coordinates for the miniature wireframe.
  final List<Offset> miniSlots;
}

/// Maps a scanned rune count to the closest canonical cast.
RuneCast runeCastForCount(int count) => switch (count) {
      1 => RuneCast.one,
      3 => RuneCast.three,
      5 => RuneCast.five,
      7 => RuneCast.seven,
      _ => RuneCast.three,
    };
