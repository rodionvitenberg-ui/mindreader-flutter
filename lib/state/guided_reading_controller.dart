import 'package:flutter/foundation.dart';

import '../core/data/guide_content.dart';
import '../core/data/guide_copy.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/divination_system.dart';
import '../core/models/guide_event.dart';
import '../core/models/guide_hint.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/reading_relationships.dart';
import 'app_settings_controller.dart';
import 'spread_controller.dart';

/// Computes the single most relevant educational hint for the Digital Table.
///
/// It is a pure observer of [SpreadController] and [AppSettingsController]: it
/// never mutates cards or their order, never advances the deck, and never
/// blocks the reader. The UI renders [currentHint] and can call
/// [explainRelationship] when the reader taps an elemental/positional branch.
///
/// Conceptual lessons ("what does this position mean") are taught once: a
/// lesson is recorded as read when the reader opens the hint sheet
/// ([learnCurrentLesson]) and is remembered across sessions in
/// `guided_seen_v1` until [resetLearned].
class GuidedReadingController extends ChangeNotifier {
  GuidedReadingController({
    required this.spread,
    required this.settings,
    LocalStorageService? storage,
  }) : _storage = storage ?? LocalStorageService() {
    spread.addListener(_recompute);
    settings.addListener(_recompute);
    initialLoad = _restoreLearned();
    _recompute();
  }

  final SpreadController spread;
  final AppSettingsController settings;
  final LocalStorageService _storage;

  /// Completes once the persisted lesson memory has been restored.
  late final Future<void> initialLoad;

  /// Lesson ids the reader has already read (`guided_seen_v1`).
  final _learned = <String>{};

  bool _disposed = false;

  GuideHint? _hint;
  GuideHint? get currentHint => _hint;

  GuidePhase _phase = GuidePhase.dealing;
  GuidePhase get phase => _phase;

  ReadingRelationship? _relationship;
  ReadingRelationship? get explainedRelationship => _relationship;

  int _lastRevision = -1;

  /// True when two face-up cards pull against each other (opposing elemental
  /// dignities) — the companion's empathetic moment (G2.2). Read-only: it
  /// never changes the table.
  bool get hasTension => spread.relationships.any((r) => r.isContradictory);

  bool get _enabled =>
      spread.isSpreadActive && settings.enabled(ReadingAid.guide);

  Future<void> _restoreLearned() async {
    try {
      _learned.addAll(await _storage.loadGuidedSeen());
    } catch (_) {
      // Storage unavailable — the session simply starts with no memory.
    }
    _recompute();
  }

  void _recompute() {
    if (_disposed) return;
    final revision = spread.readingRevision;
    if (revision != _lastRevision) {
      _lastRevision = revision;
      _relationship = null;
    }
    _phase = _derivePhase();
    _hint = _enabled ? _deriveHint() : null;
    notifyListeners();
  }

  GuidePhase _derivePhase() {
    if (!spread.isSpreadActive || spread.spreadCardCount == 0) {
      return GuidePhase.dealing;
    }
    if (spread.nextEmptySlotIndex != null) return GuidePhase.dealing;
    if (spread.initialSpreadAllFaceUp) return GuidePhase.complete;
    return GuidePhase.revealing;
  }

  GuideHint? _deriveHint() {
    if (_relationship != null) return _relationshipHint(_relationship!);

    final total = spread.spreadCardCount;
    if (total == 0) return null;

    if (spread.initialSpreadAllFaceUp) {
      final lesson = _freshLinkLesson(null);
      return _buildHint(
        id: 'completed',
        type: GuideEventType.spreadCompleted,
        title: GuideCopy.completeTitle(settings.language),
        body: GuideCopy.completeBody(settings.language),
        lesson: lesson?.text,
        lessonId: lesson?.id,
      );
    }

    final recommended = spread.recommendedSlot;
    final dealing = spread.nextEmptySlotIndex != null;

    if (dealing) {
      final slot = recommended ?? spread.nextEmptySlotIndex!;
      final role = slot < spread.slots.length ? spread.slots[slot].role : '';
      final lesson = _freshLesson(slot);
      return _buildHint(
        id: 'dealing:$slot',
        type: GuideEventType.dealingStarted,
        anchor: GuideHintAnchorKind.slot,
        slotIndex: slot,
        title: GuideCopy.dealTitle(
          settings.language,
          slot: slot + 1,
          total: total,
          role: role,
        ),
        body: GuideCopy.dealTip(
          settings.language,
          overview: spread.isSpreadOverview,
          runes: spread.system == DivinationSystem.runes,
        ),
        lesson: lesson?.text,
        lessonId: lesson?.id,
      );
    }

    if (recommended != null) {
      final role = spread.slots[recommended].role;
      final lesson = _freshLesson(recommended);
      return _buildHint(
        id: 'revealing:$recommended',
        type: GuideEventType.revealingStarted,
        anchor: GuideHintAnchorKind.slot,
        slotIndex: recommended,
        title: GuideCopy.revealTitle(
          settings.language,
          slot: recommended + 1,
          role: role,
        ),
        body: GuideCopy.revealBody(settings.language),
        lesson: lesson?.text,
        lessonId: lesson?.id,
      );
    }

    return null;
  }

