import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/oracle_chat_pane.dart';
import 'package:mindreader/features/digital_table/widgets/analyze_reading_button.dart';
import 'package:mindreader/features/digital_table/widgets/reading_context_field.dart';
import 'package:mindreader/features/digital_table/widgets/reading_subject_toggle.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final analyzeButton = find.byKey(const ValueKey('analyze-reading-button'));

  Future<SpreadController> openTable(
    WidgetTester tester, {
    String spread = 'Three Cards',
    Size size = const Size(390, 844),
    FakeViewPadding? padding,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (padding != null) {
      tester.view.padding = padding;
      addTearDown(tester.view.resetPadding);
    }
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, spread);
    return tester
        .element(find.byType(DigitalTableScreen))
        .read<SpreadController>();
  }

  testWidgets(
    'Analyze Reading is hidden on Choose Spread and appears only on the active dealing table',
    (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      expect(find.text('Choose Spread'), findsOneWidget);
      expect(analyzeButton, findsNothing);

      await activateSpread(tester, 'Three Cards');
      expect(analyzeButton, findsOneWidget);
      final dormantRect = tester.getRect(analyzeButton);
      expect(
        tester.widget<AnalyzeReadingButton>(analyzeButton).enabled,
        isFalse,
      );

      final spread = tester
          .element(find.byType(DigitalTableScreen))
          .read<SpreadController>();
      for (var i = 0; i < 3; i++) {
        spread.dealNextCard();
        spread.flipSlot(i);
      }
      await tester.pump();
      expect(
        tester.widget<AnalyzeReadingButton>(analyzeButton).enabled,
        isTrue,
      );
      expect(tester.getRect(analyzeButton), dormantRect);

      // Returning to Choose Spread hides Analyze Reading again.
      await tester.tap(find.byKey(const ValueKey('table-back-button')));
      await tester.pump();
      expect(find.text('Choose Spread'), findsOneWidget);
      expect(analyzeButton, findsNothing);
    },
  );

  testWidgets(
    'Digital Table removes redundant Oracle preparation controls in Spread and Focus views',
    (tester) async {
      await openTable(tester);

      void expectCleanTable() {
        expect(find.byType(ReadingSubjectToggle), findsNothing);
        expect(find.byType(ReadingContextField), findsNothing);
        expect(find.byType(SynthesizeChatCta), findsNothing);
        expect(find.text('FOR MYSELF (PROFILE)'), findsNothing);
        expect(find.text('FOR SOMEONE ELSE'), findsNothing);
        expect(find.byKey(const ValueKey('reading-context')), findsNothing);
        expect(find.textContaining('SYNTHESIZE IN CHAT'), findsNothing);
        expect(analyzeButton, findsOneWidget);
        expect(find.text('Analyze Reading'), findsOneWidget);
      }

      expectCleanTable();

      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expectCleanTable();

      await tester.tap(find.text('SPREAD VIEW'));
      await tester.pump();
      expectCleanTable();
    },
  );

  testWidgets(
    'Analyze Reading navigates to Oracle without auto-synthesizing and preserves session & cards',
    (tester) async {
      final ctrl = await openTable(tester);
      final ctx = tester.element(find.byType(DigitalTableScreen));
      final oracle = ctx.read<OracleSessionController>();

      // Disabled until all cards are dealt and revealed.
      expect(tester.widget<AnalyzeReadingButton>(analyzeButton).enabled, isFalse);
      await tester.tap(analyzeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page!.round(),
        0,
      );

      // Deal and flip all 3 cards.
      for (var i = 0; i < 3; i++) {
        ctrl.dealNextCardOrClarifier();
        ctrl.flipSlot(i);
      }
      await tester.pump();

      final expectedIds = ctrl.slots.map((s) => s.card!.id).toList();
      final expectedReversed = ctrl.slots.map((s) => s.isReversed).toList();
      final initialEpoch = oracle.epoch;
      final initialSessionId = oracle.sessionId;

      expect(tester.widget<AnalyzeReadingButton>(analyzeButton).enabled, isTrue);

      // Tap Analyze Reading → opens Oracle pane, NO synthesis triggered.
      await tester.tap(analyzeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page!.round(),
        1,
      );
      expect(find.byType(OracleChatPane), findsOneWidget);
      expect(find.text('YOUR SPREAD IS READY'), findsOneWidget);
      expect(oracle.generatingInitial, isFalse);
      expect(oracle.hasSynthesis, isFalse);
      expect(oracle.messages, isEmpty);
      expect(oracle.epoch, initialEpoch);
      expect(oracle.sessionId, initialSessionId);

      // Oracle screen still provides the preparation controls.
      expect(find.byType(ReadingSubjectToggle), findsOneWidget);
      expect(find.byType(ReadingContextField), findsOneWidget);

      // Navigate back to the table via the Oracle back button.
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page!.round(),
        0,
      );
      expect(ctrl.spreadType, SpreadType.three);
      expect(ctrl.slots.map((s) => s.card!.id).toList(), expectedIds);
      expect(ctrl.slots.map((s) => s.isReversed).toList(), expectedReversed);
      expect(ctrl.slots.every((s) => s.state == SlotState.faceUp), isTrue);
    },
  );

  testWidgets('Analyze Reading localizes via AppStrings', (tester) async {
    await openTable(tester);
    expect(find.text('Analyze Reading'), findsOneWidget);

    tester
        .element(find.byType(DigitalTableScreen))
        .read<AppSettingsController>()
        .setLanguage(AppLanguage.ru);
    await tester.pump();

    expect(find.text('Анализ расклада'), findsOneWidget);
    expect(find.text('Analyze Reading'), findsNothing);
  });

  testWidgets(
    'responsive: small screen with nav insets and Celtic Cross renders cleanly without overlap',
    (tester) async {
      final ctrl = await openTable(
        tester,
        spread: 'Celtic Cross',
        size: const Size(360, 640),
        padding: const FakeViewPadding(top: 24, bottom: 48),
      );

      expect(tester.takeException(), isNull);
      expect(analyzeButton, findsOneWidget);
      expect(ctrl.spreadType, SpreadType.celticCross);

      final buttonRect = tester.getRect(analyzeButton);
      final dockRect = tester.getRect(find.byIcon(Icons.style_outlined));
      final viewportRect = tester.getRect(
        find.byKey(const ValueKey('spread-viewport')),
      );

      // Sits cleanly between the spread viewport and the bottom dock.
      expect(buttonRect.top, greaterThanOrEqualTo(viewportRect.bottom - 1));
      expect(buttonRect.bottom, lessThanOrEqualTo(dockRect.top + 1));

      // Tap deck still deals cards cleanly on Celtic Cross.
      await tester.tap(find.byKey(const ValueKey('overview-deck')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();
      expect(ctrl.dealtCount, 1);

      // Switching between Spread View and Focus View causes no overflow.
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(analyzeButton, findsOneWidget);

      await tester.tap(find.text('SPREAD VIEW'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(analyzeButton, findsOneWidget);
    },
  );
}
