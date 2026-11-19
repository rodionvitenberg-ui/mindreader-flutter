import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_session_badge.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/core/models/reading_status.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';

/// PHASE 5.2 — History integration.
///
/// * the combined DIGITAL/PHYSICAL/GUIDED/LIVE badge is one pure function;
/// * the snapshot round-trips the new `customSpread` / `pendingGuidedPosition`
///   metadata without breaking legacy JSON;
/// * a 1-tap restore never re-activates a session (so camera/mic are never
///   auto-started) and preserves the physical provenance.
void main() {
  group('readingSessionBadge', () {
    test('digital is always DIGITAL', () {
      expect(
        readingSessionBadge(source: ReadingSource.digital),
        'DIGITAL',
      );
      // Even a physical-looking mode with a digital source stays DIGITAL.
      expect(
        readingSessionBadge(
          source: ReadingSource.digital,
          mode: ReadingMode.guidedSpread,
        ),
        'DIGITAL',
      );
    });

    test('physical maps to GUIDED / LIVE / PHYSICAL by mode', () {
      expect(
        readingSessionBadge(
          source: ReadingSource.physical,
          mode: ReadingMode.guidedSpread,
        ),
        'GUIDED',
      );
      expect(
        readingSessionBadge(
          source: ReadingSource.physical,
          mode: ReadingMode.liveOracle,
        ),
        'LIVE',
      );
      expect(
        readingSessionBadge(
          source: ReadingSource.physical,
          mode: ReadingMode.quickScan,
        ),
        'PHYSICAL',
      );
      expect(
        readingSessionBadge(
          source: ReadingSource.physical,
          mode: ReadingMode.standard,
        ),
        'PHYSICAL',
      );
    });

    test('null provenance (legacy) defaults to DIGITAL', () {
      expect(readingSessionBadge(), 'DIGITAL');
    });
  });

  group('snapshot metadata round-trip', () {
    test('customSpread and pendingGuidedPosition survive JSON', () {
      final snapshot = SpreadSessionSnapshot(
        timestamp: '2026-11-19T12:00:00.000',
        spreadType: SpreadType.three,
        notebook: 'All Readings',
        cards: const [],
        sessionNotes: const [],
        synthesis: null,
        chapters: const [],
        messages: const [],
        readingSource: ReadingSource.physical,
        readingMode: ReadingMode.guidedSpread,
        readingStatus: ReadingStatus.paused,
        customSpread: 'my-3x3',
        pendingGuidedPosition: 1,
      );
      final restored = SpreadSessionSnapshot.fromJson(snapshot.toJson());

      expect(restored.customSpread, 'my-3x3');
      expect(restored.pendingGuidedPosition, 1);
      expect(restored.readingStatus, ReadingStatus.paused);
    });

    test('legacy JSON without the new keys loads with null defaults', () {
      final legacy = <String, dynamic>{
        'timestamp': '2026-11-17T10:00:00.000',
        'spreadType': 'three',
        'notebook': 'All Readings',
        'cards': <dynamic>[],
        'sessionNotes': <dynamic>[],
        'chapters': <dynamic>[],
        'messages': <dynamic>[],
        'kind': 'divinationSpread',
      };
      final restored = SpreadSessionSnapshot.fromJson(legacy);

      expect(restored.customSpread, isNull);
      expect(restored.pendingGuidedPosition, isNull);
    });
  });

  group('restore never re-activates the session', () {
    test('restoring a physical session lands on completed, not active', () {
      final c = OracleSessionController();
      c.restoreSession(
        initial: null,
        chapters: const [],
        messages: const [],
        sessionId: 'saved-guided',
        readingSource: ReadingSource.physical,
        readingMode: ReadingMode.guidedSpread,
        readingStatus: ReadingStatus.completed,
      );

      // A restored session is a terminal, non-active state — camera/mic are
      // never implicitly re-started; resuming the flow is an explicit action.
      expect(c.readingStatus, ReadingStatus.completed);
      expect(c.readingStatus, isNot(ReadingStatus.active));
      expect(c.readingMode, ReadingMode.guidedSpread);
      expect(c.sessionId, 'saved-guided');
    });
  });
}
