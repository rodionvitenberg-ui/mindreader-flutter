import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// Phase 2 end-to-end widget flows: pre-draw intention prompts, the
/// ceremonial SYNTHESIZE READING gate, the endless clarifier loop and the
/// phygital camera-to-table sync.
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

  /// Deals and flips the whole Triad spread, then runs the synthesis
  /// until the three sections are on the table.
  Future<void> dealFlipAndSynthesize(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await dealOne(tester);
    }
    for (var i = 0; i < 3; i++) {
      await flipCard(tester, i);
    }
    await tester.pump();
    await tester.ensureVisible(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.tap(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump(); // start the async synthesis
    await tester.pump(); // local engine resolves
    await tester.pump(const Duration(seconds: 6)); // typewriter reveal
    await tester.pump();
  }

  testWidgets('intention bar asks the slot question; chip lands in the slot',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Slot 1 question + the four zero-friction chips above the deck.
    expect(
      find.text('What is on your mind right now? Where is the tension?'),
      findsOneWidget,
    );
    expect(find.text('Relationships & Feelings'), findsOneWidget);
    expect(find.text('Career / Money Crossroads'), findsOneWidget);
    expect(find.text('Inner Doubt'), findsOneWidget);
    expect(find.text('Let the Deck Decide'), findsOneWidget);

    // Tap a chip (highlights immediately), then pull the card.
    await tester.tap(find.text('Relationships & Feelings'));
    await tester.pump();
    await dealOne(tester);

    final ctrl = tester
        .element(find.byType(InteractiveDeckWidget))
        .read<SpreadController>();
    expect(ctrl.slots[0].userContext, 'Relationships & Feelings');

    // The bar advanced to the Slot 2 question.
    expect(
      find.text('What hidden force or fear is influencing this?'),
      findsOneWidget,
    );
  });


  testWidgets(
      'SYNTHESIZE READING appears only when all cards are face-up and '
      'opens the three-section panel', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await dealOne(tester);
    await dealOne(tester);
    await dealOne(tester);
    await tester.pump();

    // Cards are face-down: no ceremonial CTA yet.
    expect(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'), findsNothing);

    await flipCard(tester, 0);
    await flipCard(tester, 1);
    await flipCard(tester, 2);
    await tester.pump();

    // All face-up: the ceremonial CTA is revealed below the spread.
    expect(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'), findsOneWidget);

    await tester.ensureVisible(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.tap(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    // The structured synthesis renders directly on the table.
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);
    expect(find.text('2 · ELEMENTAL ALCHEMY'), findsOneWidget);
    expect(find.text('3 · ACTIONABLE VERDICT'), findsOneWidget);
    expect(find.textContaining('The question to sit with:'), findsWidgets);
  });


  testWidgets('endless clarifier loop: +1 card and its expansion chapter',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await dealFlipAndSynthesize(tester);
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);

    // The follow-up prompts live at the bottom of the synthesis panel.
    final prompt =
        find.text('+ Pull 1 Card: What is the hidden obstacle?');
    await tester.ensureVisible(prompt);
    await tester.pump();
    await tester.tap(prompt);
    await tester.pump(); // clarifier slot appended + dealt
    await tester.pump(const Duration(milliseconds: 700)); // flight spring
    await tester.pump();

    expect(find.byType(TarotCard3DWidget), findsNWidgets(4));

    // Flip the clarifier → the chapter generates automatically.
    await flipCard(tester, 3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.textContaining('CLARIFIER EXPANSION'), findsOneWidget);
    expect(find.textContaining('What is the hidden obstacle?'),
        findsWidgets);

    // The bar above the deck switched to the endless-clarifier mode.
    await tester.ensureVisible(find.text('EXPAND THE READING'));
    await tester.pump();
    expect(find.text('EXPAND THE READING'), findsOneWidget);
  });


  testWidgets(
      'phygital sync: scanned spread gets context prompts, synthesis and '
      'camera clarifier buttons', (tester) async {
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

    // Back on the table: physical-sync badge + all 3 cards face-up.
    expect(find.text('PHYSICAL SYNC'), findsOneWidget);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));

    // Pre-synthesis context prompts for the photographed cards.
    expect(find.text('ADD CONTEXT FOR YOUR CARDS'), findsOneWidget);
    await tester.tap(find.text('Relationships & Feelings'));
    await tester.pump();
    await tester.tap(find.text('APPLY'));
    await tester.pump();
    final ctrl = tester
        .element(find.text('PHYSICAL SYNC'))
        .read<SpreadController>();
    expect(ctrl.slots[0].userContext, 'Relationships & Feelings');

    // Synthesize the photographed spread.
    await tester.ensureVisible(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.tap(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('1 · CORE NARRATIVE SYNTHESIS'), findsOneWidget);

    // The camera-sync clarifier pair is offered in the panel.
    final cameraBtn = find.text('📷 Photograph Next Physical Card');
    await tester.ensureVisible(cameraBtn);
    await tester.pump();
    expect(cameraBtn, findsOneWidget);
    expect(find.text('🃏 Draw from Digital Deck'), findsOneWidget);

    // Draw a digital clarifier straight from the panel.
    await tester.tap(find.text('🃏 Draw from Digital Deck'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.byType(TarotCard3DWidget), findsNWidgets(4));
  });


  testWidgets(
      'photographing the next physical card arms the camera for one card '
      'and appends it face-up', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Reach the synthesized physical-sync table.
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.ensureVisible(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.tap(find.text('СИНТЕЗИРОВАТЬ ПРОГНОЗ'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    // Photograph the next PHYSICAL clarifier card.
    final cameraBtn = find.text('📷 Photograph Next Physical Card');
    await tester.ensureVisible(cameraBtn);
    await tester.pump();
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

    // Back on the table: the photographed card is Card N+1, face-up.
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(4));
    final ctrl = tester
        .element(find.text('DIGITAL TABLE'))
        .read<SpreadController>();
    expect(ctrl.slots.length, 4);
    expect(ctrl.slots[3].state, SlotState.faceUp);
    expect(ctrl.slots[3].fromPhysicalCard, isTrue);

    // The expansion chapter generated automatically.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('CLARIFIER EXPANSION'), findsOneWidget);
  });
}

