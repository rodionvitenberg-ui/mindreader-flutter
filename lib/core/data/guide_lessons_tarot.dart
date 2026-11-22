import '../models/guide_line.dart';

/// G4 — "why this position matters" for every Tarot slot, EN + RU.
///
/// Keys are `SpreadType.name` values. The EN side is the long-standing copy
/// (previously in `spread_type.dart`); RU is authored to match it sentence by
/// sentence.
const Map<String, List<GuideLine>> tarotSlotLessons = {
  'one': [GuideLine('content.lesson.tarot.one.0')],
  'three': [
    GuideLine('content.lesson.tarot.three.0'),
    GuideLine('content.lesson.tarot.three.1'),
    GuideLine('content.lesson.tarot.three.2'),
  ],
  'four': [
    GuideLine('content.lesson.tarot.four.0'),
    GuideLine('content.lesson.tarot.four.1'),
    GuideLine('content.lesson.tarot.four.2'),
    GuideLine('content.lesson.tarot.four.3'),
  ],
  'seven': [
    GuideLine('content.lesson.tarot.seven.0'),
    GuideLine('content.lesson.tarot.seven.1'),
    GuideLine('content.lesson.tarot.seven.2'),
    GuideLine('content.lesson.tarot.seven.3'),
    GuideLine('content.lesson.tarot.seven.4'),
    GuideLine('content.lesson.tarot.seven.5'),
    GuideLine('content.lesson.tarot.seven.6'),
  ],
  'loveBridge': [
    GuideLine('content.lesson.tarot.loveBridge.0'),
    GuideLine('content.lesson.tarot.loveBridge.1'),
    GuideLine('content.lesson.tarot.loveBridge.2'),
    GuideLine('content.lesson.tarot.loveBridge.3'),
    GuideLine('content.lesson.tarot.loveBridge.4'),
  ],
  'careerCrossroads': [
    GuideLine('content.lesson.tarot.careerCrossroads.0'),
    GuideLine('content.lesson.tarot.careerCrossroads.1'),
    GuideLine('content.lesson.tarot.careerCrossroads.2'),
    GuideLine('content.lesson.tarot.careerCrossroads.3'),
    GuideLine('content.lesson.tarot.careerCrossroads.4'),
    GuideLine('content.lesson.tarot.careerCrossroads.5'),
  ],
  'celticCross': [
    GuideLine('content.lesson.tarot.celticCross.0'),
    GuideLine('content.lesson.tarot.celticCross.1'),
    GuideLine('content.lesson.tarot.celticCross.2'),
    GuideLine('content.lesson.tarot.celticCross.3'),
    GuideLine('content.lesson.tarot.celticCross.4'),
    GuideLine('content.lesson.tarot.celticCross.5'),
    GuideLine('content.lesson.tarot.celticCross.6'),
    GuideLine('content.lesson.tarot.celticCross.7'),
    GuideLine('content.lesson.tarot.celticCross.8'),
    GuideLine('content.lesson.tarot.celticCross.9'),
  ],
};

/// Why each Tarot spread exists and how it wants to be read (EN + RU).
/// Keys are `SpreadType.name` values.
const Map<String, GuideLine> tarotPurposeLines = {
  'one': GuideLine('content.purpose.tarot.one'),
  'three': GuideLine('content.purpose.tarot.three'),
  'four': GuideLine('content.purpose.tarot.four'),
  'seven': GuideLine('content.purpose.tarot.seven'),
  'loveBridge': GuideLine('content.purpose.tarot.loveBridge'),
  'careerCrossroads': GuideLine('content.purpose.tarot.careerCrossroads'),
  'celticCross': GuideLine('content.purpose.tarot.celticCross'),
};

/// G4.2 — how to read two cards that pull in different directions (opposing
/// elemental dignities): name both demands, then read the tension.
const GuideLine tarotConflictLesson = GuideLine('content.lesson.tarot.conflict');

/// G4.2 — the dignity method is one tradition, not a law; the app names the
/// school it teaches so a modern reading is never presented as wrong.
const GuideLine tarotSchoolLesson = GuideLine('content.lesson.tarot.school');
