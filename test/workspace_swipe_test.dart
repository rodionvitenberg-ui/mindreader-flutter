import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// Sprint 2/3 → 4 workspace tests: the 3-pane horizontal PageView, gesture
/// disambiguation with the 3D deck, and the local history save/restore.
/// Sprint 4: panes switch EXCLUSIVELY by horizontal swipe (the top 3-pill
/// indicator bar was removed).
void main() {
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
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  }

  /// Swipes horizontally across the workspace until [pane] is the active
  /// page (the test viewport is 800 px wide, so a drag must clear half a
  /// page, >400 px, to snap into the next pane).
  Future<void> goToPane(WidgetTester tester, int pane) async {
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    var current = controller.page!.round();
    while (current != pane) {
      await tester.dragFrom(
        const Offset(200, 300),
        Offset(current < pane ? -600 : 600, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // The drag release ends in a fling whose ballistic keeps the
      // PageView's scrollable in pointer-ignoring mode — pump until the
      // activity fully settles so taps on the pane content land.
      while (controller.position.isScrollingNotifier.value) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pump();
      current = controller.page!.round();
    }
  }

  Future<void> dealFlipAndSynthesize(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await dealOne(tester);
    }
    for (var i = 0; i < 3; i++) {
      await flipCard(tester, i);
    }
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

    // Pane 0: the Digital Table.
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    expect(find.text('NO READING YET'), findsNothing);

    // Swipe left on the table background (never on the deck) → Pane 1.
    await goToPane(tester, 1);
    expect(find.text('NO READING YET'), findsOneWidget);
    expect(find.text('CURRENT SPREAD'), findsOneWidget);

    // Swipe once more → Pane 2: Spread History & Notebooks (PRO).
    await goToPane(tester, 2);
    expect(find.text('SPREAD HISTORY'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('+ NEW SPREAD · НОВЫЙ РАСКЛАД'), findsOneWidget);
    expect(find.text('ALL READINGS'), findsOneWidget);
    expect(find.text('RELATIONSHIPS'), findsOneWidget);
    expect(find.text('CAREER & PATH'), findsOneWidget);

    // Swipe right twice → back on the Digital Table.
    await goToPane(tester, 0);
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
  });

  testWidgets(
      'horizontal drags on the 3D deck shuffle it and never switch panes',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    // Still on the Digital Table pane; the deck kept its full 220×388 box
    // (the PageView never stole the riffle gesture).
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
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
    expect(find.text('3 · TRIAD FLOW'), findsOneWidget);

    // Start a fresh table through the archive action.
    await tester.tap(find.text('+ NEW SPREAD · НОВЫЙ РАСКЛАД'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final ctrl = tester
        .element(find.byType(InteractiveDeckWidget))
        .read<SpreadController>();
    expect(ctrl.dealtCount, 0);
    expect(ctrl.remaining, 78);

    // 1-tap restore: the exact cards land on the table, face-up.
    await goToPane(tester, 2);
    await tester.tap(find.text('3 · TRIAD FLOW'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(ctrl.slots.length, 3);
    expect(ctrl.slots.every((s) => s.state == SlotState.faceUp), isTrue);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));

    // And the exact conversation is restored in the chat pane.
    await goToPane(tester, 1);
    expect(find.text('What should I focus on?'), findsOneWidget);
    expect(find.textContaining('Sitting with your question'), findsOneWidget);
  });
}