  /// Wraps authored copy as a once-only lesson: null in concise mode, null when
  /// the reader already learned [id], null when nothing is authored.
  ({String id, String text})? _freshLessonLine(
    String id,
    String? Function(AppLanguage lang) resolve,
  ) {
    if (settings.guideDetail != GuideDetail.thorough) return null;
    if (_learned.contains(id)) return null;
    final text = resolve(settings.language);
    if (text == null || text.isEmpty) return null;
    return (id: id, text: text);
  }

  /// The conceptual lesson for [slot] — only while the reader asked for
  /// thorough guidance and has not read this lesson yet. Every preset spread of
  /// every system carries authored lessons (G4); custom spreads do not.
  ({String id, String text})? _freshLesson(int slot) => _freshLessonLine(
    'slot:${spread.system.name}:${spread.spreadLabel}:${slot + 1}',
    (lang) => spread.slotLesson(slot, lang),
  );

  /// The one concept this moment can teach about reading cards together:
  /// a contradictory pair (opposing elements) outranks the general
  /// "tradition vs modern school" note, and each is taught once per system.
  /// Nothing is taught when the spread has no elemental link to read.
  ({String id, String text})? _freshLinkLesson(ReadingRelationship? link) {
    final links = link != null ? [link] : spread.relationships;
    if (!links.any((r) => r.influence != null)) return null;
    final system = spread.system;
    if (links.any((r) => r.isContradictory)) {
      final tension = _freshLessonLine(
        'conflict:${system.name}',
        (lang) => guideConflictLesson(system)?.forLanguage(lang),
      );
      if (tension != null) return tension;
    }
    return _freshLessonLine(
      'school:${system.name}',
      (lang) => guideSchoolLesson(system)?.forLanguage(lang),
    );
  }

  GuideHint _relationshipHint(ReadingRelationship relationship) {
    final lesson = _freshLinkLesson(relationship);
    return _buildHint(
      id: 'relationship:${relationship.from}:${relationship.to}',
      type: GuideEventType.relationshipTapped,
      title: GuideCopy.relationshipTitle(
        settings.language,
        elemental: relationship.influence != null,
      ),
      body: relationship.localizedExplanation(settings.language),
      lesson: lesson?.text,
      lessonId: lesson?.id,
    );
  }

  GuideHint _buildHint({
    required String id,
    required GuideEventType type,
    required String title,
    required String body,
    GuideHintAnchorKind anchor = GuideHintAnchorKind.whole,
    int? slotIndex,
    String? lesson,
    String? lessonId,
  }) =>
      GuideHint(
        id: id,
        eventType: type,
        title: title,
        body: body,
        anchor: anchor,
        slotIndex: slotIndex,
        lesson: lesson,
        lessonId: lessonId,
      );

  /// The reader explicitly tapped an elemental/positional branch — surface its
  /// explanation above every other hint until [clearRelationship] is called.
  void explainRelationship(ReadingRelationship relationship) {
    _relationship = relationship;
    _recompute();
  }

  /// Dismisses the explicit branch explanation and falls back to the hint the
  /// current table state calls for.
  void clearRelationship() {
    if (_relationship == null) return;
    _relationship = null;
    _recompute();
  }

  /// Records the conceptual lesson of [currentHint] as read. Called when the
  /// reader opens the detail sheet — a lesson is learned by being read, never
  /// by being displayed. No-op when the moment carries no fresh lesson.
  Future<void> learnCurrentLesson() async {
    final id = _hint?.lessonId;
    if (id == null || !_learned.add(id)) return;
    _recompute();
    try {
      await _storage.saveGuidedSeen(_learned);
    } catch (_) {
      // Learned for this session only on devices without a preference store.
    }
  }

  /// Forgets every learned lesson ("Reset learned hints" in the settings).
  Future<void> resetLearned() async {
    if (_learned.isEmpty) return;
    _learned.clear();
    _recompute();
    try {
      await _storage.saveGuidedSeen(_learned);
    } catch (_) {
      // Nothing was persisted — memory is already clean.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    spread.removeListener(_recompute);
    settings.removeListener(_recompute);
    super.dispose();
  }
}
