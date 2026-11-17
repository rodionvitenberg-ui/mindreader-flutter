/// The four canonical Elder Futhark rune casts. Pure Dart.
enum RuneCast {
  one('1 · Odin’s Rune', 1, ['The Whisper of Odin'],
      'One stone for one question — the oldest draw.'),
  three('3 · The Three Norns', 3, ['Urd — What Was', 'Verdandi — What Is',
          'Skuld — What Becomes'],
      'The Norns weave what was, what is, and what becomes.'),
  five('5 · Thor’s Cross', 5, ['The Hammer', 'The Storm', 'The Shield',
          'The Foe', 'The Lightning'],
      'Thor’s Cross: the storm, its defense, its foe and its strike.'),
  seven('7 · Heimdall’s Bridge', 7, ['The Gate', 'The Watcher', 'The Path',
          'The Toll', 'The Dawn', 'The Warning', 'The Return'],
      'Heimdall’s Bridge: seven stones across Bifröst.'),
  ;

  const RuneCast(this.label, this.cardCount, this.slotRoles, this.focusLine);

  final String label;
  final int cardCount;
  final List<String> slotRoles;
  final String focusLine;
}

/// Maps a scanned rune count to the closest canonical cast.
RuneCast runeCastForCount(int count) => switch (count) {
      1 => RuneCast.one,
      3 => RuneCast.three,
      5 => RuneCast.five,
      7 => RuneCast.seven,
      _ => RuneCast.three,
    };
