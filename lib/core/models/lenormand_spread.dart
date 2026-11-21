import 'dart:ui' show Offset;

/// The canonical Petit Lenormand spread templates — all open without
/// subscription. Pure Dart; real board geometry lives in `shuffle_physics.dart`.
enum LenormandSpread {
  one(
    '1 · Daily Sign',
    1,
    false,
    ['Today’s Sign'],
    'A single card to read the weather of the day.',
    ['Sign'],
    [Offset(0.5, 0.5)],
  ),
  three(
    '3 · Lenormand Line',
    3,
    false,
    ['Past', 'Present', 'Future'],
    'The classic three-card line: what has been, what is, what comes.',
    ['Past', 'Present', 'Future'],
    [Offset(0.08, 0.5), Offset(0.5, 0.5), Offset(0.92, 0.5)],
  ),
  five(
    '5 · Cross of 5',
    5,
    false,
    ['The Matter', 'What Crosses It', 'The Root', 'What Passes', 'The Crown'],
    'The Cross of 5: the matter, the forces crossing it, and the path through.',
    ['Matter', 'Cross', 'Root', 'Passes', 'Crown'],
    [
      Offset(0.5, 0.5),
      Offset(0.5, 0.1),
      Offset(0.1, 0.5),
      Offset(0.9, 0.5),
      Offset(0.5, 0.9),
    ],
  ),
  nine(
    '9 · 3×3 Portrait Box',
    9,
    false,
    [
      'Past',
      'Present',
      'Future',
      'What You Hide',
      'The Querent',
      'What You Show',
      'Hopes',
      'Fears',
      'Outcome',
    ],
    'The 3×3 portrait box: a full map of the querent’s situation.',
    ['Past', 'Present', 'Future', 'Hide', 'Querent', 'Show', 'Hopes', 'Fears', 'Outcome'],
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
    '9 · Grand Portrait',
    9,
    false,
    [
      'The House',
      'The Heart',
      'The Mind',
      'The Body',
      'The Soul',
      'The Path',
      'The Key',
      'The Ring',
      'The Star',
    ],
    'The Grand Portrait: a nine-card map of the querent’s inner and outer world.',
    ['House', 'Heart', 'Mind', 'Body', 'Soul', 'Path', 'Key', 'Ring', 'Star'],
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

  /// Always false: all preset Lenormand spreads are open without subscription.
  final bool isPro;
  final List<String> slotRoles;
  final String focusLine;

  /// Compact single-word role per slot for the overview slot labels.
  final List<String> slotRoleShorts;

  /// Normalized (0..1) slot coordinates for the miniature wireframe.
  final List<Offset> miniSlots;
}

/// Maps a scanned Lenormand card count to the closest spread template.
LenormandSpread lenormandSpreadForCount(int count) => switch (count) {
      1 => LenormandSpread.one,
      3 => LenormandSpread.three,
      5 => LenormandSpread.five,
      9 => LenormandSpread.nine,
      _ => LenormandSpread.three,
    };
