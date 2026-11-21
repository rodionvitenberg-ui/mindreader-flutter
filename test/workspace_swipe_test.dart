import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

/// Sprint 2/3 → 4 workspace tests: the 3-pane horizontal PageView, gesture
/// disambiguation with the 3D deck, and the local history save/restore.
/// Sprint 4: panes switch EXCLUSIVELY by horizontal swipe (the top 3-pill
/// indicator bar was removed).
void main() {
  /// SPREAD VIEW is the default; deal-driven flows opt back into FOCUS VIEW.
  Future<void> focusMode(WidgetTester tester) async {
    await tester.tap(find.text('FOCUS VIEW'));
    await tester.pump();
  }

  Future<void> dealOne(WidgetTester tester) async {
    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  Future<void> flipCard(WidgetTester tester, int index) async {
    final card = find.byType(TarotCard3DWidget).at(index);
    await tester.ensureVisible(card);
    await tester.pump();
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // 750ms reveal
    await tester.pump();
  }

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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('✦ SYNTHESIZE IN CHAT →'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }
  testWidgets(
      '3-pane workspace: swipe left through Chat into History and back',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Step 1 (Choose Spread): the TAROT|LENORMAND|RUNES system switcher.
    expect(find.text('TAROT'), findsOneWidget);
    expect(find.text('NO READING YET'), findsNothing);

    // Enter the Active Digital Table (Step 2).
    await activateSpread(tester, 'Three Cards');
    expect(find.byKey(const ValueKey('overview-deck')), findsOneWidget);
    expect(find.text('NO READING YET'), findsNothing);

    // Swipe left on the table background (never on the deck) → Pane 1.
    await goToPane(tester, 1);
    expect(find.text('NO READING YET'), findsOneWidget);
    expect(find.text('Oracle'), findsOneWidget);

    // Swipe once more → Pane 2: Spread History & Notebooks (PRO).
    await goToPane(tester, 2);
    expect(find.text('SPREAD HISTORY'), findsOneWidget);
    expect(find.text('PRO ∞'), findsOneWidget);
    expect(find.text('NEW SPREAD · НОВЫЙ РАСКЛАД'), findsOneWidget);
    expect(find.text('ALL READINGS'), findsOneWidget);
    expect(find.text('RELATIONSHIPS'), findsOneWidget);
    expect(find.text('CAREER & PATH'), findsOneWidget);

    // Swipe right twice → back on the Digital Table.
    await goToPane(tester, 0);
    expect(find.byKey(const ValueKey('overview-deck')), findsOneWidget);
  });

  testWidgets(
      'horizontal drags on the 3D deck shuffle it and never switch panes',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    await focusMode(tester);

    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    // Still on the Digital Table pane; the deck kept its full 168×303 box
    // (the PageView never stole the riffle gesture).
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
    expect(find.text('NO READING YET'), findsNothing);
    expect(tester.getSize(deck), const Size(deckWidth, deckBoxHeight));

    // And a deal still works straight out of the messy state.
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.byType(TarotCard3DWidget), findsOneWidget);
  });
  testWidgets(
      'history: a synthesized session saves and restores in one tap '
      '(cards + conversation)', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    await focusMode(tester);
    await dealFlipAndSynthesize(tester);

    // One conversational turn, so the dialog is captured too.
    await tester.enterText(
      find.byKey(const ValueKey('oracle-input')),
      'What should I focus on?',
    );
    await tester.tap(find.byKey(const ValueKey('oracle-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Open the history pane: the session tile is waiting there.
    await goToPane(tester, 2);
    expect(find.text('SPREAD HISTORY'), findsOneWidget);
    expect(find.text('3 · THREE CARDS'), findsOneWidget);

    // Start a fresh table through the archive action. NEW SPREAD exits back
    // to Step 1 (Choose Spread) and clears the table.
    await tester.tap(find.text('NEW SPREAD · НОВЫЙ РАСКЛАД'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final ctrl = tester
        .element(find.byType(PageView))
        .read<SpreadController>();
    expect(ctrl.dealtCount, 0);
    expect(ctrl.remaining, 78);

    // NEW SPREAD lands on Step 1; re-enter the Active Table before swiping
    // to the history pane.
    await activateSpread(tester, 'Three Cards');

    // 1-tap restore: it lands on the ORACLE CHAT (Pane 1) with the exact
    // conversation restored — no jarring jump back to the raw table.
    await goToPane(tester, 2);
    await tester.tap(find.text('3 · THREE CARDS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    final paneController =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(paneController.page!.round(), 1);
    expect(find.text('What should I focus on?'), findsOneWidget);
    expect(find.textContaining('Sitting with your question'), findsOneWidget);

    expect(find.byKey(const ValueKey('oracle-input')), findsOneWidget);
    await tester.tap(find.byTooltip('Show reading cards'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('oracle-rail-slot-0')), findsOneWidget);

    // The exact cards are restored face-up back on the table (Pane 0).
    await goToPane(tester, 0);
    expect(ctrl.slots.length, 3);
    expect(ctrl.slots.every((s) => s.state == SlotState.faceUp), isTrue);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
  });
}


