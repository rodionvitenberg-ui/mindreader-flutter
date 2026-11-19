import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/camera_scan/widgets/guided_spread_hud.dart';
import 'package:mindreader/state/live_reading_controller.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

GuidedSpreadHud _hud({
  required GuidePhase phase,
  required VoidCallback onPause,
  required VoidCallback onExit,
  required VoidCallback onConfirm,
  required VoidCallback onResume,
  required VoidCallback onOpenChat,
  required VoidCallback onToggleFlash,
}) {
  return GuidedSpreadHud(
    spreadName: 'Triad Flow',
    filledCount: 2,
    totalSlots: 3,
    currentSlotRole: 'HIDDEN SHADOW',
    phase: phase,
    flashOn: false,
    onPause: onPause,
    onExit: onExit,
    onConfirm: onConfirm,
    onResume: onResume,
    onOpenChat: onOpenChat,
    onToggleFlash: onToggleFlash,
  );
}

void main() {
  group('guidedInstruction', () {
    test('maps each phase to its instruction', () {
      expect(guidedInstruction(GuidePhase.awaitingCard), 'DRAW A CARD AND PLACE IT');
      expect(guidedInstruction(GuidePhase.awaitingReveal), 'TURN THE CARD FACE-UP');
      expect(guidedInstruction(GuidePhase.awaitingConfirmation), 'CONFIRM THE CARD?');
      expect(guidedInstruction(GuidePhase.spreadCompleted), 'SPREAD COMPLETE');
      expect(guidedInstruction(GuidePhase.paused), 'PAUSED');
    });
  });

  group('guidedPrimaryAction', () {
    test('confirm/next/resume only in their phases', () {
      expect(guidedPrimaryAction(GuidePhase.awaitingConfirmation), 'CONFIRM');
      expect(guidedPrimaryAction(GuidePhase.awaitingNextCard), 'NEXT');
      expect(guidedPrimaryAction(GuidePhase.paused), 'RESUME');
      expect(guidedPrimaryAction(GuidePhase.awaitingCard), isNull);
      expect(guidedPrimaryAction(GuidePhase.interpretingCard), isNull);
    });
  });

  group('GuidedSpreadHud renders', () {
    testWidgets('spread name, progress and slot role', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _hud(
            phase: GuidePhase.awaitingCard,
            onPause: () {},
            onExit: () {},
            onConfirm: () {},
            onResume: () {},
            onOpenChat: () {},
            onToggleFlash: () {},
          ),
        ),
      );

      expect(find.text('Triad Flow'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('HIDDEN SHADOW'), findsOneWidget);
      expect(find.text('DRAW A CARD AND PLACE IT'), findsOneWidget);
    });

    testWidgets('primary button label follows the phase', (tester) async {
      Widget build(GuidePhase phase) => _wrap(
            _hud(
              phase: phase,
              onPause: () {},
              onExit: () {},
              onConfirm: () {},
              onResume: () {},
              onOpenChat: () {},
              onToggleFlash: () {},
            ),
          );

      await tester.pumpWidget(build(GuidePhase.awaitingConfirmation));
      expect(find.byKey(const ValueKey('guided-primary-CONFIRM')), findsOneWidget);

      await tester.pumpWidget(build(GuidePhase.awaitingNextCard));
      await tester.pump();
      expect(find.byKey(const ValueKey('guided-primary-NEXT')), findsOneWidget);

      await tester.pumpWidget(build(GuidePhase.paused));
      await tester.pump();
      expect(find.byKey(const ValueKey('guided-primary-RESUME')), findsOneWidget);

      await tester.pumpWidget(build(GuidePhase.awaitingCard));
      await tester.pump();
      expect(find.byKey(const ValueKey('guided-primary-CONFIRM')), findsNothing);
    });

    testWidgets('actions invoke the right callbacks', (tester) async {
      var paused = 0;
      var exited = 0;
      var confirmed = 0;
      var resumed = 0;
      var openedChat = 0;
      var toggledFlash = 0;

      await tester.pumpWidget(
        _wrap(
          _hud(
            phase: GuidePhase.awaitingConfirmation,
            onPause: () => paused++,
            onExit: () => exited++,
            onConfirm: () => confirmed++,
            onResume: () => resumed++,
            onOpenChat: () => openedChat++,
            onToggleFlash: () => toggledFlash++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.pause));
      await tester.tap(find.byIcon(Icons.close));
      await tester.tap(find.byIcon(Icons.flash_off_outlined));
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.tap(find.byKey(const ValueKey('guided-primary-CONFIRM')));
      await tester.pump();

      expect(paused, 1);
      expect(exited, 1);
      expect(toggledFlash, 1);
      expect(openedChat, 1);
      expect(confirmed, 1);
      expect(resumed, 0);
    });
  });
}
