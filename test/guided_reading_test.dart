import 'package:flutter/material.dart' hide Element;
import 'package:flutter/gestures.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/guide_event.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/widgets/reading_bottom_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  testWidgets(
    'visibility and optional guidance follow out-of-order reveals in both views',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await activateSpread(tester, 'Three Cards');
      final ctx = tester.element(find.byType(DigitalTableScreen));
      final ctrl = ctx.read<SpreadController>();
      final settings = ctx.read<AppSettingsController>();
      await settings.setAid(ReadingAid.positions, false);
      await tester.pump();
      expect(find.text('1 · State'), findsNothing);
      final guide = find.byKey(const ValueKey('reading-guide'));
      expect(guide, findsNothing);
      final order = ctrl.deckTop.map((c) => c.id).take(3).toList();
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('overview-deck'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 16));
      final target = find.byKey(const ValueKey('spread-slot-0'));
      final highlight = find.descendant(
        of: target,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color ==
                  TaroColors.lavender.withValues(alpha: .12),
        ),
      );
      expect(highlight, findsOneWidget);
      await finger.moveTo(tester.getCenter(target));
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await settings.setAid(ReadingAid.guide, true);
      await tester.pump();
      expect(guide, findsOneWidget);
      expect(ctrl.recommendedSlot, 1);
      ctrl.dealNextCard();
      ctrl.dealNextCard();
      ctrl.flipSlot(2);
      expect(ctrl.recommendedSlot, 1);
      ctrl.flipSlot(1);
      expect(ctrl.recommendedSlot, 0);
      ctrl.flipSlot(0);
      expect(ctrl.recommendedSlot, isNull);
      await tester.pump();
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expect(guide, findsOneWidget);
      expect(ctrl.slots.map((s) => s.card!.id), order);
      String prompt() => OracleSynthesisService.buildSynthesisPrompt(
        slots: ctrl.slots,
        system: ctrl.system,
        spreadLabel: ctrl.spreadLabel,
        focusLine: ctrl.spreadFocusLine,
        relationships: ctrl.relationships,
      )!;
      final before = prompt();
      expect(
        before,
        contains('Three-card dignity: compare the flanking influences'),
      );
      await settings.setAid(ReadingAid.guide, false);
      await settings.setAid(ReadingAid.relationships, true);
      await tester.pump();
      expect(guide, findsNothing);
      expect(prompt(), before);
    },
  );

  testWidgets('opening the guide sheet teaches its lesson exactly once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    final ctx = tester.element(find.byType(DigitalTableScreen));
    final settings = ctx.read<AppSettingsController>();
    await settings.setAid(ReadingAid.guide, true);
    await settings.setGuideDetail(GuideDetail.thorough);
    await tester.pump();

    final lesson = find.textContaining('essence of the matter');
    final bar = find.byKey(const ValueKey('reading-guide'));
    await tester.ensureVisible(bar);
    await tester.pump();

    await tester.tap(bar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(lesson, findsOneWidget);

    Navigator.of(tester.element(find.byType(TaroGlassSheet))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Reading the lesson is what teaches it: the mentor stops repeating it.
    await tester.tap(bar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(lesson, findsNothing);
    expect(find.byType(TaroGlassSheet), findsOneWidget);
  });

  testWidgets('tapping a relationship row asks the guide to explain the link', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    final ctx = tester.element(find.byType(DigitalTableScreen));
    final ctrl = ctx.read<SpreadController>();
    final settings = ctx.read<AppSettingsController>();
    final guide = ctx.read<GuidedReadingController>();
    await settings.setAid(ReadingAid.guide, true);
    await settings.setAid(ReadingAid.relationships, true);
    await settings.setGuideDetail(GuideDetail.thorough);

    // A face-up spread whose first pair pulls in different directions.
    ctrl.loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: [
        for (final element in [Element.fire, Element.water, Element.air])
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == element),
          ),
      ],
      reversed: const [false, false, false],
      spreadType: SpreadType.three,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('spread-slot-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ReadingBottomSheet), findsOneWidget);

    final row = find.byKey(const ValueKey('relationship-row-0-1'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The inspector closes and the mentor takes over the same link.
    expect(find.byType(ReadingBottomSheet), findsNothing);
    expect(guide.currentHint!.eventType, GuideEventType.relationshipTapped);
    expect(guide.currentHint!.lessonId, 'conflict:tarot');

    // Opening the mentor bar teaches the tension in the sheet.
    await tester.tap(find.byKey(const ValueKey('reading-guide')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('the tension'), findsOneWidget);

    // The reader returns to the spread: the explicit link stops hijacking the
    // mentor and the table's own hint comes back.
    await tester.tap(find.text('Back to the spread'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaroGlassSheet), findsNothing);
    expect(guide.currentHint!.eventType, GuideEventType.spreadCompleted);
  });
}
