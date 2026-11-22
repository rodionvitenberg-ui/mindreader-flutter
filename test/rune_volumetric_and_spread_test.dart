import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/rune_packs_registry.dart';
import 'package:mindreader/core/data/runes_data.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/widgets/rune_stone_3d_widget.dart';
import 'package:mindreader/features/digital_table/widgets/spread_deck_dock.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Volumetric RuneStonePainter smoke tests', () {
    test('paints procedural smooth 3D fallback across all 5 packs & states', () {
      for (final pack in runePacksRegistry) {
        for (final faceUp in [false, true]) {
          for (final merkstave in [false, true]) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            final painter = RuneStonePainter(
              stone: elderFuthark[0],
              pack: pack,
              faceUp: faceUp,
              ignite: faceUp ? 1.0 : 0.0,
              merkstave: merkstave,
              stoneTilt: 0.12,
              depthShade: faceUp ? 0.0 : 0.45,
              lift: faceUp ? 0.5 : 0.0,
            );
            painter.paint(canvas, const Size(140, 165));
            final picture = recorder.endRecording();
            picture.dispose();
          }
        }
      }
    });

    test('paints sprite-backed volumetric path with depthShade and lift', () async {
      final recorder = ui.PictureRecorder();
      final srcCanvas = Canvas(recorder);
      srcCanvas.drawOval(
        const Rect.fromLTWH(4, 4, 56, 72),
        Paint()..color = const Color(0xFF2A2638),
      );
      final srcPic = recorder.endRecording();
      final sprite = await srcPic.toImage(64, 80);
      srcPic.dispose();

      final outRec = ui.PictureRecorder();
      final outCanvas = Canvas(outRec);
      RuneStonePainter(
        stone: elderFuthark[5],
        pack: runePacksRegistry.last,
        stoneImage: sprite,
        faceUp: true,
        ignite: 0.85,
        merkstave: true,
        depthShade: 0.35,
        lift: 0.8,
      ).paint(outCanvas, const Size(120, 142));
      outRec.endRecording().dispose();
      sprite.dispose();
    });
  });

  group('SPREAD VIEW horizontal stone heap, flight & 5 rune packs', () {
    final deck = find.byKey(const ValueKey('overview-deck'));
    final moving = find.byKey(const ValueKey('spread-moving-card'));
    Finder slot(int index) => find.byKey(ValueKey('spread-slot-$index'));

    Future<SpreadController> openRunesSpread(
      WidgetTester tester, {
      String spread = 'The Three Norns',
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await activateSystem(tester, 'RUNES', spread);
      return tester
          .element(find.byType(DigitalTableScreen))
          .read<SpreadController>();
    }

    testWidgets(
      'tap on horizontal stone heap flies a volumetric rune stone into slot 0 and depletes',
      (tester) async {
        final ctrl = await openRunesSpread(tester);
        expect(ctrl.system, DivinationSystem.runes);
        expect(ctrl.remaining, 24);

        final underlyingStones = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'overview-rune-stone-',
              ),
        );
        // 12 visible stones = 11 underlying + 1 top stone.
        expect(underlyingStones, findsNWidgets(overviewRuneHeapCap - 1));
        expect(find.byKey(const ValueKey('overview-rune-top')), findsOneWidget);

        // Tap the heap to launch a real flying rune stone (NOT a card back).
        await tester.tap(deck);
        await tester.pump();
        expect(ctrl.dealtCount, 1);
        expect(ctrl.remaining, 23);
        expect(moving, findsOneWidget);
        expect(
          find.descendant(of: moving, matching: find.byType(SpreadCardBack)),
          findsNothing,
        );
        expect(
          find.descendant(of: moving, matching: find.byType(RuneStoneView)),
          findsOneWidget,
        );

        // Complete flight and verify face-down rune landed in slot 0.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(moving, findsNothing);
        expect(ctrl.slots.first.state, SlotState.faceDown);
        expect(
          find.descendant(of: slot(0), matching: find.byType(RuneStone3DWidget)),
          findsOneWidget,
        );

        // Tap the face-down rune stone to perform 3D turn-over flip.
        await tester.tap(slot(0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        expect(ctrl.slots.first.state, SlotState.faceUp);
      },
    );

    testWidgets(
      'long-press drag casts a rune stone from the heap onto slot 0',
      (tester) async {
        final ctrl = await openRunesSpread(tester);
        final gesture = await tester.startGesture(tester.getCenter(deck));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 24));
        expect(moving, findsOneWidget);

        await gesture.moveTo(tester.getCenter(slot(0)));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(moving, findsNothing);
        expect(ctrl.dealtCount, 1);
        expect(ctrl.remaining, 23);
      },
    );

    testWidgets(
      'horizontal swipe on SPREAD VIEW rune heap shuffles without dealing',
      (tester) async {
        final ctrl = await openRunesSpread(tester);
        final before = ctrl.remainingDeck.map((c) => c.id).toList();

        await tester.drag(deck, const Offset(96, 0));
        await tester.pump();

        expect(ctrl.dealtCount, 0);
        expect(ctrl.remaining, 24);
        expect(ctrl.remainingDeck.map((c) => c.id).toList(), isNot(before));
      },
    );

    testWidgets(
      'heap visibly shrinks once remaining drops below overviewRuneHeapCap',
      (tester) async {
        final ctrl = await openRunesSpread(tester);
        ctrl.setCustomSpread(
          CustomSpreadConfig.fromQuestions(
            questions: List.generate(12, (i) => 'Rune $i'),
          ),
        );
        // Deal 12 base runes, flip them, then deal 2 clarifiers -> 10 left (< 12).
        for (var i = 0; i < 12; i++) {
          ctrl.dealNextCard();
          ctrl.flipSlot(i);
        }
        ctrl.dealNextCardOrClarifier();
        ctrl.flipSlot(12);
        ctrl.dealNextCardOrClarifier();
        await tester.pump();

        expect(ctrl.remaining, 10);
        final underlyingStones = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'overview-rune-stone-',
              ),
        );
        // 10 remaining -> 9 underlying + 1 top.
        expect(underlyingStones, findsNWidgets(ctrl.remaining - 1));
      },
    );

    testWidgets(
      'switching between built-in stone packs (blood_jasper & moss_agate) updates painted stones',
      (tester) async {
        await openRunesSpread(tester);
        final packs = tester
            .element(find.byType(DigitalTableScreen))
            .read<DeckPackController>();

        for (final packId in ['blood_jasper', 'moss_agate']) {
          await packs.setActiveRunePack(packId);
          await tester.pump();

          final painters = tester
              .widgetList<CustomPaint>(
                find.descendant(of: deck, matching: find.byType(CustomPaint)),
              )
              .map((cp) => cp.painter)
              .whereType<RuneStonePainter>()
              .toList();
          expect(painters, isNotEmpty);
          expect(painters.map((p) => p.pack.id).toSet(), {packId});
        }
      },
    );
  });
}
