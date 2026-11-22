import '../models/guide_line.dart';

/// G4 — per-slot lessons for the Lenormand spreads, EN + RU.
///
/// Keys are `LenormandSpread.name` values. Lenormand is read as nouns and
/// noun-pairs (never reversals), so the lessons teach the *question* each
/// position asks, not an esoteric meaning.
const Map<String, List<GuideLine>> lenormandSlotLessons = {
  'one': [GuideLine('content.lesson.lenormand.one.0')],
  'three': [
    GuideLine('content.lesson.lenormand.three.0'),
    GuideLine('content.lesson.lenormand.three.1'),
    GuideLine('content.lesson.lenormand.three.2'),
  ],
  'five': [
    GuideLine('content.lesson.lenormand.five.0'),
    GuideLine('content.lesson.lenormand.five.1'),
    GuideLine('content.lesson.lenormand.five.2'),
    GuideLine('content.lesson.lenormand.five.3'),
    GuideLine('content.lesson.lenormand.five.4'),
  ],
  'nine': [
    GuideLine('content.lesson.lenormand.nine.0'),
    GuideLine('content.lesson.lenormand.nine.1'),
    GuideLine('content.lesson.lenormand.nine.2'),
    GuideLine('content.lesson.lenormand.nine.3'),
    GuideLine('content.lesson.lenormand.nine.4'),
    GuideLine('content.lesson.lenormand.nine.5'),
    GuideLine('content.lesson.lenormand.nine.6'),
    GuideLine('content.lesson.lenormand.nine.7'),
    GuideLine('content.lesson.lenormand.nine.8'),
  ],
  'grandPortrait': [
    GuideLine('content.lesson.lenormand.grandPortrait.0'),
    GuideLine('content.lesson.lenormand.grandPortrait.1'),
    GuideLine('content.lesson.lenormand.grandPortrait.2'),
    GuideLine('content.lesson.lenormand.grandPortrait.3'),
    GuideLine('content.lesson.lenormand.grandPortrait.4'),
    GuideLine('content.lesson.lenormand.grandPortrait.5'),

    GuideLine('content.lesson.lenormand.grandPortrait.6'),
    GuideLine('content.lesson.lenormand.grandPortrait.7'),
    GuideLine('content.lesson.lenormand.grandPortrait.8'),
  ],
};

/// Why each Lenormand spread exists and how it wants to be read (EN + RU).
/// Keys are `LenormandSpread.name` values.
const Map<String, GuideLine> lenormandPurposeLines = {
  'one': GuideLine('content.purpose.lenormand.one'),
  'three': GuideLine('content.purpose.lenormand.three'),
  'five': GuideLine('content.purpose.lenormand.five'),
  'nine': GuideLine('content.purpose.lenormand.nine'),
  'grandPortrait': GuideLine('content.purpose.lenormand.grandPortrait'),
};
