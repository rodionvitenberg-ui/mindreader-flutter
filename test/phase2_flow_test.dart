import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/cosmos_send_burst.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// Sprint 2/3 end-to-end widget flows: the Gemini input capsule context
/// ("Sent to Cosmos"), the ✦ SYNTHESIZE IN CHAT → gate, the clarifier loop
/// inside the Oracle AI Chat pane and the phygital camera-to-table sync.
void main() {
  /// Deals one card from the tactile deck and settles the spring flight.
  Future<void> dealOne(WidgetTester tester) async {
    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 90));
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
    await tester.pump(); // flip ticker captures its start time
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  /// Switches panes with the 3-pill indicator (1-tap switching).
  Future<void> goToPane(WidgetTester tester, int pane) async {
    await tester.tap(find.byKey(ValueKey('pane-$pane')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // pane slide
    await tester.pump();
  }

  /// Deals and flips the whole Triad spread, then runs the synthesis and
  /// slides into the Oracle AI Chat pane.
  Future<void> dealFlipAndSynthesize(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await dealOne(tester);
    }
    for (var i = 0; i < 3; i++) {
      await flipCard(tester, i);
    }
    await tester.pump();
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump(); // synthesis starts
    await tester.pump(); // local engine resolves
    await tester.pump(const Duration(milliseconds: 700)); // pane slide
    await tester.pump();
  }

  testWidgets('capsule sends context into the ether and tags the next card',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // The decluttered table: no BEFORE YOU DRAW box, quick-context chips
    // float above the Gemini capsule instead.
    expect(find.text('SLOT 1 · BEFORE YOU DRAW'), findsNothing);
    expect(find.text('✨ Relationships'), findsOneWidget);
    expect(find.text('⚡ Crossroads'), findsOneWidget);
    expect(find.text('🔮 Blind Draw'), findsOneWidget);

    // Type a thought and send it — the capsule plays "Sent to Cosmos"
    // and the note lands in the session context.
    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'my own words',
    );
    await tester.tap(find.byKey(const ValueKey('oracle-send')));
    await tester.pump();
    expect(find.byType(CosmosSendBurst), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();

    final ctrl = tester
        .element(find.byType(InteractiveDeckWidget))
        .read<SpreadController>();
    expect(ctrl.sessionContextNotes, contains('my own words'));

    // The pending note lands on the next dealt card.
    await dealOne(tester);
    expect(ctrl.slots[0].userContext, '"my own words"');

    // A chip tap sends itself into the ether too.
    await tester.tap(find.text('✨ Relationships'));
    await tester.pump();
    expect(ctrl.sessionContextNotes, contains('✨ Relationships'));
    expect(ctrl.sessionContextNotes, hasLength(2));
  });
  testWidgets(
      '✦ SYNTHESIZE IN CHAT appears only when all cards are face-up and '
      'opens the full-width chat pane', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await dealOne(tester);
    await dealOne(tester);
    await dealOne(tester);
    await tester.pump();

    // Cards are face-down: no ceremonial CTA yet.
    expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsNothing);

    await flipCard(tester, 0);
    await flipCard(tester, 1);
    await flipCard(tester, 2);
    await tester.pump();

    // All face-up: the glowing CTA is revealed above the capsule.
    expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsOneWidget);

    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700)); // pane slide
    await tester.pump();

    // The structured synthesis streams as the first message of the
    // full-width Oracle AI Chat pane (no narrow modal box).
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
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
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
    await dealFlipAndSynthesize(tester);

    // Empty input → gentle prompt + keyboard focus, nothing armed.
    await tester.tap(find.text('🃏 +1 CARD FOR MY QUESTION'));
    await tester.pump();
    expect(find.textContaining('Type your question'), findsOneWidget);
    final ctrlEmpty = tester
        .element(find.byKey(const ValueKey('pane-0')))
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
        .element(find.byKey(const ValueKey('pane-0')))
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

    // Mock camera scan of a 3-card physical spread.
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // lock-on
    await tester.pump(const Duration(milliseconds: 700)); // settle
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Back on the table: physical-sync badge + all 3 cards face-up and
    // the CTA ready immediately.
    expect(find.text('PHYSICAL SYNC'), findsOneWidget);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
    expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsOneWidget);

    // Synthesize the photographed spread → lands in the chat pane.
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
        .element(find.byKey(const ValueKey('pane-0')))
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


