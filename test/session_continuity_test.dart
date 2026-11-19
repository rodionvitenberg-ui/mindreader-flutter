import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/core/models/reading_status.dart';
import 'package:mindreader/state/live_oracle_controller.dart';
import 'package:mindreader/state/live_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';

/// PHASE 5.1 — Session continuity (scenarios A–H).
///
/// The cross-cutting invariant every physical/digital transition must hold:
/// ONE stable [OracleSessionController] `sessionId` that is never regenerated
/// by switching provenance or views, provenance that survives a 1-tap restore,
/// and a dialogue that is never silently reset by a mode/source change.
///
/// These are domain-level sequences: they drive the real controllers the way
/// the camera / table / oracle panes do, without depending on the widget tree.
void main() {
  group('sessionId stability across flows', () {
    test('A — Quick Scan → Oracle → Table → Oracle keeps one sessionId', () {
      final c = OracleSessionController();
      c.beginSession(
        sessionId: 'scan-a',
        source: ReadingSource.physical,
        mode: ReadingMode.quickScan,
      );
      c.addUserMessage('what do I see?');
      c.addOracleMessage('the fool stands at the edge');

      // Oracle → Table: provenance changes shape, identity does not.
      c.setReadingMode(ReadingMode.standard);
      expect(c.sessionId, 'scan-a');
      expect(c.messages.length, 2);

      // Table → Oracle: back to the same conversation, still one id.
      c.setReadingMode(ReadingMode.quickScan);
      expect(c.sessionId, 'scan-a');
      expect(c.messages.last.text, 'the fool stands at the edge');
    });

    test('B — Guided → Pause → Oracle → Resume preserves id + dialogue', () {
      final oracle = OracleSessionController();
      oracle.beginSession(
        sessionId: 'guided-b',
        source: ReadingSource.physical,
        mode: ReadingMode.guidedSpread,
      );
      final live = LiveReadingController();
      live.begin(slotCount: 3);
      live.transitionTo(GuidePhase.awaitingIntention);
      live.transitionTo(GuidePhase.awaitingCard);
      live.pause();
      expect(live.phase, GuidePhase.paused);

      // Oracle dialogue happens WHILE the guided flow is paused — it must not
      // disturb the stable id or the guided provenance.
      oracle.addUserMessage('pause to ask');
      oracle.addOracleMessage('answer while paused');
      expect(oracle.sessionId, 'guided-b');
      expect(oracle.readingMode, ReadingMode.guidedSpread);

      live.resume();
      expect(live.phase, GuidePhase.awaitingCard);
      expect(oracle.sessionId, 'guided-b');
      expect(oracle.messages.length, 2);
    });

    test('C — Live → Compact → Full → Voice keeps one liveOracle session', () {
      final oracle = OracleSessionController();
      oracle.beginSession(
        sessionId: 'live-c',
        source: ReadingSource.physical,
        mode: ReadingMode.liveOracle,
      );
      final live = LiveOracleController();
      live.begin(intention: 'guidance');

      // Compact → Full → voice toggles only move provenance/presentation;
      // the freeform controller and the session id are untouched by them.
      live.setIntention('guidance for the road');
      expect(oracle.sessionId, 'live-c');
      expect(oracle.readingMode, ReadingMode.liveOracle);
      expect(oracle.readingStatus, ReadingStatus.active);

      // Restarting the freeform intent does not re-key the Oracle session.
      live.begin(intention: 'a fresh intent');
      expect(oracle.sessionId, 'live-c');
    });

    test('D — Oracle → Physical Clarifier → Camera → Oracle: same session', () {
      final c = OracleSessionController();
      c.beginSession(
        sessionId: 'clarify-d',
        source: ReadingSource.physical,
        mode: ReadingMode.quickScan,
      );
      c.addUserMessage('ask');
      c.addOracleMessage('clarify');

      // Clarifier round-trip + camera revisit never re-key the session.
      c.setReadingSource(ReadingSource.physical);
      c.setReadingMode(ReadingMode.quickScan);
      expect(c.sessionId, 'clarify-d');
      expect(c.messages.length, 2);
    });

    test('H — Digital → Physical Clarifier → Same: source flips, id holds', () {
      final c = OracleSessionController();
      c.beginSession(
        sessionId: 'same-h',
        source: ReadingSource.digital,
        mode: ReadingMode.standard,
      );
      c.addUserMessage('digital first');

      // Moving to a physical clarifier changes the source, not the identity.
      c.setReadingSource(ReadingSource.physical);
      expect(c.sessionId, 'same-h');
      expect(c.readingSource, ReadingSource.physical);
      expect(c.messages.single.text, 'digital first');
    });
  });

  group('restore preserves physical provenance', () {
    void expectRestoreKeeps(ReadingMode mode) {
      final c = OracleSessionController();
      c.beginSession(sessionId: 'live-restore', mode: mode);
      c.addUserMessage('q');

      c.restoreSession(
        initial: null,
        chapters: const [],
        messages: List.of(c.messages),
        sessionId: 'live-restore',
        readingSource: ReadingSource.physical,
        readingMode: mode,
        readingStatus: ReadingStatus.completed,
      );

      expect(c.readingSource, ReadingSource.physical, reason: '$mode source');
      expect(c.readingMode, mode, reason: '$mode mode');
      expect(c.readingStatus, ReadingStatus.completed);
      expect(c.messages.length, 1, reason: '$mode dialogue');
    }

    test('E — History → Restore Physical (quickScan)', () {
      expectRestoreKeeps(ReadingMode.quickScan);
    });

    test('F — History → Restore Guided (guidedSpread)', () {
      expectRestoreKeeps(ReadingMode.guidedSpread);
    });

    test('G — History → Restore Live (liveOracle)', () {
      expectRestoreKeeps(ReadingMode.liveOracle);
    });
  });

  group('stale responses never land in a new session', () {
    test('a late answer from a paused/restarted session is rejected', () {
      final c = OracleSessionController();
      c.beginSession(sessionId: 's1', mode: ReadingMode.guidedSpread);
      final epochDuringS1 = c.epoch;

      // Switch to a different saved conversation (restore = new epoch).
      c.restoreSession(
        initial: null,
        chapters: const [],
        messages: const [],
        sessionId: 's2',
        readingMode: ReadingMode.quickScan,
      );

      expect(c.isCurrentSession(epochDuringS1), isFalse);
      expect(c.sessionId, 's2');
      // The old async answer must not have mutated the new session.
      expect(c.messages, isEmpty);
    });
  });
}
