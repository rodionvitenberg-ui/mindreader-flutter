import 'package:flutter/foundation.dart';

import '../core/services/oracle_synthesis_service.dart';

/// One appended "Clarifier Expansion" chapter: the follow-up question, the
/// pulled clarifier card, and the synthesized answer text (empty while the
/// AI/local engine is still generating).
class ClarifierChapter {
  ClarifierChapter({
    required this.slotIndex,
    required this.question,
    required this.cardName,
    required this.isReversed,
  });

  final int slotIndex;
  final String question;
  final String cardName;
  final bool isReversed;

  String text = '';
  bool generating = true;
}

/// The screen-level state of the reading synthesis: the structured initial
/// synthesis + the endless clarifier chapters appended to it.
class SynthesisSession extends ChangeNotifier {
  StructuredSynthesis? initial;
  bool generatingInitial = false;

  final List<ClarifierChapter> chapters = [];

  bool get hasSynthesis => initial != null;

  bool get hasPendingClarifiers => chapters.any((c) => c.generating);

  ClarifierChapter? chapterForSlot(int slotIndex) {
    for (final c in chapters) {
      if (c.slotIndex == slotIndex) return c;
    }
    return null;
  }

  void startGenerating() {
    generatingInitial = true;
    notifyListeners();
  }

  void markInitial(StructuredSynthesis synthesis) {
    initial = synthesis;
    generatingInitial = false;
    notifyListeners();
  }

  void addPendingChapter(ClarifierChapter chapter) {
    chapters.add(chapter);
    notifyListeners();
  }

  void completeChapter(int slotIndex, String text) {
    final chapter = chapterForSlot(slotIndex);
    if (chapter == null) return;
    chapter.text = text;
    chapter.generating = false;
    notifyListeners();
  }

  void reset() {
    initial = null;
    generatingInitial = false;
    chapters.clear();
    notifyListeners();
  }
}
