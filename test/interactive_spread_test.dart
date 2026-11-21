import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/widgets/reading_bottom_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/slotted_divination_card.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  final viewport = find.byKey(const ValueKey('spread-viewport'));
  final deck = find.byKey(const ValueKey('overview-deck'));
  final inspector = find.byType(ReadingBottomSheet);
  final field = find.byKey(const ValueKey('reading-context')).hitTestable();

  Future<void> openTable(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Daily Anchor');
  }

  BuildContext table(WidgetTester tester) =>
      tester.element(find.byType(DigitalTableScreen));

  testWidgets(
    'Celtic Cross fits initially, pinch and pan move only the table',
    (tester) async {
      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>()
        ..setSpreadType(SpreadType.celticCross);
      await tester.pump();
      final viewer = tester.widget<InteractiveViewer>(viewport);
      final camera = viewer.transformationController!;
      final rect = tester.getRect(viewport);
      final dock = tester.getRect(deck);
      for (var i = 0; i < 10; i++) {
        final role = '${i + 1} · ${ctrl.spreadSlotRoleShorts[i]}';
        expect(
          rect.contains(tester.getCenter(find.text(role))),
          isTrue,
          reason: role,
        );
      }
      final fit = camera.value.getMaxScaleOnAxis();
      final center = rect.center;
      final left = await tester.startGesture(
        center - const Offset(32, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(32, 0),
        pointer: 2,
      );
      for (var i = 1; i <= 5; i++) {
        await left.moveTo(center - Offset(32 + 10.0 * i, 0));
        await right.moveTo(center + Offset(32 + 10.0 * i, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();
      await tester.pump();
      expect(camera.value.getMaxScaleOnAxis(), greaterThan(fit * 1.4));
      final beforePan = camera.toScene(center - rect.topLeft);
      final finger = await tester.startGesture(center);
      for (var i = 1; i <= 12; i++) {
        await finger.moveBy(const Offset(-4, 1));
        await tester.pump(const Duration(milliseconds: 25));
      }
      await finger.up();
      await tester.pump();
      expect(
        camera.toScene(center - rect.topLeft).dx,
        greaterThan(beforePan.dx + 5),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      expect(tester.getRect(deck), dock);
      await tester.tap(find.byTooltip('Fit whole spread'));
      await tester.pump();
      expect(camera.value.getMaxScaleOnAxis(), closeTo(fit, 0.0001));
      await goToPane(tester, 1);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
    },
  );

  testWidgets(
    'taps deal, reveal, inspect and return to the same camera and Focus cards',
    (tester) async {
      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>();
      final camera = tester
          .widget<InteractiveViewer>(viewport)
          .transformationController!;
      final slot = find.descendant(
        of: viewport,
        matching: find.byType(SlottedDivinationCard),
      );
      await tester.tap(deck);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(ctrl.slots.first.state, SlotState.faceDown);
      expect(
        tester
            .widgetList<Opacity>(
              find.ancestor(of: slot, matching: find.byType(Opacity)),
            )
            .every((widget) => widget.opacity > 0.99),
        isTrue,
      );
      await tester.tap(slot);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();
      expect(ctrl.slots.first.state, SlotState.faceUp);
      final id = ctrl.slots.first.card!.id;
      // Zoom around the card before opening it.
      final matrix = camera.value.clone()..scaleByDouble(1.15, 1.15, 1.15, 1);
      camera.value = matrix;
      await tester.pump();
      await tester.tap(slot);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<ReadingBottomSheet>(inspector).cardIndex, 0);
      expect(find.byKey(const ValueKey('card-note-field')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(inspector, findsNothing);
      expect(camera.value, matrix);
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expect(ctrl.slots.first.state, SlotState.faceUp);
      expect(ctrl.slots.first.card!.id, id);
      await tester.tap(find.text('SPREAD VIEW'));
      await tester.pump();
      expect(ctrl.dealtCount, 1);
      expect(ctrl.slots.first.card!.id, id);
    },
  );

  for (final system in [DivinationSystem.lenormand, DivinationSystem.runes]) {
    testWidgets(
      '${system.name} keeps its renderer and dismisses back to the table',
      (tester) async {
        await openTable(tester);
        final ctrl = table(tester).read<SpreadController>()..setSystem(system);
        await tester.pump();
        await tester.tap(deck);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final card = find.descendant(
          of: viewport,
          matching: find.byType(SlottedDivinationCard),
        );
        await tester.tap(card);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 850));
        await tester.pump();
        await tester.tap(card);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.widget<ReadingBottomSheet>(inspector).cardIndex, 0);
        expect(find.byKey(const ValueKey('card-note-field')), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(inspector, findsNothing);
        expect(ctrl.slots.first.state, SlotState.faceUp);
      },
    );
  }

  for (final system in [DivinationSystem.tarot, DivinationSystem.runes]) {
    testWidgets(
      '${system.name}: deal enables reset, reveal enables synthesis',
      (tester) async {
        await openTable(tester);
        final context = table(tester);
        final ctrl = context.read<SpreadController>()..setSystem(system);
        if (system == DivinationSystem.tarot) {
          ctrl.setSpreadType(SpreadType.three);
        }
        await tester.pump();
        final oracle = context.read<OracleSessionController>();
        final reset = find.text('TAP TO RESET');
        final synthesize = find.byKey(const ValueKey('synthesize-cta'));
        final synthesizeLabel = find.descendant(
          of: synthesize,
          matching: find.textContaining('SYNTHESIZE IN CHAT'),
        );
        final effects = find.descendant(
          of: synthesize,
          matching: find.byType(CustomPaint),
        );
        final disabledColor = TaroColors.textDisabled;

        await tester.tap(deck);
        await tester.pump();
        expect(tester.widget<Text>(reset).style!.color, disabledColor);
        await tester.tap(reset);
        await tester.pump();
        expect(ctrl.dealtCount, 1);

        for (var index = 1; index < ctrl.spreadCardCount; index++) {
          await tester.tap(deck);
          await tester.pump();
        }
        expect(ctrl.allDealt, isTrue);
      expect(tester.widget<Text>(reset).style!.color, isNot(disabledColor));
        for (var index = 0; index < ctrl.spreadCardCount - 1; index++) {
          ctrl.flipSlot(index);
        }
        await tester.pump();
        expect(
          tester.widget<Text>(synthesizeLabel).style!.color,
          disabledColor,
        );
        expect(effects, findsNothing);
        await tester.tap(synthesize);
        await tester.pump();
        expect(oracle.generatingInitial, isFalse);
        expect(oracle.hasSynthesis, isFalse);

        ctrl.flipSlot(ctrl.spreadCardCount - 1);
        await tester.pump();
        expect(
          tester.widget<Text>(synthesizeLabel).style!.color,
          isNot(disabledColor),
        );
        expect(effects, findsOneWidget);
        await tester.tap(reset);
        await tester.pump();
        expect(ctrl.dealtCount, 0);
        expect(tester.widget<Text>(reset).style!.color, disabledColor);
        expect(effects, findsNothing);
      },
    );
  }

  testWidgets('typing stays available when microphone permission is denied', (
    tester,
  ) async {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await openTable(tester);
    await tester.tap(find.byTooltip('Dictate question'));
    await tester.pump();
    expect(
      find.text('Voice input is unavailable. You can type your question.'),
      findsOneWidget,
    );
    await tester.enterText(field, 'Written question');
    expect(
      table(tester).read<SpreadController>().readingQuestion,
      'Written question',
    );
  });

  testWidgets(
    'dictation updates the current draft without duplicating partial speech',
    (tester) async {
      const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      Future<void> fromRecognizer(String method, String data) async {
        await messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, data)),
          (_) {},
        );
        await tester.pump();
      }

      Future<void> words(String text, int type) => fromRecognizer(
        'textRecognition',
        '{"alternates":[{"recognizedWords":"$text","confidence":0.9}],"resultType":$type}',
      );

      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>();
      await tester.enterText(field, 'Job change');
      await tester.tap(find.byTooltip('Dictate question'));
      await tester.pump();
      expect(calls, contains('listen'));
      await fromRecognizer('notifyStatus', 'listening');
      await words('next', 0);
      await words('next week', 0);
      await words('next week?', 2);
      expect(ctrl.readingQuestion, 'Job change next week?');
      // Complete the platform session and verify that the text stays editable.
      await fromRecognizer('notifyStatus', 'done');
      expect(find.byTooltip('Dictate question'), findsOneWidget);
      await tester.enterText(field, 'A different question');
      expect(ctrl.readingQuestion, 'A different question');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      ctrl.dealNextCardOrClarifier();
      ctrl.flipSlot(0);
      await tester.pump();
      await tester.tap(find.byTooltip('Dictate question').hitTestable());
      await tester.pump();
      await fromRecognizer('notifyStatus', 'listening');
      await words('about', 0);
      final oracle = table(tester).read<OracleSessionController>();
      await tester.tap(find.byKey(const ValueKey('synthesize-cta')));
      await tester.pump();
      expect(calls, contains('stop'));
      expect(oracle.hasSynthesis, isFalse);
      await words('about changing jobs', 2);
      await tester.pump(const Duration(seconds: 1));
      expect(
        oracle.initial!.narrative,
        contains('A different question about changing jobs'),
      );
    },
  );

  testWidgets(
    'the draft is editable with the keyboard open on a short landscape display',
    (tester) async {
      await openTable(tester, size: const Size(760, 360));
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 205);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(field, findsOneWidget);
      await tester.enterText(field, 'Preparing for tomorrow');
      expect(
        table(tester).read<SpreadController>().readingQuestion,
        'Preparing for tomorrow',
      );
      tester.view.resetViewInsets();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(viewport, findsOneWidget);
    },
  );

  for (final forSelf in [true, false]) {
    testWidgets(
      'first synthesis uses the draft and correct subject (self = $forSelf)',
      (tester) async {
        await openTable(tester);
        final context = table(tester);
        final ctrl = context.read<SpreadController>();
        final history = context.read<SessionHistoryController>();
        final oracle = context.read<OracleSessionController>();
        context.read<UserProfileController>()
          ..setPersonalBioContext('Owner biography')
          ..setTargetPersonNote('Previous recipient');
        const question = 'What should I ask at the interview?';
        await tester.enterText(field, question);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.tap(find.text('FOR SOMEONE ELSE'));
        await tester.pump();
        if (forSelf) await tester.tap(find.text('FOR MYSELF (PROFILE)'));
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, question);
        await tester.tap(find.text('FOCUS VIEW'));
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, question);
        await tester.tap(find.text('SPREAD VIEW'));
        await tester.pump();
        ctrl.dealNextCardOrClarifier();
        ctrl.flipSlot(0);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('synthesize-cta')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(oracle.initial!.narrative, contains(question));
        expect(oracle.initial!.narrative.contains('Owner biography'), forSelf);
        expect(
          oracle.initial!.narrative,
          isNot(contains('Previous recipient')),
        );
        final saved = SpreadSessionSnapshot.fromJson(
          history.sessions.first.toJson(),
        );
        expect(saved.readingQuestion, question);
        expect(saved.readingForSelf, forSelf);
        await goToPane(tester, 0);
        ctrl.resetTable();
        await tester.pump();
        expect(oracle.hasSynthesis, isFalse);
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      },
    );
  }

  testWidgets(
    'SPREAD VIEW at full scale swipes on the board into Oracle Chat, and zooms cleanly',
    (tester) async {
      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>()
        ..setSpreadType(SpreadType.three);
      await tester.pump();
      expect(ctrl.spreadType, SpreadType.three);

      // At full (fit) scale, swiping left directly on the board opens Chat.
      final boardCenter = tester.getCenter(viewport);
      await tester.flingFrom(boardCenter, const Offset(-320, 0), 900);
      await tester.pumpAndSettle();
      final pageController =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(pageController.page!.round(), 1);

      // Swipe back to the Digital Table.
      await goToPane(tester, 0);
      expect(pageController.page!.round(), 0);
    },
  );

  testWidgets(
    'SYNTHESIZE CTA keeps the exact same size across dormant, ready, and OPEN ORACLE CHAT states',
    (tester) async {
      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>()
        ..setSpreadType(SpreadType.three);
      await tester.pump();

      final cta = find.byKey(const ValueKey('synthesize-cta'));
      expect(find.text('✦ SYNTHESIZE IN CHAT'), findsOneWidget);
      expect(find.textContaining('FLIP ALL CARDS'), findsNothing);
      final dormantSize = tester.getSize(cta);

      // Deal all 3 and flip 1 → still dormant with compact count, identical size.
      for (var i = 0; i < 3; i++) {
        ctrl.dealNextCardOrClarifier();
      }
      ctrl.flipSlot(0);
      await tester.pump();
      expect(find.text('✦ SYNTHESIZE IN CHAT (1/3)'), findsOneWidget);
      expect(tester.getSize(cta), dormantSize);

      // Flip remaining cards → State 2 (ignited): identical size after settle.
      ctrl.flipSlot(1);
      ctrl.flipSlot(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsOneWidget);
      final readySize = tester.getSize(cta);
      expect(readySize.width, closeTo(dormantSize.width, 0.01));
      expect(readySize.height, closeTo(dormantSize.height, 0.01));

      // Synthesize → State 3 (OPEN ORACLE CHAT) back on Table: identical size.
      await tester.tap(cta);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await goToPane(tester, 0);
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('✦ OPEN ORACLE CHAT →'), findsOneWidget);
      final postSize = tester.getSize(cta);
      expect(postSize.width, closeTo(readySize.width, 0.01));
      expect(postSize.height, closeTo(readySize.height, 0.01));
    },
  );

  testWidgets(
    'SPREAD VIEW deck matches the rendered table card size while keeping its centered dock position',
    (tester) async {
      await openTable(tester);
      final ctrl = table(tester).read<SpreadController>()
        ..setSpreadType(SpreadType.three);
      await tester.pump();
      ctrl.dealNextCardOrClarifier();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final deckCard = find.descendant(
        of: deck,
        matching: find.byType(CardBack),
      );
      final tableCard = find.descendant(
        of: viewport,
        matching: find.byType(SlottedDivinationCard),
      );
      final deckRect = tester.getRect(deckCard);
      final tableRect = tester.getRect(tableCard);

      // Horizontal deck in the dock has the exact rotated dimensions of a table card.
      expect(deckRect.width, closeTo(tableRect.height, 1.0));
      expect(deckRect.height, closeTo(tableRect.width, 1.0));
      // Centered horizontally in the dock above the board.
      expect(deckRect.center.dx, closeTo(tester.getRect(viewport).center.dx, 3.0));
      expect(deckRect.bottom, lessThanOrEqualTo(tester.getRect(viewport).top));
    },
  );
}
