import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/analyze_reading_button.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

/// Sprint 2/3 → 4 end-to-end widget flows: the context chips + Gemini
/// input capsule now live EXCLUSIVELY on the Oracle AI Chat pane, the
/// ✦ SYNTHESIZE IN CHAT CTA is permanently anchored on the Digital Table
/// (dormant → ignited), the clarifier loop and the phygital camera-to-
/// table sync.
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

  /// Deals and flips the whole Triad spread, then taps the ignited CTA —
  /// synthesis runs and the workspace slides into the Oracle AI Chat pane.
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
      'Pane 1 exclusively hosts the chips + capsule; chip tap toggles ✓ '
      'and weaves context into the reading', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');

    // Pane 0 is a pure table: no capsule, no context chips.
    expect(find.text('SLOT 1 · BEFORE YOU DRAW'), findsNothing);
    expect(find.byType(GeminiInputCapsule), findsNothing);
    expect(find.text('✨ Relationships'), findsNothing);
    expect(find.text('⚡ Crossroads'), findsNothing);
    expect(find.text('🔮 Blind Draw'), findsNothing);

    await goToPane(tester, 1);

    // Pane 1 (Oracle AI Chat) holds both exclusively.
    expect(find.byType(GeminiInputCapsule), findsOneWidget);
    expect(find.text('✨ Relationships'), findsOneWidget);
    expect(find.text('⚡ Crossroads'), findsOneWidget);
    expect(find.text('🔮 Blind Draw'), findsOneWidget);

    // A chip tap activates ONE pill (single-select radio, soft glow — no
    // ✓ icon) and silently weaves the context into the session state.
    // NO 'Context woven into the reading' lines may be appended to chat.
    await tester.tap(find.byKey(const ValueKey('context-chip-0')));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byKey(const ValueKey('context-chip-0-active')), findsOneWidget);
    final ctrl = tester
        .element(find.byType(GeminiInputCapsule))
        .read<SpreadController>();
    expect(ctrl.sessionContextNotes, contains('✨ Relationships'));
    expect(find.textContaining('Context woven into the reading'), findsNothing);

    // A second tap deselects the active pill.
    await tester.tap(find.byKey(const ValueKey('context-chip-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('context-chip-0-active')), findsNothing);

    // Tapping another pill switches the single active context.
    await tester.tap(find.byKey(const ValueKey('context-chip-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('context-chip-0-active')), findsNothing);
    expect(find.byKey(const ValueKey('context-chip-1-active')), findsOneWidget);

    // The capsule drives the chat; before synthesis it guides back to
    // the table instead of sending context into the ether.
    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'my own words',
    );
    await tester.tap(find.byKey(const ValueKey('oracle-send')));
    await tester.pump();
    expect(find.textContaining('not synthesized yet'), findsOneWidget);
  });
  testWidgets(
      'Analyze Reading stays dormant until every base card is face-up, '
      'opens Oracle without auto-synthesizing, and lets Oracle run synthesis',
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
    await tester.pump(const Duration(milliseconds: 700));
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
    expect(find.text('CURRENT SPREAD'), findsOneWidget);

    // Running synthesis from the Oracle screen streams the full reading.
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);
    expect(find.text('2 · ELEMENTAL ALCHEMY'), findsOneWidget);
    expect(find.text('3 · ACTIONABLE VERDICT'), findsOneWidget);
    // The narrative text itself carries the closing Socratic question.
    expect(find.textContaining('The question to sit with:'), findsWidgets);
    // The pinned spread header strip is on top of the chat.
    expect(find.text('CURRENT SPREAD'), findsOneWidget);
  });

  testWidgets(
      'AI clarifier questions: tap → +1 unlock → pull → clarifier reading',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);
    await dealFlipAndSynthesize(tester);

    // The synthesis ends with 3 AI-generated +1 CARD questions that
    // dynamically reference the actual cards on the table.
    final suggestions = find.textContaining('🃏 +1 CARD:');
    expect(suggestions, findsNWidgets(3));
    expect(
      find.text('WOULD YOU LIKE TO DRAW A +1 CLARIFIER CARD TO UNCOVER:'),
      findsOneWidget,
    );

    // Tap the first suggestion → the deck unlocks exactly ONE card and the
    // workspace slides back to the Digital Table with the armed banner.
    await tester.ensureVisible(suggestions.first);
    await tester.pump();
    await tester.tap(suggestions.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // pane slide
    await tester.pump();
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('clarifier-banner')), findsOneWidget);

    final ctrl = tester
        .element(find.byType(InteractiveDeckWidget))
        .read<SpreadController>();
    expect(ctrl.isDealLocked, isFalse); // exactly one unlocked
    expect(ctrl.allowedCardsLimit, 4);
    final question = ctrl.pendingClarifierQuestion!;
    expect(find.textContaining(question), findsWidgets); // banner shows it

    // Pull the unlocked card and flip it face-up → the clarifier reading
    // streams into the chat answering exactly that question.
    await dealOne(tester);
    expect(ctrl.slots.length, 4);
    expect(ctrl.isDealLocked, isTrue); // relocked immediately
    expect(find.byKey(const ValueKey('clarifier-banner')), findsNothing);

    await flipCard(tester, 3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // chapter generation
    await tester.pump();

    await goToPane(tester, 1);
    await tester.pump();
    await tester.pump();
    expect(find.text('CLARIFIER EXPANSION'), findsOneWidget);
    expect(find.textContaining(question), findsWidgets);
  });

  testWidgets('custom question in the input bar arms a +1 card draw',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);
    await dealFlipAndSynthesize(tester);

    // Empty input → gentle prompt + keyboard focus, nothing armed.
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await tester.pump();
    expect(find.textContaining('Type your question'), findsOneWidget);
    final ctrlEmpty = tester
        .element(find.byType(PageView))
        .read<SpreadController>();
    expect(ctrlEmpty.pendingClarifierQuestion, isNull);

    // A typed custom question arms the single +1 unlock and slides to the
    // table with the banner.
    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'Should I change jobs?',
    );
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // pane slide
    await tester.pump();
    final ctrl = tester
        .element(find.byType(PageView))
        .read<SpreadController>();
    expect(ctrl.pendingClarifierQuestion, 'Should I change jobs?');
    expect(ctrl.allowedCardsLimit, 4);
    expect(find.byKey(const ValueKey('clarifier-banner')), findsOneWidget);
    expect(find.textContaining('Should I change jobs?'), findsWidgets);
  });

  testWidgets('locked deck refuses a 4th draw with the synthesis prompt',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);
    for (var i = 0; i < 3; i++) {
      await dealOne(tester);
    }

    // The base spread is complete and no question is armed: a swipe-down
    // on the deck deals nothing and shows the subtle lock prompt.
    await dealOne(tester);
    final ctrl = tester
        .element(find.byType(InteractiveDeckWidget))
        .read<SpreadController>();
    expect(ctrl.dealtCount, 3);
    expect(ctrl.slots.length, 3);
    expect(ctrl.isDealLocked, isTrue);
    expect(find.textContaining('Flip all cards face-up'), findsOneWidget);
  });

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
    expect(find.text('Analyze Reading'), findsOneWidget);

    // Open Oracle → synthesize the photographed spread.
    await tester.tap(find.byKey(const ValueKey('analyze-reading-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
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


