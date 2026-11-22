import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/analyze_reading_button.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  /// SPREAD VIEW is the default; deal-driven flows opt back into FOCUS VIEW.
  /// Also enters the Active Table (Step 2) from the Step 1 spread picker.
  Future<void> focusMode(WidgetTester tester) async {
    await activateSpread(tester, 'Three Cards');
    await tester.tap(find.text('FOCUS VIEW'));
    await tester.pump();
  }

  /// Deals one card from the tactile deck and settles the spring flight.
  Future<void> dealOne(WidgetTester tester) async {
    final deck = find.byType(InteractiveDeckWidget);
    // The clarifier flow may leave the deck scrolled off the top after
    // flipping cards — bring it back into the viewport first.
    await tester.ensureVisible(deck);
    await tester.pump();
    // Drag from near the deck's TOP edge (always inside the viewport, even
    // when the clarifier banner shrinks the canvas) rather than its center.
    final rect = tester.getRect(deck);
    await tester.dragFrom(
      Offset(rect.center.dx, rect.top + 40),
      const Offset(0, 90),
    );
    await tester.pump(); // slot materializes; flight starts
    await tester.pump(const Duration(milliseconds: 700)); // spring flight
    await tester.pump();
  }

  /// Scrolls to the dealt card [index] and flips it face-up.
  Future<void> flipCard(WidgetTester tester, int index) async {
    final card = find.byType(TarotCard3DWidget).at(index);
    await tester.ensureVisible(card);
    await tester.pump();
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 30));
    await tester.pump(); // reveal ticker captures its start time
    await tester.pump(const Duration(milliseconds: 800)); // 750ms reveal
    await tester.pump();
  }

  /// Deals and flips the whole Triad spread, opens the Oracle with the
  /// compact Analyze Reading button, then runs the synthesis from the Oracle
  /// preparation screen and waits for the conversation to appear.
  Future<void> dealFlipAndSynthesize(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await dealOne(tester);
    }
    for (var i = 0; i < 3; i++) {
      await flipCard(tester, i);
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('analyze-reading-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // pane slide to Oracle
    await tester.pump();
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump(); // synthesis starts
    await tester.pump(); // local engine resolves
    await tester.pump(const Duration(milliseconds: 700)); // settle
    await tester.pump();
  }

  testWidgets(
      'Analyze Reading stays dormant until every base card is face-up, '
      'opens Oracle without auto-synthesizing, then Oracle runs synthesis',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

    await dealOne(tester);
    await dealOne(tester);
    await dealOne(tester);
    await tester.pump();

    // Cards are face-down: the button is visible but disabled, and tapping
    // stays on the table (no navigation, no synthesis).
    final analyzeBtn = find.byKey(const ValueKey('analyze-reading-button'));
    expect(analyzeBtn, findsOneWidget);
    expect(find.text('Analyze Reading'), findsOneWidget);
    expect(tester.widget<AnalyzeReadingButton>(analyzeBtn).enabled, isFalse);
    await tester.tap(analyzeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(InteractiveDeckWidget), findsOneWidget); // still on the table
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsNothing);

    await flipCard(tester, 0);
    await tester.pump();
    expect(tester.widget<AnalyzeReadingButton>(analyzeBtn).enabled, isFalse);

    await flipCard(tester, 1);
    await flipCard(tester, 2);
    await tester.pump();

    // All face-up: Analyze Reading is enabled.
    expect(tester.widget<AnalyzeReadingButton>(analyzeBtn).enabled, isTrue);

    // Tapping opens Oracle WITHOUT triggering synthesis automatically.
    await tester.tap(analyzeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // pane slide
    await tester.pump();
    expect(find.text('YOUR SPREAD IS READY'), findsOneWidget);
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsNothing);

    // The Oracle preparation screen runs the synthesis on demand.
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    // The structured synthesis streams as the first message of the
    // full-width Oracle AI Chat pane (no narrow modal box).
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);
    expect(find.text('2 · ELEMENTAL ALCHEMY'), findsOneWidget);
    expect(find.text('3 · ACTIONABLE VERDICT'), findsOneWidget);
    // The narrative text itself carries the closing Socratic question.
    expect(find.textContaining('The question to sit with:'), findsWidgets);
    expect(find.byTooltip('Show reading cards'), findsOneWidget);
  });

  testWidgets(
    'Oracle reveals a suggested card in place and keeps the rail open',
    (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await focusMode(tester);
      await dealFlipAndSynthesize(tester);
      final pages = find.byType(PageView);
      final ctrl = tester.element(pages).read<SpreadController>();
      final next = ctrl.deckTop.first.id;
      await tester.tap(find.byTooltip('Show reading cards'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final rail = find.byKey(const ValueKey('oracle-card-rail'));
      final scrollable = find.descendant(
        of: rail,
        matching: find.byType(Scrollable),
      );
      await tester.drag(rail, const Offset(0, -95));
      await tester.pump(const Duration(milliseconds: 600));
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;

      final suggestion = find.textContaining('🃏 +1 CARD:').first;
      await tester.ensureVisible(suggestion);
      await tester.pump();
      await tester.tap(suggestion);
      await tester.pump();

      expect(tester.widget<PageView>(pages).controller!.page!.round(), 1);
      expect(find.byTooltip('Hide reading cards'), findsOneWidget);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      expect(ctrl.slots[3].card!.id, next);
      expect(ctrl.slots[3].state, SlotState.faceUp);
      expect(find.byKey(const ValueKey('clarifier-banner')), findsNothing);
      expect(find.text('CLARIFIER EXPANSION'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('oracle-rail-slot-3')),
        150,
        scrollable: scrollable,
      );
      final returnOffset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      await goToPane(tester, 0);
      expect(find.byType(TarotCard3DWidget), findsNWidgets(4));
      await goToPane(tester, 1);
      expect(find.byTooltip('Hide reading cards'), findsOneWidget);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        returnOffset,
      );
    },
  );

  testWidgets('custom question in the input bar immediately draws one card', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);
    await dealFlipAndSynthesize(tester);
    final ctrl = tester.element(find.byType(PageView)).read<SpreadController>();
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await tester.pump();
    expect(find.textContaining('Type your question'), findsOneWidget);
    expect(ctrl.dealtCount, 3);

    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'Should I change jobs?',
    );
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await tester.pump();
    expect(ctrl.slots[3].oracleQuestion, 'Should I change jobs?');
    expect(ctrl.slots[3].state, SlotState.faceUp);
    expect(find.textContaining('Should I change jobs?'), findsWidgets);
    expect(find.byTooltip('Show reading cards'), findsOneWidget);
  });

  testWidgets(
    'deck waits for the base reveal then accepts a manual additional card',
    (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await focusMode(tester);
      for (var i = 0; i < 3; i++) {
        await dealOne(tester);
      }

      // A fourth draw waits until the base cards are face up.
      await dealOne(tester);
      final ctrl = tester
          .element(find.byType(InteractiveDeckWidget))
          .read<SpreadController>();
      expect(ctrl.dealtCount, 3);
      expect(ctrl.slots.length, 3);
      expect(ctrl.isDealLocked, isTrue);
      expect(find.textContaining('Flip all cards face-up'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        ctrl.flipSlot(i);
      }
      await tester.pump();
      final deck = find.byType(InteractiveDeckWidget);
      await tester.ensureVisible(deck);
      await tester.pump();
      await dealOne(tester);
      expect(ctrl.slots[3].state, SlotState.faceDown);
      expect(ctrl.slots[3].oracleQuestion, isNull);
    },
  );

  testWidgets(
      'chat: a free-form question gets a grounded oracle answer',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);
    await dealFlipAndSynthesize(tester);

    // The same Gemini capsule drives the conversation on the chat pane.
    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'What should I focus on?',
    );
    await tester.tap(find.byKey(const ValueKey('oracle-send')));
    await tester.pump();
    await tester.pump(); // stream rebuilds and jumps to the bottom
    expect(find.text('What should I focus on?'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // The offline oracle answered, grounded in the table.
    expect(find.textContaining('Sitting with your question'), findsOneWidget);
  });
  testWidgets(
      'phygital sync: scanned spread gets synthesis + camera clarifier',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

    // Mock camera scan of a 3-card physical spread.
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // lock-on
    await tester.pump(const Duration(milliseconds: 700)); // settle
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // The Recognition Review sheet appears; confirm the proposed spread.
    await tester.pump(const Duration(milliseconds: 400)); // lock-on completes
    await tester.pump(const Duration(milliseconds: 400)); // review modal in
    await tester.pump();
    expect(find.text('3 RECOGNIZED'), findsOneWidget);
    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // modal out + handoff
    await tester.pump();

    // Back on the table: physical-sync badge + all 3 cards face-up and
    // the Analyze Reading button ready immediately.
    expect(find.text('PHYSICAL SYNC'), findsOneWidget);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
    expect(find.byKey(const ValueKey('analyze-reading-button')), findsOneWidget);

    // Open the Oracle with the compact button, then synthesize there.
    await tester.tap(find.byKey(const ValueKey('analyze-reading-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // pane slide
    await tester.pump();
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);

    // Photograph the next PHYSICAL clarifier card (fixed suggestion chip).
    final cameraBtn = find.text('📷 · CAMERA CLARIFIER');
    expect(cameraBtn, findsOneWidget);
    await tester.tap(cameraBtn);
    await tester.pump();

    // The camera tab is armed for a single-card scan.
    expect(
      find.text('PHOTOGRAPH YOUR NEXT PHYSICAL CARD'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // lock-on
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Back in the workspace: the photographed card is Card N+1, face-up.
    final ctrl = tester
        .element(find.byType(PageView))
        .read<SpreadController>();
    expect(ctrl.slots.length, 4);
    expect(ctrl.slots[3].state, SlotState.faceUp);
    expect(ctrl.slots[3].fromPhysicalCard, isTrue);

    // The expansion chapter generated automatically in the chat.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(find.text('CLARIFIER EXPANSION'), findsOneWidget);

    // The table pane holds all 4 cards.
    await goToPane(tester, 0);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(4));
  });
}


