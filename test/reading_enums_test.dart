import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/core/models/reading_status.dart';

void main() {
  group('ReadingStatus transitions', () {
    test('happy path idle -> preparing -> active -> completed', () {
      expect(ReadingStatus.idle.canTransitionTo(ReadingStatus.preparing), isTrue);
      expect(ReadingStatus.preparing.canTransitionTo(ReadingStatus.active), isTrue);
      expect(ReadingStatus.active.canTransitionTo(ReadingStatus.completed), isTrue);
      expect(ReadingStatus.completed.isTerminal, isTrue);
    });

    test('pause/resume and cancellations are legal', () {
      expect(ReadingStatus.active.canTransitionTo(ReadingStatus.paused), isTrue);
      expect(ReadingStatus.paused.canTransitionTo(ReadingStatus.active), isTrue);
      expect(ReadingStatus.paused.canTransitionTo(ReadingStatus.cancelled), isTrue);
      expect(ReadingStatus.preparing.canTransitionTo(ReadingStatus.cancelled),
          isTrue);
      expect(ReadingStatus.preparing.canTransitionTo(ReadingStatus.failed), isTrue);
      expect(ReadingStatus.active.canTransitionTo(ReadingStatus.failed), isTrue);
    });

    test('illegal transitions are rejected', () {
      expect(ReadingStatus.idle.canTransitionTo(ReadingStatus.active), isFalse);
      expect(ReadingStatus.idle.canTransitionTo(ReadingStatus.completed), isFalse);
      expect(ReadingStatus.preparing.canTransitionTo(ReadingStatus.paused), isFalse);
      expect(ReadingStatus.preparing.canTransitionTo(ReadingStatus.completed),
          isFalse);
      expect(ReadingStatus.completed.canTransitionTo(ReadingStatus.active), isFalse);
      expect(ReadingStatus.cancelled.canTransitionTo(ReadingStatus.active), isFalse);
      expect(ReadingStatus.failed.canTransitionTo(ReadingStatus.active), isFalse);
    });
  });

  test('ReadingSource/ReadingMode/ReadingStatus serialize by name', () {
    // source/mode preservation: `.name` round-trips through `values.byName`.
    for (final source in ReadingSource.values) {
      expect(ReadingSource.values.byName(source.name), source);
    }
    for (final mode in ReadingMode.values) {
      expect(ReadingMode.values.byName(mode.name), mode);
    }
    for (final status in ReadingStatus.values) {
      expect(ReadingStatus.values.byName(status.name), status);
    }
  });

  test('ReadingSource <-> TableSourceMode maps in one place', () {
    expect(ReadingSource.digital.tableSourceMode, TableSourceMode.digitalDeck);
    expect(ReadingSource.physical.tableSourceMode, TableSourceMode.physicalCameraSync);
    expect(ReadingSourceX.fromTableSourceMode(TableSourceMode.digitalDeck),
        ReadingSource.digital);
    expect(ReadingSourceX.fromTableSourceMode(TableSourceMode.physicalCameraSync),
        ReadingSource.physical);
  });

  test('labels are stable uppercase badges', () {
    expect(ReadingSource.digital.label, 'DIGITAL');
    expect(ReadingSource.physical.label, 'PHYSICAL');
    expect(ReadingMode.standard.label, 'STANDARD');
    expect(ReadingMode.quickScan.label, 'QUICK SCAN');
    expect(ReadingMode.guidedSpread.label, 'GUIDED SPREAD');
    expect(ReadingMode.liveOracle.label, 'LIVE ORACLE');
  });
}

