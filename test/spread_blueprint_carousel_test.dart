import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/features/digital_table/widgets/custom_spread_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/spread_blueprint_grid.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/features/shell/widgets/pro_subscription_sheet.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/voice_input_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_voice_pipeline.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profile avatar pushes the full-page ProfileScreen',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('PERSONAL CONTEXT & BIRTH DATA'), findsOneWidget);
  });

  test('all preset spreads across all systems are open without PRO', () {
    expect(SpreadType.values.every((t) => !t.isPro), isTrue);
    expect(LenormandSpread.values.every((s) => !s.isPro), isTrue);
    expect(RuneCast.values.every((c) => !c.isPro), isTrue);
    // Exactly one universal 3-card Tarot schema.
    expect(SpreadType.values.where((t) => t.cardCount == 3).length, 1);
  });

  test('adaptive column count: 3 default, 2 on narrow screen or large font', () {
    expect(spreadGridColumnCount(maxWidth: 412, textScale: 1.0), 3);
    expect(spreadGridColumnCount(maxWidth: 360, textScale: 1.0), 3);
    expect(spreadGridColumnCount(maxWidth: 359, textScale: 1.0), 2);
    expect(spreadGridColumnCount(maxWidth: 412, textScale: 1.25), 2);
    expect(spreadGridColumnCount(maxWidth: 412, textScale: 1.4), 2);
  });

  test('count caption shows only where it helps understand spread scale', () {
    expect(shouldShowSpreadCardCount(cardCount: 1, title: 'Daily Anchor'), isFalse);
    expect(shouldShowSpreadCardCount(cardCount: 3, title: 'Three Cards'), isFalse);
    expect(shouldShowSpreadCardCount(cardCount: 3, title: 'Три карты'), isFalse);
    expect(shouldShowSpreadCardCount(cardCount: 5, title: 'Cross of 5'), isFalse);
    expect(shouldShowSpreadCardCount(cardCount: 9, title: '3×3 Portrait Box'), isFalse);
    expect(shouldShowSpreadCardCount(cardCount: 4, title: 'Target & Shadow'), isTrue);
    expect(shouldShowSpreadCardCount(cardCount: 5, title: 'Love Bridge'), isTrue);
    expect(shouldShowSpreadCardCount(cardCount: 10, title: 'Celtic Cross'), isTrue);
    expect(shouldShowSpreadCardCount(cardCount: 9, title: 'Grand Portrait'), isTrue);
  });

  test('miniature projection matches real spread geometry and stays in bounds',
      () {
    const box = Size(100, 60);
    for (final t in SpreadType.values) {
      final geom = spreadBoardGeometryForTarot(t);
      final rects = SpreadMiniaturePainter.projectSlotRects(geom, box);
      expect(rects.length, t.cardCount);
      for (final r in rects) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(box.width + 0.01));
        expect(r.bottom, lessThanOrEqualTo(box.height + 0.01));
      }
    }
    // Celtic Cross staff cards (slots 6..9) align vertically on the right.
    final celtic = SpreadMiniaturePainter.projectSlotRects(
      spreadBoardGeometryForTarot(SpreadType.celticCross),
      box,
    );
    expect(celtic[6].left, closeTo(celtic[9].left, 0.01));
    expect(celtic[6].top, lessThan(celtic[9].top));
    // Love Bridge center card (slot 2) sits between left and right shores.
    final bridge = SpreadMiniaturePainter.projectSlotRects(
      spreadBoardGeometryForTarot(SpreadType.loveBridge),
      box,
    );
    expect(bridge[2].center.dx, greaterThan(bridge[0].center.dx));
    expect(bridge[2].center.dx, lessThan(bridge[1].center.dx));
  });

  testWidgets('grid uses 3 columns on standard phone and 2 on narrow / large font',
      (tester) async {
    Future<int> columnsFor(Size size, {double textScale = 1.0}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('spread-blueprint-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      return delegate.crossAxisCount;
    }

    expect(await columnsFor(const Size(390, 844)), 3);
    expect(await columnsFor(const Size(340, 740)), 2);
    expect(await columnsFor(const Size(390, 844), textScale: 1.3), 2);
  });

  testWidgets('grid shows no PRO locks and selecting any preset opens Table immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.textContaining('PRO'), findsNothing);
    expect(find.textContaining('🔒'), findsNothing);
    expect(find.text('Three Cards'), findsOneWidget);
    expect(find.text('Love Bridge'), findsOneWidget);
    expect(find.text('Celtic Cross'), findsOneWidget);
    expect(find.text('10 cards'), findsOneWidget);
    expect(find.text('5 cards'), findsOneWidget);
    expect(find.text('3 cards'), findsNothing);
    expect(find.text('1 card'), findsNothing);

    await tester.ensureVisible(find.text('Celtic Cross'));
    await tester.pump();
    await tester.tap(find.text('Celtic Cross'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ctrl =
        tester.element(find.byType(PageView)).read<SpreadController>();
    expect(ctrl.spreadType, SpreadType.celticCross);
    expect(ctrl.isSpreadActive, isTrue);
    expect(find.byType(ProSubscriptionSheet), findsNothing);
    expect(find.text('SPREAD VIEW'), findsOneWidget);
  });

  testWidgets('Russian UI shows Три карты, Любовный мост, Кельтский крест and Свой расклад',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    tester
        .element(find.byType(PageView))
        .read<AppSettingsController>()
        .setLanguage(AppLanguage.ru);
    await tester.pump();

    expect(find.text('Выбор расклада'), findsOneWidget);
    expect(find.text('Три карты'), findsOneWidget);
    expect(find.text('Любовный мост'), findsOneWidget);
    expect(find.text('Кельтский крест'), findsOneWidget);
    expect(find.text('5 карт'), findsOneWidget);
    expect(find.text('10 карт'), findsOneWidget);
    expect(find.text('3 карты'), findsNothing);
    expect(find.text('Свой расклад'), findsOneWidget);
  });

  testWidgets(
      'Custom Spread builder: write, dictate, edit, reorder, delete questions and open Table',
      (tester) async {
    var now = DateTime(2026, 11, 24, 19, 30, 0);
    final voice = VoiceInputController(
      recorder: FakeAudioRecorderEngine(),
      transcriber: FakeAudioTranscriber(nextTranscript: 'Where is my focus?'),
      tempStore: FakeVoiceTempFileStore(),
      clock: () => now,
      hapticConfirm: () async {},
      preRollDelay: Duration.zero,
    );
    addTearDown(voice.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MindreaderApp(voiceInput: voice));
    await tester.pump();

    final gridBottom =
        tester.getRect(find.byKey(const ValueKey('spread-blueprint-grid'))).bottom;
    final customBtn = find.byKey(const ValueKey('custom-spread-button'));
    expect(tester.getRect(customBtn).top, greaterThanOrEqualTo(gridBottom));

    await tester.ensureVisible(customBtn);
    await tester.pump();
    await tester.tap(customBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(CustomSpreadSheet), findsOneWidget);
    expect(find.text('0 / 12'), findsOneWidget);

    // Optional spread name.
    await tester.enterText(
      find.byKey(const ValueKey('custom-spread-name-field')),
      'Evening Check-in',
    );

    // Add question 1 by typing.
    await tester.enterText(
      find.byKey(const ValueKey('custom-question-input')),
      'What drains me?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('custom-question-add')));
    await tester.pump();

    // Add question 2 by dictating via the upgraded voice pipeline.
    await tester.tap(find.byKey(const ValueKey('custom-question-mic')));
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('custom-question-mic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-question-add')));
    await tester.pump();

    // Add question 3 (to delete).
    await tester.enterText(
      find.byKey(const ValueKey('custom-question-input')),
      'Temporary extra',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('custom-question-add')));
    await tester.pump();
    expect(find.text('3 / 12'), findsOneWidget);

    // Delete question 3, edit question 1, and swap order (move item 1 up).
    await tester.tap(find.byKey(const ValueKey('custom-question-delete-2')));
    await tester.pump();
    expect(find.text('2 / 12'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('custom-question-edit-0')),
      'What drains my energy?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('custom-question-up-1')));
    await tester.pump();

    final openBtn = find.byKey(const ValueKey('custom-spread-open-button'));
    await tester.ensureVisible(openBtn);
    await tester.pump();
    await tester.tap(openBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final ctrl =
        tester.element(find.byType(PageView)).read<SpreadController>();
    expect(ctrl.isSpreadActive, isTrue);
    expect(ctrl.isCustomSpread, isTrue);
    expect(ctrl.spreadCardCount, 2);
    expect(ctrl.spreadLabel, '2 · Evening Check-in');
    // Reordered: "Where is my focus?" is now position 1.
    expect(ctrl.spreadSlotRoles, [
      'Where is my focus?',
      'What drains my energy?',
    ]);
    expect(find.text('1 · Where is my focus?'), findsOneWidget);
    expect(find.text('2 · What drains my energy?'), findsOneWidget);

    // Returning to Step 1 and picking a preset clears custom spread state.
    await tester.tap(find.byKey(const ValueKey('table-back-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Three Cards'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ctrl.isCustomSpread, isFalse);
    expect(ctrl.spreadType, SpreadType.three);
    expect(ctrl.spreadCardCount, 3);
  });

  testWidgets(
      '12-question Custom Spread works end-to-end: deal, reveal, synthesize question–card pairs, save & restore',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    final questions = [for (var i = 1; i <= 12; i++) 'Month $i focus?'];
    final ctx = tester.element(find.byType(PageView));
    final ctrl = ctx.read<SpreadController>()
      ..setCustomSpread(
        CustomSpreadConfig.fromQuestions(
          questions: questions,
          name: 'Year Wheel',
        ),
      )
      ..activateSpread();
    await tester.pump();

    // All 12 positions are laid out in the Spread View overview without overflow.
    expect(ctrl.slots.length, 12);
    expect(find.text('1 · Month 1 focus?'), findsOneWidget);
    expect(find.text('12 · Month 12 focus?'), findsOneWidget);

    // Deal and reveal all 12 cards.
    for (var i = 0; i < 12; i++) {
      expect(ctrl.dealNextCardOrClarifier(), i);
      ctrl.flipSlot(i);
    }
    await tester.pump();
    expect(ctrl.initialSpreadAllFaceUp, isTrue);

    // Verify prompt carries all 12 Question — Card pairs and asks to link them.
    final prompt = OracleSynthesisService.buildSynthesisPrompt(
      slots: ctrl.slots,
      system: ctrl.system,
      spreadLabel: ctrl.spreadLabel,
      focusLine: ctrl.spreadFocusLine,
      positionQuestions: ctrl.customSpread!.questions,
    )!;
    expect(prompt, contains('Question–card pairs in position order:'));
    expect(prompt, contains('1. Question: "Month 1 focus?" — Card:'));
    expect(prompt, contains('12. Question: "Month 12 focus?" — Card:'));
    expect(prompt, contains('weave all pairs together into one cohesive'));

    // Navigate to Oracle → synthesize in Chat → saves custom spread + questions in History.
    await tester.tap(find.byKey(const ValueKey('analyze-reading-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final oracle = ctx.read<OracleSessionController>();
    final history = ctx.read<SessionHistoryController>();
    expect(oracle.hasSynthesis, isTrue);
    expect(oracle.initial!.narrative, contains('1. Question: Month 1 focus?'));
    expect(oracle.initial!.narrative, contains('12. Question: Month 12 focus?'));
    expect(oracle.initial!.narrative, contains('Overall thread:'));

    final saved = SpreadSessionSnapshot.fromJson(
      history.sessions.first.toJson(),
    );
    expect(saved.customSpread, 'Year Wheel');
    expect(saved.customQuestions, questions);
    expect(saved.cards.length, 12);
    expect(saved.cards.first.role, 'Month 1 focus?');
    expect(saved.cards.last.role, 'Month 12 focus?');

    // Restore from snapshot restores all 12 cards, questions, and order.
    ctrl.exitSpread();
    ctrl.restoreSpread(
      system: saved.system,
      type: saved.spreadType,
      customSpread: saved.customSpread,
      customQuestions: saved.customQuestions,
      cards: saved.toRestoreCards(),
      sessionNotes: saved.sessionNotes,
    );
    expect(ctrl.isCustomSpread, isTrue);
    expect(ctrl.spreadCardCount, 12);
    expect(ctrl.customSpread!.questions, questions);
    expect(ctrl.slots.length, 12);
    expect(ctrl.slots.every((s) => s.state == SlotState.faceUp), isTrue);
    expect(ctrl.slots[11].role, 'Month 12 focus?');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'guided launch context routes selection to the callback, not the table',
      (tester) async {
    int? selectedCount;
    final ctrl = SpreadController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ctrl),
          ChangeNotifierProvider.value(value: AppSettingsController()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpreadBlueprintGrid(
                launchContext: SpreadLaunchContext.guidedSpread,
                onSpreadSelected: (count) => selectedCount = count,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Three Cards'));
    await tester.pump();

    expect(selectedCount, 3);
    // The digital table is NOT activated in the guided context.
    expect(ctrl.isSpreadActive, isFalse);
  });

  testWidgets('non-tarot systems open former PRO spreads immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('LENORMAND'));
    await tester.pump();
    expect(find.text('Grand Portrait'), findsOneWidget);
    await tester.tap(find.text('Grand Portrait'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ctrl =
        tester.element(find.byType(PageView)).read<SpreadController>();
    expect(ctrl.system, DivinationSystem.lenormand);
    expect(ctrl.lenormandSpread, LenormandSpread.grandPortrait);
    expect(ctrl.isSpreadActive, isTrue);
  });
}
