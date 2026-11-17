import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';

void main() {
  testWidgets('boots into the Digital Table: hero deck, badge, NO empty slots',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    // The live 78-counter: header subtitle + deck badge.
    expect(find.textContaining('78'), findsWidgets);
    expect(find.textContaining('SWIPE'), findsOneWidget);
    // The hero deck is present.
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
    // No empty placeholder slots are rendered before dealing.
    expect(find.text('Current State / Essence'), findsNothing);
    expect(find.text('Hidden Shadow / Block'), findsNothing);
    expect(find.text('Vector / Action'), findsNothing);
  });

  testWidgets('swipe down on the deck deals + depletes, tap flips the card',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Strictly touch-scoped: the deal must trigger from the deck widget.
    final deck = find.byType(InteractiveDeckWidget);
    expect(deck, findsOneWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump(); // start the flight ticker
    await tester.pump(const Duration(milliseconds: 700)); // spring flight
    await tester.pump();

    // First slot is now a face-down board card; badge dropped to 77.
    final boardCards = find.byType(TarotCard3DWidget);
    expect(boardCards, findsOneWidget);
    expect(find.textContaining('77'), findsWidgets);

    // The pillar card may sit below the viewport fold — scroll it into view
    // and tap a guaranteed-visible point near its top edge.
    await tester.ensureVisible(boardCards.first);
    await tester.pump();
    final cardRect = tester.getRect(boardCards.first);
    final tapPoint = Offset(cardRect.center.dx, cardRect.top + 30);

    // Tap reveals it face-up (750 ms arcane materialization).
    await tester.tapAt(tapPoint);
    await tester.pump(); // ticker must capture its start time first
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    // Tapping the face-up card opens the redesigned Card Inspector sheet:
    // resonance pills, slot role line and a personal-note field — and NO
    // synthesize button, NO reading-context chips.
    await tester.tapAt(tapPoint);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Resonates'), findsOneWidget);
    expect(find.text('Challenging'), findsOneWidget);
    expect(find.text('Unclear'), findsOneWidget);
    expect(find.textContaining('SLOT 1 ·'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-note-field')), findsOneWidget);
    expect(find.text('SYNTHESIZE SPREAD'), findsNothing);
    expect(find.text('READING CONTEXT'), findsNothing);
  });

  testWidgets('header spread selector resets the table: pillar empty',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Sprint 2/3: the tappable header subtitle opens the compact selector.
    await tester.tap(find.textContaining('3 · TRIAD FLOW · 78 IN DECK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SPREAD METHOD'), findsOneWidget);

    await tester.tap(find.text('7 · DEEP SYNTHESIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No placeholders: the pillar stays empty after switching the spread.
    expect(find.text('Past'), findsNothing);
    expect(find.text('Outcome'), findsNothing);
    expect(find.text('Current State / Essence'), findsNothing);
    // The header subtitle now carries the new spread label.
    expect(find.textContaining('7 · DEEP SYNTHESIS'), findsOneWidget);
  });

  testWidgets('mock camera scan hands the spread to the table face-up',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    // In the test environment the camera cannot initialize, so the screen
    // falls back to the mock viewfinder; the shutter always drives the
    // mock scan pipeline there.
    expect(find.byKey(const ValueKey('shutter')), findsOneWidget);

    // 3-card default spread.
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump(); // start the lock-on ticker
    await tester.pump(const Duration(milliseconds: 500)); // lock-on + handoff
    await tester.pump();
    // Let the deck's post-handoff collapse timer + animation settle.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Back on the Digital Table with no empty placeholders left.
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    expect(find.text('Current State / Essence'), findsNothing);
    expect(find.text('Vector / Action'), findsNothing);
    // All 3 scanned cards are face-up already.
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
  });

  testWidgets('full spread keeps the deck full-size; the badge resets it',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    // Full flight + camera-follow settle (the follow ticker starts one
    // frame late, so it needs its own extra pump).
    Future<void> settleDeal() async {
      await tester.pump(); // slot materializes; flight + follow start
      await tester.pump(const Duration(milliseconds: 700)); // flight spring
      await tester.pump(); // follow's first tick (elapsed 0)
      await tester.pump(const Duration(milliseconds: 600)); // follow done
      await tester.pump();
    }

    // Scroll the unified camera back up to the deck before each grab.
    // The drag starts on the left margin (never on the deck) and covers
    // exactly the current scroll offset, so the bounce never overshoots.
    Future<void> scrollBackToDeck() async {
      final area = tester.getRect(find.byType(SingleChildScrollView).first);
      // Sprint 4: no pane indicator — the deck rests under the header.
      final resting = 84 + tableTopPad;
      final delta = resting - tester.getTopLeft(deck).dy;
      if (delta > 4) {
        await tester.dragFrom(
          Offset(40, area.bottom - 30),
          Offset(0, delta + 24), // +18 px touch slop consumed by the drag
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800)); // bounce settles
      await tester.pump();
    }

    // Deal all 3 cards of the default Triad spread (the camera follows
    // each landing card, so we scroll back up to the deck in between).
    for (var i = 0; i < 3; i++) {
      await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
      await settleDeal();
      await scrollBackToDeck();
    }

    // The deck NEVER shrinks into a header: it keeps its 220×388 box.
    expect(find.textContaining('TAP TO RESET'), findsOneWidget);
    expect(tester.getSize(deck).width, deckWidth);
    expect(tester.getSize(deck).height, deckBoxHeight);
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));

    // Tapping the reset badge clears the table and re-shuffles the deck.
    // (The badge may sit below the fold after the camera follow — bring it
    // into view first.)
    await tester.ensureVisible(find.textContaining('TAP TO RESET'));
    await tester.pump();
    await tester.tap(find.textContaining('TAP TO RESET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(TarotCard3DWidget), findsNothing);
    expect(find.textContaining('SWIPE'), findsOneWidget);
    expect(tester.getSize(deck).width, deckWidth);
    // The dealt cards were physically re-inserted into the deck: the
    // live counter jumped back up to the full 78 (no lost cards).
    expect(find.textContaining('78'), findsWidgets);
  });

  testWidgets(
      'unified table: NO auto-scroll on deal — the camera stays on the deck',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    final resting = 84 + tableTopPad;
    expect(tester.getTopLeft(deck).dy, closeTo(resting, 0.1));

    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump(); // slot materializes; flight starts
    await tester.pump(const Duration(milliseconds: 700)); // flight spring
    await tester.pump();

    // The dealt card is 1:1 with the deck: exactly 220×360.
    final dealt = find.byType(TarotCard3DWidget);
    expect(dealt, findsOneWidget);
    expect(tester.getSize(dealt.first), const Size(deckWidth, deckHeight));
    expect(tester.getSize(deck), const Size(deckWidth, deckBoxHeight));

    // The camera did NOT auto-follow: the deck stayed put at the top of
    // the unified canvas while the card flew below the fold.
    expect(tester.getTopLeft(deck).dy, closeTo(resting, 0.1));
    final scrollArea = tester.getRect(find.byType(SingleChildScrollView).first);
    expect(tester.getBottomLeft(dealt.first).dy, greaterThan(scrollArea.bottom));

    // The user scrolls down manually whenever ready to inspect the card.
    await tester.dragFrom(
      Offset(40, scrollArea.bottom - 30),
      const Offset(0, -900),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // bounce settles
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(tester.getTopLeft(deck).dy, lessThan(resting));
    expect(tester.getBottomLeft(dealt.first).dy, lessThan(scrollArea.bottom));
  });

  testWidgets('shuffling leaves a persistent messy deck; no brick snap-back',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    // Horizontal riffle, then release.
    await tester.dragFrom(tester.getCenter(deck), const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    // Still a full-size deck (no collapse, no shrink).
    expect(tester.getSize(deck), const Size(deckWidth, deckBoxHeight));
    // And a deal still works straight out of the messy state.
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.byType(TarotCard3DWidget), findsOneWidget);
    expect(find.textContaining('77'), findsWidgets);
  });

  testWidgets('deck switcher carousel changes the active pack on the fly',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Default pack pill in the table header.
    expect(find.text('RIDER-WAITE'), findsOneWidget);

    await tester.tap(find.text('RIDER-WAITE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DECK SELECTOR'), findsOneWidget);
    // Bring the second carousel tile into the viewport and let the page
    // settle fully before tapping. (Two PageViews exist: the workspace
    // panes + the carousel inside the sheet — target the sheet's last.)
    await tester.drag(find.byType(PageView).last, const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    // Pick a different pack in the carousel.
    await tester.tap(find.text('TAROT DE MARSEILLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Close the sheet with the confirm action.
    await tester.tap(find.text('USE TAROT DE MARSEILLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The table header pill now shows the new active pack.
    expect(find.text('TAROT DE MARSEILLE'), findsOneWidget);
    expect(find.text('RIDER-WAITE'), findsNothing);
  });

  testWidgets('almanac lists cards and opens the detail sheet',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('ALMANAC'));
    await tester.pump();

    expect(find.text('All (78)'), findsOneWidget);
    // The Fool appears on the tile face AND on the tile caption.
    expect(find.text('The Fool'), findsWidgets);

    await tester.ensureVisible(find.text('The Fool').last);
    await tester.pump();
    await tester.tap(find.text('The Fool').last); // tile caption
    await tester.pump(); // start the modal route ticker
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('UPRIGHT'), findsOneWidget);
    expect(find.text('REVERSED'), findsOneWidget);
    expect(find.textContaining('blank page'), findsOneWidget);
  });

  testWidgets('FOCUS ↔ SPREAD toggle: centered proportional overview, '
      'deal materializes in the slot (no flying card)', (tester) async {
    // Portrait viewport (the default 800×600 logical test view is
    // LANDSCAPE — wider than tall).
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0; // logical 360×640 portrait
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Focus mode default: full-size tactile deck, no placeholder roles.
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
    expect(find.text('CURRENT STATE / ESSENCE'), findsNothing);

    // Switch to Spread Overview.
    await tester.tap(find.text('SPREAD VIEW'));
    await tester.pump();

    // The proportional mini-deck replaces the tactile deck, CENTERED
    // above the spread geometry; role placeholders are visible.
    expect(find.byType(InteractiveDeckWidget), findsNothing);
    final miniDeck = find.byKey(const ValueKey('overview-deck'));
    expect(miniDeck, findsOneWidget);
    final deckRect = tester.getRect(miniDeck);
    final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(deckRect.center.dx, closeTo(screenW / 2, 1.5)); // centered
    expect(find.text('CURRENT STATE / ESSENCE'), findsOneWidget);
    expect(find.text('HIDDEN SHADOW / BLOCK'), findsOneWidget);
    expect(find.text('VECTOR / ACTION'), findsOneWidget);

    // Tapping the mini-deck materializes the card DIRECTLY inside its
    // slot — no flight overlay card anywhere on screen.
    await tester.tap(miniDeck);
    await tester.pump(); // slot materializes
    await tester.pump(const Duration(milliseconds: 600)); // entrance
    await tester.pump();
    expect(find.textContaining('77'), findsWidgets);
    final dealt = find.byType(TarotCard3DWidget);
    expect(dealt, findsOneWidget);

    // The deck stays proportional to the dealt slot card (~1.12× larger,
    // never the old 3× tower). The dealt card sits inside a FittedBox
    // (paint-scaled), so compare the deck height against the CANVAS box
    // height — exactly one row of slots in a 3-card spread.
    final deckH = tester.getRect(miniDeck).height;
    final canvasH = tester
        .getSize(
          find.ancestor(of: dealt, matching: find.byType(FittedBox)).first,
        )
        .height;
    expect(deckH, greaterThanOrEqualTo(canvasH));
    expect(deckH, lessThanOrEqualTo(canvasH * 1.35));

    // Toggle back to focus: the tactile deck returns.
    await tester.tap(find.text('FOCUS VIEW'));
    await tester.pump();
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
  });

  testWidgets('spread overview goes wide in landscape: deck left, slots right',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3.0; // logical 640×360
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('SPREAD VIEW'));
    await tester.pump();

    // Deck panel anchored on the LEFT, spread slots across the wide area
    // to the RIGHT — all on one screen.
    final deckRect = tester.getRect(find.byKey(const ValueKey('overview-deck')));
    expect(deckRect.left, lessThan(200));
    expect(deckRect.top, lessThan(150));
    final firstSlot = tester.getRect(find.text('CURRENT STATE / ESSENCE'));
    final lastSlot = tester.getRect(find.text('VECTOR / ACTION'));
    expect(firstSlot.left, greaterThan(deckRect.right));
    expect(lastSlot.right, greaterThan(firstSlot.right));
  });
}
