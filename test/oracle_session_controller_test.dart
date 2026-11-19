import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/chat_message.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/core/models/reading_status.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/synthesis_session.dart';

void main() {
  const synthesis = StructuredSynthesis(
    narrative: 'n',
    elementalAlchemy: 'e',
    verdict: 'v',
    followUp: 'f',
  );

  test('absorbs SynthesisSession: message + synthesis flow stays intact', () {
    final c = OracleSessionController();
    c.addUserMessage('hello');
    c.addOracleMessage('hi');
    c.beginAnswer();
    expect(c.messages.length, 2);
    expect(c.generatingAnswer, isTrue);
    c.finishAnswer();
    expect(c.generatingAnswer, isFalse);

    c.startGenerating();
    expect(c.generatingInitial, isTrue);
    c.markInitial(synthesis);
    expect(c.hasSynthesis, isTrue);
    expect(c.initial, same(synthesis));
    expect(c.generatingInitial, isFalse);
  });

  test(
    'sessionId is stable: first writer wins, tab switches never change it',
    () {
      final c = OracleSessionController();
      expect(c.sessionId, isNull);
      c.ensureSessionId('2026-11-18T10:00:00.000');
      expect(c.sessionId, '2026-11-18T10:00:00.000');
      expect(c.effectiveSessionId('later'), '2026-11-18T10:00:00.000');
      // A later id must NOT overwrite the stable one.
      c.ensureSessionId('2026-11-18T11:00:00.000');
      expect(c.sessionId, '2026-11-18T10:00:00.000');
    },
  );

  test('beginSession sets provenance + active lifecycle', () {
    final c = OracleSessionController();
    c.beginSession(
      sessionId: 'session-1',
      source: ReadingSource.physical,
      mode: ReadingMode.quickScan,
    );
    expect(c.sessionId, 'session-1');
    expect(c.readingSource, ReadingSource.physical);
    expect(c.readingMode, ReadingMode.quickScan);
    expect(c.readingStatus, ReadingStatus.active);
  });

  test('transitionTo validates the ReadingStatus FSM', () {
    final c = OracleSessionController();
    // idle -> active is illegal (must go through preparing).
    expect(c.transitionTo(ReadingStatus.active), isFalse);
    expect(c.readingStatus, ReadingStatus.idle);

    expect(c.transitionTo(ReadingStatus.preparing), isTrue);
    expect(c.transitionTo(ReadingStatus.active), isTrue);
    expect(c.transitionTo(ReadingStatus.paused), isTrue);
    expect(c.transitionTo(ReadingStatus.active), isTrue);
    expect(c.transitionTo(ReadingStatus.completed), isTrue);
    // Terminal state rejects everything.
    expect(c.transitionTo(ReadingStatus.active), isFalse);
  });

  test('restoreSession rebuilds dialogue + metadata atomically', () {
    final c = OracleSessionController();
    final chapter = ClarifierChapter(
      slotIndex: 3,
      question: 'Why?',
      cardName: 'The Fool',
      isReversed: false,
    )..text = 'answered';
    c.restoreSession(
      initial: synthesis,
      chapters: [chapter],
      messages: const [
        ChatMessage(role: 'user', text: 'q'),
        ChatMessage(role: 'oracle', text: 'a'),
      ],
      sessionId: 'restored-1',
      readingSource: ReadingSource.physical,
      readingMode: ReadingMode.guidedSpread,
      readingStatus: ReadingStatus.completed,
    );
    expect(c.hasSynthesis, isTrue);
    expect(c.chapters.length, 1);
    expect(c.chapters.first.text, 'answered');
    expect(c.messages.length, 2);
    expect(c.sessionId, 'restored-1');
    expect(c.readingSource, ReadingSource.physical);
    expect(c.readingMode, ReadingMode.guidedSpread);
    expect(c.readingStatus, ReadingStatus.completed);
  });

  test('restoreSession with null metadata falls back to defaults', () {
    final c = OracleSessionController();
    c.restoreSession(initial: null, chapters: const [], messages: const []);
    expect(c.hasSynthesis, isFalse);
    expect(c.sessionId, isNull);
    expect(c.readingSource, ReadingSource.digital);
    expect(c.readingMode, ReadingMode.standard);
    expect(c.readingStatus, ReadingStatus.completed);
  });

  test('reset clears dialogue AND session metadata', () {
    final c = OracleSessionController();
    c.beginSession(sessionId: 'x', source: ReadingSource.physical);
    c.markInitial(synthesis);
    c.addUserMessage('q');
    c.reset();
    expect(c.sessionId, isNull);
    expect(c.hasSynthesis, isFalse);
    expect(c.messages, isEmpty);
    expect(c.readingSource, ReadingSource.digital);
    expect(c.readingMode, ReadingMode.standard);
    expect(c.readingStatus, ReadingStatus.idle);
  });

  test('epoch guard rejects a stale async response after reset/restart', () {
    final c = OracleSessionController();
    // A fresh controller accepts its own epoch.
    expect(c.isCurrentSession(c.epoch), isTrue);

    c.beginSession(sessionId: 's1');
    final epochDuringS1 = c.epoch;
    expect(c.isCurrentSession(epochDuringS1), isTrue);

    // reset() (new spread / restart) invalidates the captured epoch — a late
    // async answer started under s1 must not write into the new session.
    c.reset();
    expect(c.isCurrentSession(epochDuringS1), isFalse);
    expect(c.isCurrentSession(c.epoch), isTrue);

    // beginSession() also invalidates an older epoch.
    c.beginSession(sessionId: 's2');
    final epochDuringS2 = c.epoch;
    expect(c.isCurrentSession(epochDuringS2), isTrue);
    c.reset();
    expect(c.isCurrentSession(epochDuringS2), isFalse);
  });
}
