import 'package:flutter/foundation.dart';

import '../core/models/chat_message.dart';
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

/// The workspace-level state of the reading synthesis: the structured
/// initial synthesis, the endless clarifier chapters appended to it, and
/// the full Oracle AI Chat conversation (Pane 1).
class SynthesisSession extends ChangeNotifier {
  StructuredSynthesis? initial;
  bool generatingInitial = false;
  bool _initialFailed = false;
  bool get initialFailed => _initialFailed;

  final List<ClarifierChapter> chapters = [];

  /// The free-form conversational thread after the synthesis.
  final List<ChatMessage> messages = [];

  /// True while the oracle is composing the answer to the last question.
  bool generatingAnswer = false;

  bool get hasSynthesis => initial != null;

  bool get hasPendingClarifiers => chapters.any((c) => c.generating);

  ClarifierChapter? chapterForSlot(int slotIndex) {
    for (final c in chapters) {
      if (c.slotIndex == slotIndex) return c;
    }
    return null;
  }

  void startGenerating() {
    _initialFailed = false;
    generatingInitial = true;
    notifyListeners();
  }

  void failInitial() {
    generatingInitial = false;
    _initialFailed = true;
    notifyListeners();
  }

  void markInitial(StructuredSynthesis synthesis) {
    _initialFailed = false;
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

  // ---- Oracle AI Chat conversation ----

  void addUserMessage(String text) {
    messages.add(ChatMessage(role: 'user', text: text));
    notifyListeners();
  }

  void addOracleMessage(String text) {
    messages.add(ChatMessage(role: 'oracle', text: text));
    notifyListeners();
  }

  void addSystemMessage(String text) {
    messages.add(ChatMessage(role: 'system', text: text));
    notifyListeners();
  }

  void beginAnswer() {
    generatingAnswer = true;
    notifyListeners();
  }

  void finishAnswer() {
    generatingAnswer = false;
    notifyListeners();
  }

  /// 1-tap session restore: rebuilds the exact reading state from the
  /// local archive (synthesis + clarifiers + the whole conversation).
  void restore({
    required StructuredSynthesis? initial,
    required List<ClarifierChapter> chapters,
    required List<ChatMessage> messages,
  }) {
    _initialFailed = false;
    this.initial = initial;
    generatingInitial = false;
    generatingAnswer = false;
    this.chapters
      ..clear()
      ..addAll(chapters);
    this.messages
      ..clear()
      ..addAll(messages);
    notifyListeners();
  }

  void reset() {
    _initialFailed = false;
    initial = null;
    generatingInitial = false;
    generatingAnswer = false;
    chapters.clear();
    messages.clear();
    notifyListeners();
  }
}
