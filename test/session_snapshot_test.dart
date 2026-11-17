import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/chat_message.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/synthesis_session.dart';

/// Sprint 2/3: the full-session snapshot round-trip — capture, JSON,
/// restore — and the thematic notebook derivation.
void main() {
  test('snapshot round-trip preserves cards, notes, synthesis and dialog',
      () {
    final ctrl = SpreadController(random: Random(1));
    for (var i = 0; i < 3; i++) {
      ctrl.dealNextCard();
    }
    ctrl.consumePendingContext(0);
    ctrl.queueContext(chip: '✨ Relationships');
    ctrl.consumePendingContext(1);
    ctrl.addSessionContextNote('why these cards');

    final session = SynthesisSession();
    session.addUserMessage('hello oracle');
    session.addOracleMessage('the table speaks through fire');

    final snapshot = SpreadSessionSnapshot.capture(
      ctrl: ctrl,
      session: session,
      timestamp: '2026-11-17T10:00:00.000',
      notebook: SessionHistoryController.notebookFor(ctrl),
    );
    final restored = SpreadSessionSnapshot.fromJson(snapshot.toJson());

    expect(restored.timestamp, snapshot.timestamp);
    expect(restored.spreadType, SpreadType.three);
    expect(restored.notebook, 'Relationships');
    expect(restored.cards.length, 3);
    expect(restored.cards[0].cardId, ctrl.slots[0].card!.id);
    expect(restored.cards[0].reversed, ctrl.slots[0].isReversed);
    expect(restored.sessionNotes, ['why these cards']);
    expect(restored.synthesis, isNull);
    expect(restored.messages.length, 2);
    expect(restored.messages[0].role, 'user');
    expect(restored.messages[0].text, 'hello oracle');
    expect(restored.messages[1].text, 'the table speaks through fire');

    // And the captured cards rebuild the exact table.
    final ctrl2 = SpreadController(random: Random(2));
    ctrl2.restoreSpread(
      type: restored.spreadType,
      cards: restored.toRestoreCards(),
      sessionNotes: restored.sessionNotes,
    );
    expect(ctrl2.slots[0].card!.id, ctrl.slots[0].card!.id);
    expect(ctrl2.slots[2].isReversed, ctrl.slots[2].isReversed);
    expect(ctrl2.slots.every((s) => s.state.name == 'faceUp'), isTrue);
  });

  test('chapters with empty text are skipped, completed ones survive', () {
    final session = SynthesisSession();
    session.addPendingChapter(
      ClarifierChapter(
        slotIndex: 3,
        question: 'Why?',
        cardName: 'The Fool',
        isReversed: false,
      ),
    );
    session.completeChapter(3, 'The answer text.');
    final ctrl = SpreadController(random: Random(3));
    final snapshot = SpreadSessionSnapshot.capture(
      ctrl: ctrl,
      session: session,
      timestamp: '2026-11-17T11:00:00.000',
      notebook: 'All Readings',
    );
    final restored = SpreadSessionSnapshot.fromJson(snapshot.toJson());
    expect(restored.chapters.length, 1);
    expect(restored.chapters.first.text, 'The answer text.');
    expect(restored.chapters.first.generating, isFalse);
  });

  test('chat messages serialize round-trip', () {
    final message = const ChatMessage(role: 'oracle', text: 'hi', slotIndex: 3);
    final copy = ChatMessage.fromJson(message.toJson());
    expect(copy.role, 'oracle');
    expect(copy.text, 'hi');
    expect(copy.slotIndex, 3);
  });
}
