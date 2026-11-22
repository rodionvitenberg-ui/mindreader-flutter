import '../models/guide_line.dart';

/// G4 — per-position lessons for the Elder Futhark casts, EN + RU.
///
/// Keys are `RuneCast.name` values. Runes are read as verbs and forces, with
/// merkstave only for the eight asymmetric stones — the lessons ask the
/// question each position poses, never a fixed fate.
const Map<String, List<GuideLine>> runeSlotLessons = {
  'one': [GuideLine('content.lesson.runes.one.0')],
  'three': [
    GuideLine('content.lesson.runes.three.0'),
    GuideLine('content.lesson.runes.three.1'),
    GuideLine('content.lesson.runes.three.2'),
  ],
  'five': [
    GuideLine('content.lesson.runes.five.0'),
    GuideLine('content.lesson.runes.five.1'),
    GuideLine('content.lesson.runes.five.2'),
    GuideLine('content.lesson.runes.five.3'),
    GuideLine('content.lesson.runes.five.4'),
  ],
  'seven': [
    GuideLine('content.lesson.runes.seven.0'),
    GuideLine('content.lesson.runes.seven.1'),
    GuideLine('content.lesson.runes.seven.2'),
    GuideLine('content.lesson.runes.seven.3'),
    GuideLine('content.lesson.runes.seven.4'),
    GuideLine('content.lesson.runes.seven.5'),
    GuideLine('content.lesson.runes.seven.6'),
  ],
  'worldTree': [
    GuideLine('content.lesson.runes.worldTree.0'),
    GuideLine('content.lesson.runes.worldTree.1'),
    GuideLine('content.lesson.runes.worldTree.2'),
    GuideLine('content.lesson.runes.worldTree.3'),
    GuideLine('content.lesson.runes.worldTree.4'),
    GuideLine('content.lesson.runes.worldTree.5'),

    GuideLine('content.lesson.runes.worldTree.6'),
    GuideLine('content.lesson.runes.worldTree.7'),
    GuideLine('content.lesson.runes.worldTree.8'),
  ],
};

/// Why each rune cast exists and how it wants to be read (EN + RU).
/// Keys are `RuneCast.name` values.
const Map<String, GuideLine> runePurposeLines = {
  'one': GuideLine('content.purpose.runes.one'),
  'three': GuideLine('content.purpose.runes.three'),
  'five': GuideLine('content.purpose.runes.five'),
  'seven': GuideLine('content.purpose.runes.seven'),
  'worldTree': GuideLine('content.purpose.runes.worldTree'),
};
