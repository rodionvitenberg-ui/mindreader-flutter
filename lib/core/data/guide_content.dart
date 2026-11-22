import '../l10n/app_strings.dart';
import '../models/divination_system.dart';
import '../models/guide_line.dart';
import 'guide_lessons_lenormand.dart';
import 'guide_lessons_runes.dart';
import 'guide_lessons_tarot.dart';

/// The single lookup surface for the Guided Reading curriculum (G4).
///
/// Content lives in per-system data files keyed by enum `name`; this file only
/// resolves (system, spread, slot) → localized line. Custom spreads are the
/// reader's own questions and deliberately have no authored lessons.

/// Lessons for one preset spread, indexed by slot. Null for custom spreads or
/// unknown keys.
List<GuideLine>? guideSlotLessons(
  DivinationSystem system,
  String spreadKey,
) => switch (system) {
  DivinationSystem.tarot => tarotSlotLessons[spreadKey],
  DivinationSystem.lenormand => lenormandSlotLessons[spreadKey],
  DivinationSystem.runes => runeSlotLessons[spreadKey],
};

/// Why this spread exists and how it wants to be read. Null when nothing is
/// authored for the pair.
GuideLine? guidePurposeLine(DivinationSystem system, String spreadKey) =>
    switch (system) {
      DivinationSystem.tarot => tarotPurposeLines[spreadKey],
      DivinationSystem.lenormand => lenormandPurposeLines[spreadKey],
      DivinationSystem.runes => runePurposeLines[spreadKey],
    };

/// The lesson for [slot] (0-based) in [lang], or null when the spread has no
/// authored lesson there (custom spreads, out-of-range slots).
String? guideSlotLesson({
  required DivinationSystem system,
  required String spreadKey,
  required int slot,
  required AppLanguage lang,
}) {
  final lessons = guideSlotLessons(system, spreadKey);
  if (lessons == null || slot < 0 || slot >= lessons.length) return null;
  return lessons[slot].forLanguage(lang);
}

/// How to read two cards pulling in different directions. Only Tarot assigns
/// elemental dignities today, so only Tarot can contradict itself (G4.2).
GuideLine? guideConflictLesson(DivinationSystem system) =>
    system == DivinationSystem.tarot ? tarotConflictLesson : null;

/// "Tradition vs modern school" for the active method — a separate lesson that
/// follows the conflict one (G4.2). Null where no authored note exists.
GuideLine? guideSchoolLesson(DivinationSystem system) =>
    system == DivinationSystem.tarot ? tarotSchoolLesson : null;
