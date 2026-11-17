/// The four canonical Petit Lenormand spread templates. Pure Dart.
enum LenormandSpread {
  one('1 · Daily Sign', 1, ['Today’s Sign'],
      'A single card to read the weather of the day.'),
  three('3 · Lenormand Line', 3, ['Past', 'Present', 'Future'],
      'The classic three-card line: what has been, what is, what comes.'),
  five('5 · Cross of 5', 5,
      ['The Matter', 'What Crosses It', 'The Root', 'What Passes', 'The Crown'],
      'The Cross of 5: the matter, the forces crossing it, and the path through.'),
  nine('9 · 3×3 Portrait Box', 9,
      ['Past', 'Present', 'Future', 'What You Hide', 'The Querent',
          'What You Show', 'Hopes', 'Fears', 'Outcome'],
      'The 3×3 portrait box: a full map of the querent’s situation.'),
  ;

  const LenormandSpread(this.label, this.cardCount, this.slotRoles, this.focusLine);

  final String label;
  final int cardCount;
  final List<String> slotRoles;
  final String focusLine;
}

/// Maps a scanned Lenormand card count to the closest spread template.
LenormandSpread lenormandSpreadForCount(int count) => switch (count) {
      1 => LenormandSpread.one,
      3 => LenormandSpread.three,
      5 => LenormandSpread.five,
      9 => LenormandSpread.nine,
      _ => LenormandSpread.three,
    };
