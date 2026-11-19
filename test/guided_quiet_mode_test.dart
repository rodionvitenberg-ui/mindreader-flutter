import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/state/live_reading_controller.dart';

void main() {
  group('guidanceShouldSpeak', () {
    test('both modes speak at the meaningful beats', () {
      for (final mode in GuidanceMode.values) {
        expect(guidanceShouldSpeak(mode, GuidePhase.interpretingCard), isTrue);
        expect(guidanceShouldSpeak(mode, GuidePhase.spreadCompleted), isTrue);
        expect(guidanceShouldSpeak(mode, GuidePhase.awaitingUser), isTrue);
      }
    });

    test('quiet mode stays silent on movement beats', () {
      expect(
        guidanceShouldSpeak(GuidanceMode.quiet, GuidePhase.cardDetected),
        isFalse,
      );
      expect(
        guidanceShouldSpeak(GuidanceMode.quiet, GuidePhase.awaitingReveal),
        isFalse,
      );
      expect(
        guidanceShouldSpeak(GuidanceMode.quiet, GuidePhase.recognizingCard),
        isFalse,
      );
      expect(
        guidanceShouldSpeak(GuidanceMode.quiet, GuidePhase.awaitingConfirmation),
        isFalse,
      );
    });

    test('active mode voices the transitional beats', () {
      expect(
        guidanceShouldSpeak(GuidanceMode.active, GuidePhase.cardDetected),
        isTrue,
      );
      expect(
        guidanceShouldSpeak(GuidanceMode.active, GuidePhase.awaitingReveal),
        isTrue,
      );
      expect(
        guidanceShouldSpeak(GuidanceMode.active, GuidePhase.recognizingCard),
        isTrue,
      );
    });

    test('neither mode speaks for pure bookkeeping states', () {
      for (final mode in GuidanceMode.values) {
        expect(guidanceShouldSpeak(mode, GuidePhase.preparing), isFalse);
        expect(guidanceShouldSpeak(mode, GuidePhase.awaitingCard), isFalse);
        expect(guidanceShouldSpeak(mode, GuidePhase.awaitingNextCard), isFalse);
        expect(guidanceShouldSpeak(mode, GuidePhase.completed), isFalse);
      }
    });
  });

  group('LiveReadingController.oracleShouldSpeak', () {
    test('follows the guidance mode and the current phase', () {
      final c = LiveReadingController();
      c.begin(slotCount: 3);
      c.transitionTo(GuidePhase.awaitingIntention);
      c.transitionTo(GuidePhase.awaitingCard);
      c.transitionTo(GuidePhase.cardDetected);

      // Active (default) voices the detection.
      expect(c.oracleShouldSpeak, isTrue);

      // Quiet stays silent on the same movement.
      c.setGuidanceMode(GuidanceMode.quiet);
      expect(c.oracleShouldSpeak, isFalse);

      // But quiet still speaks when interpreting.
      c.transitionTo(GuidePhase.recognizingCard);
      c.transitionTo(GuidePhase.awaitingConfirmation);
      c.transitionTo(GuidePhase.interpretingCard);
      expect(c.oracleShouldSpeak, isTrue);
    });

    test('setGuidanceMode is idempotent and observable', () {
      final c = LiveReadingController();
      expect(c.guidanceMode, GuidanceMode.active);
      c.setGuidanceMode(GuidanceMode.quiet);
      expect(c.guidanceMode, GuidanceMode.quiet);
      c.setGuidanceMode(GuidanceMode.quiet); // no-op, no listener storm
      expect(c.guidanceMode, GuidanceMode.quiet);
    });
  });
}
