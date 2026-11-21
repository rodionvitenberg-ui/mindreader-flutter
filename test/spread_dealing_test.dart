import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/widgets/spread_deck_dock.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  final deck = find.byKey(const ValueKey('overview-deck'));
  final moving = find.byKey(const ValueKey('spread-moving-card'));
  final viewport = find.byKey(const ValueKey('spread-viewport'));
  Finder slot(int index) => find.byKey(ValueKey('spread-slot-$index'));

  Future<SpreadController> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    return tester
        .element(find.byType(DigitalTableScreen))
        .read<SpreadController>();
  }

  Future<TestGesture> grab(WidgetTester tester) async {
    final g = await tester.startGesture(tester.getCenter(deck));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 16));
    expect(moving, findsOneWidget);
    return g;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  double angle(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return (box.localToGlobal(const Offset(1, 0)) -
            box.localToGlobal(Offset.zero))
        .direction;
  }

  testWidgets(
    'tap and manual release use the same ordered deck and context; rapid taps cannot double-deal',
    (tester) async {
      final ctrl = await open(tester);
      final order = ctrl.remainingDeck.map((c) => c.id).toList();
      final reversed = ctrl.remainingReversalFlags;
      ctrl.queueContext(note: 'first question');
      await tester.tap(deck);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.tap(deck);
      }
      expect(ctrl.dealtCount, 1);
      final back = find.descendant(
        of: moving,
        matching: find.byType(SpreadCardBack),
      );
      expect(angle(tester, back), closeTo(math.pi / 2, 0.01));
      await tester.pump(const Duration(milliseconds: 180));
      expect(angle(tester, back), inExclusiveRange(0.1, 1.5));
      await tester.pump(const Duration(milliseconds: 179));
      expect(
        (tester.getCenter(back) - tester.getCenter(slot(0))).distance,
        lessThan(1),
      );
      expect(angle(tester, back), closeTo(0, 0.01));
      await settle(tester);
      expect(moving, findsNothing);
      expect(ctrl.slots.first.userContext, contains('first question'));

      ctrl.queueContext(note: 'second question');
      final finger = await grab(tester);
      expect(ctrl.dealtCount, 1);
      await finger.moveTo(tester.getCenter(slot(1)));
      await tester.pump();
      expect(ctrl.dealtCount, 1);
      await finger.up();
      await settle(tester);
      expect(ctrl.slots[1].userContext, contains('second question'));
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        expect(ctrl.slots[i].index, i);
        expect(ctrl.slots[i].card!.id, order[i]);
        expect(ctrl.slots[i].isReversed, reversed[i]);
        expect(ctrl.slots[i].state, SlotState.faceDown);
      }
      expect(ctrl.remainingDeck.map((c) => c.id), orderedEquals(order.skip(2)));
      expect(ctrl.ledgerTotal, ctrl.totalCards);
    },
  );

  testWidgets(
    'wrong slot, held tap, pointer cancellation and interrupted pickup leave the deck intact',
    (tester) async {
      final ctrl = await open(tester);
      final order = ctrl.deckOrder;
      final reversed = ctrl.remainingReversalFlags;
      ctrl.queueContext(note: 'keep for next card');
      for (final location in [
        tester.getCenter(slot(2)),
        tester.getCenter(deck),
      ]) {
        final finger = await grab(tester);
        await finger.moveTo(location);
        await finger.up();
        await settle(tester);
        expect(moving, findsNothing);
        expect(ctrl.dealtCount, 0);
      }
      final cancelled = await grab(tester);
      await cancelled.moveTo(tester.getCenter(slot(0)));
      await cancelled.cancel();
      await settle(tester);
      expect(moving, findsNothing);
      final interrupted = await grab(tester);
      ctrl.setSpreadOverview(false);
      await tester.pump();
      await interrupted.up();
      expect(ctrl.deckOrder, order);
      expect(ctrl.remainingReversalFlags, reversed);
      expect(ctrl.hasPendingContext, isTrue);
      expect(ctrl.dealtCount, 0);
      expect(moving, findsNothing);
    },
  );

  testWidgets('leaving the tab or backgrounding the app cancels a held card', (
    tester,
  ) async {
    final ctrl = await open(tester);
    final first = await grab(tester);
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    await tester.tap(find.text('TABLE'));
    await tester.pump();
    expect(moving, findsNothing);
    await first.moveTo(tester.getCenter(slot(0)));
    await first.up();
    expect(ctrl.dealtCount, 0);

    final held = await grab(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await held.moveTo(tester.getCenter(slot(0)));
    await held.up();
    await settle(tester);
    expect(moving, findsNothing);
    expect(ctrl.dealtCount, 0);
  });

  testWidgets(
    'reset during flight discards the visual and accepts the next reading',
    (tester) async {
      final ctrl = await open(tester);
      await tester.tap(deck);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(moving, findsOneWidget);
      ctrl.resetTable();
      await settle(tester);
      expect(moving, findsNothing);
      expect(ctrl.remaining, ctrl.totalCards);
      await tester.tap(deck);
      await tester.tap(find.text('FOCUS VIEW'));
      await settle(tester);
      expect(ctrl.dealtCount, 1);
      expect(ctrl.isSpreadOverview, isFalse);
    },
  );

  testWidgets(
    'crossing card lands horizontally over the first card even when released inside both',
    (tester) async {
      final ctrl = await open(tester);
      ctrl.setSpreadType(SpreadType.celticCross);
      await tester.pump();
      final order = ctrl.remainingDeck.map((c) => c.id).toList();
      await tester.tap(deck);
      await settle(tester);
      final a = tester.renderObject<RenderBox>(slot(0));
      final b = tester.renderObject<RenderBox>(slot(1));
      final overlap =
          MatrixUtils.transformRect(
            a.getTransformTo(null),
            Offset.zero & a.size,
          ).intersect(
            MatrixUtils.transformRect(
              b.getTransformTo(null),
              Offset.zero & b.size,
            ),
          );
      expect(overlap.isEmpty, isFalse);
      expect(angle(tester, slot(1)), closeTo(math.pi / 2, 0.001));
      final finger = await grab(tester);
      await finger.moveTo(overlap.center);
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 209));
      final back = find.descendant(
        of: moving,
        matching: find.byType(SpreadCardBack),
      );
      expect(angle(tester, back), closeTo(math.pi / 2, 0.01));
      expect(
        (tester.getCenter(back) - tester.getCenter(slot(1))).distance,
        lessThan(1),
      );
      await settle(tester);
      expect(
        ctrl.slots.take(2).map((s) => s.card!.id),
        orderedEquals(order.take(2)),
      );
      expect(ctrl.dealtCount, 2);
    },
  );

  testWidgets(
    'zoomed custom table brings a distant slot within reach without changing zoom',
    (tester) async {
      final ctrl = await open(tester);
      ctrl.setCustomSpread(
        CustomSpreadConfig.fromQuestions(
          questions: List.generate(12, (i) => 'Q$i'),
        ),
      );
      for (var i = 0; i < 11; i++) {
        ctrl.dealNextCard();
      }
      await tester.pump();
      final camera = tester
          .widget<InteractiveViewer>(viewport)
          .transformationController!;
      camera.value = Matrix4.diagonal3Values(1.6, 1.6, 1.6);
      await tester.pump();
      final bounds = tester.getRect(viewport);
      expect(bounds.contains(tester.getCenter(slot(11))), isFalse);
      final finger = await grab(tester);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(camera.value.getMaxScaleOnAxis(), closeTo(1.6, 0.001));
      expect(bounds.contains(tester.getCenter(slot(11))), isTrue);
      await finger.moveTo(tester.getCenter(slot(11)));
      await finger.up();
      await settle(tester);
      expect(ctrl.dealtCount, 12);
      await tester.tap(deck);
      await settle(tester);
      expect(ctrl.dealtCount, 12);
      expect(moving, findsNothing);
      expect(ctrl.armClarifierQuestion('What next?'), isTrue);
      await tester.pump();
      final clarifier = await grab(tester);
      await tester.pump(const Duration(milliseconds: 220));
      await clarifier.moveTo(tester.getCenter(slot(12)));
      await clarifier.up();
      await settle(tester);
      expect(ctrl.clarifierCount, 1);
      expect(ctrl.slots.last.userContext, contains('What next?'));
    },
  );

  testWidgets('every card preset accepts its final drop in landscape', (
    tester,
  ) async {
    final ctrl = await open(tester, size: const Size(900, 500));
    Future<void> placeLast() async {
      final last = ctrl.spreadCardCount - 1;
      for (var i = 0; i < last; i++) {
        ctrl.dealNextCard();
      }
      await tester.pump();
      final expected = ctrl.deckTop.first.id;
      final finger = await grab(tester);
      await finger.moveTo(tester.getCenter(slot(last)));
      await finger.up();
      await settle(tester);
      expect(ctrl.allDealt, isTrue);
      expect(ctrl.slots.last.card!.id, expected);
      if (ctrl.system == DivinationSystem.lenormand) {
        expect(ctrl.slots.last.isReversed, isFalse);
      }
    }

    for (final preset in SpreadType.values) {
      ctrl.setSpreadType(preset);
      await placeLast();
    }
    ctrl.setSystem(DivinationSystem.lenormand);
    for (final preset in LenormandSpread.values) {
      ctrl.setLenormandSpread(preset);
      await placeLast();
    }
  });
}
