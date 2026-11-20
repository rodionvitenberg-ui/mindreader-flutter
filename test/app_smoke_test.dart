import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  /// Switches the table into FOCUS VIEW (the tactile hero-deck mode) after
  /// boot, for the tests that exercise deck drag physics. Also enters the
  /// Active Table (Step 2) from the Step 1 "Choose Spread" picker.
  Future<void> focusMode(WidgetTester tester) async {
    await activateSpread(tester, 'Triad Flow');
    await tester.tap(find.text('FOCUS VIEW'));
    await tester.pump();
  }

  testWidgets(
      'boots on the Step 1 picker; the Active Table opens in SPREAD VIEW',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Step 1 (Choose Spread): the TAROT|LENORMAND|RUNES system switcher and
    // the swipeable spread-blueprint row.
    expect(find.text('TAROT'), findsOneWidget);
    expect(find.text('LENORMAND'), findsOneWidget);
    expect(find.text('RUNES'), findsOneWidget);
    expect(find.text('Choose Spread'), findsOneWidget);
    expect(find.text('Triad Flow'), findsOneWidget);

      // Enter the Active Table — SPREAD VIEW is the default mode.
      await activateSpread(tester, 'Triad Flow');
      expect(find.text('FOCUS VIEW'), findsOneWidget);
      expect(find.text('SPREAD VIEW'), findsOneWidget);
      // The fixed mini-deck + empty slot placeholders are visible,
      // NOT the full-size tactile hero deck.
      expect(find.byKey(const ValueKey('overview-deck')), findsOneWidget);
      expect(find.byType(InteractiveDeckWidget), findsNothing);
      expect(find.text('TAP DECK TO DEAL'), findsOneWidget);
      // Empty slots render crisp numbered position-role labels.
      expect(find.text('1 · State'), findsOneWidget);
      expect(find.text('2 · Shadow'), findsOneWidget);
      expect(find.text('3 · Vector'), findsOneWidget);
    },
  );

  testWidgets('swipe down on the deck deals + depletes, tap flips the card',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

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
    // No deck-size counter prefixes remain on the deal pill.
    expect(find.text('SWIPE ↓ TO DEAL'), findsOneWidget);

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

  testWidgets('changing the spread from Step 1 resets the table to empty',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Start on Triad Flow (3 slots).
    await activateSpread(tester, 'Triad Flow');
    expect(find.text('1 · State'), findsOneWidget);

    // Return to Step 1 via the back button, then choose Horseshoe Synthesis.
    await tester.tap(find.byKey(const ValueKey('table-back-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Choose Spread'), findsOneWidget);
    await activateSpread(tester, 'Horseshoe Synthesis');

    // The table starts empty in the new 7-slot geometry: the Triad labels
    // are gone and the 7 Horseshoe placeholders are present.
    expect(find.text('1 · State'), findsNothing);
    expect(find.text('3 · Vector'), findsNothing);
    expect(find.text('1 · Past'), findsOneWidget);
    expect(find.text('7 · Outcome'), findsOneWidget);
    // No old preamble roles anywhere.
    expect(find.text('Current State / Essence'), findsNothing);
  });

  testWidgets('mock camera scan hands the spread to the table face-up',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    // In the test environment the camera cannot initialize, so the screen
    // falls back to the mock viewfinder; the shutter always drives the
    // mock scan pipeline there.
    expect(find.byKey(const ValueKey('shutter')), findsOneWidget);

    // 3-card default spread.
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump(); // start the lock-on ticker
    await tester.pump(const Duration(milliseconds: 500)); // lock-on completes
    await tester.pump();
    // The Recognition Review sheet appears; confirm the proposed spread.
    await tester.pump(const Duration(milliseconds: 400)); // review modal in
    await tester.pump();
    expect(find.text('3 RECOGNIZED'), findsOneWidget);
    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // modal out + handoff
    await tester.pump();
    // Let the deck's post-handoff collapse timer + animation settle.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // Back on the Active Digital Table with no empty placeholders left.
    expect(find.byKey(const ValueKey('table-back-button')), findsOneWidget);
    expect(find.text('Current State / Essence'), findsNothing);
    expect(find.text('Vector / Action'), findsNothing);
    // All 3 scanned cards are face-up already.
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
  });

  testWidgets('full spread keeps the deck full-size; the badge resets it',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

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
      // Step 2: no carousel — the deck rests just under the 56px header.
      const resting = 56.0 + tableTopPad;
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
    // The pill shows the fresh deal hint (counters were removed by design).
    expect(find.text('SWIPE ↓ TO DEAL'), findsOneWidget);
  });

  testWidgets(
      'unified table: NO auto-scroll on deal — the camera stays on the deck',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await focusMode(tester);

    final deck = find.byType(InteractiveDeckWidget);
    const resting = 56.0 + tableTopPad;
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
    await focusMode(tester);

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
    expect(find.text('SWIPE ↓ TO DEAL'), findsOneWidget);
  });

  testWidgets('almanac deck picker changes the active pack on the fly',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Deck selection moved from the table into the Almanac tab.
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    expect(find.text('RIDER-WAITE'), findsOneWidget); // active-pack pill

    await tester.tap(find.byKey(const ValueKey('almanac-pack-pill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DECK SELECTOR'), findsOneWidget);
    // Bring the second carousel tile into the viewport and let the page
    // settle fully before tapping.
    await tester.drag(find.byType(PageView).last, const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    // Pick a different pack in the carousel: the tap selects + persists it
    // immediately — the bottom "USE ..." confirm button is gone.
    await tester.tap(find.text('TAROT DE MARSEILLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dismiss the sheet (tap the barrier above it).
    await tester.tapAt(const Offset(400, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The Almanac pack pill now shows the new active pack.
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
    // The Fool appears as the uppercase tile caption.
    expect(find.text('THE FOOL'), findsWidgets);

    await tester.ensureVisible(find.text('THE FOOL').last);
    await tester.pump();
    await tester.tap(find.text('THE FOOL').last); // tile caption
    await tester.pump(); // start the modal route ticker
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('UPRIGHT'), findsOneWidget);
    expect(find.text('REVERSED'), findsOneWidget);
    expect(find.textContaining('blank page'), findsOneWidget);
  });

  testWidgets('SPREAD ↔ FOCUS toggle: default overview, proportional deck, '
      'deal materializes in the slot (no flying card)', (tester) async {
    // Portrait viewport (the default 800×600 logical test view is
    // LANDSCAPE — wider than tall).
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0; // logical 360×640 portrait
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Triad Flow');

    // SPREAD VIEW is the default: fixed mini-deck + empty slot
    // placeholders, NO full-size tactile deck.
    expect(find.byType(InteractiveDeckWidget), findsNothing);
    final miniDeck = find.byKey(const ValueKey('overview-deck'));
    expect(miniDeck, findsOneWidget);
    expect(find.text('1 · State'), findsOneWidget);
    expect(find.text('2 · Shadow'), findsOneWidget);
    expect(find.text('3 · Vector'), findsOneWidget);

    // Switch to Focus: the full-size tactile deck returns.
    await tester.tap(find.text('FOCUS VIEW'));
    await tester.pump();
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);

    // Back to Spread Overview.
    await tester.tap(find.text('SPREAD VIEW'));
    await tester.pump();

    // The fixed mini-deck replaces the tactile deck, CENTERED
    // above the spread geometry; role placeholders are visible.
    expect(find.byType(InteractiveDeckWidget), findsNothing);
    final deckRect = tester.getRect(miniDeck);
    final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(deckRect.center.dx, closeTo(screenW / 2, 1.5)); // centered

    // Tapping the mini-deck materializes the card DIRECTLY inside its
    // slot — no flight overlay card anywhere on screen.
    await tester.tap(miniDeck);
    await tester.pump(); // slot materializes
    await tester.pump(const Duration(milliseconds: 800)); // 750ms mist entrance
    await tester.pump();
    expect(find.text('TAP DECK TO DEAL'), findsOneWidget);
    final dealt = find.byType(TarotCard3DWidget);
    expect(dealt, findsOneWidget);

    // The deck stays on its horizontal dock while the card belongs to the
    // interactive board at its native design dimensions.
    final viewer = find.ancestor(
      of: dealt,
      matching: find.byType(InteractiveViewer),
    );
    expect(viewer, findsOneWidget);
    expect(
      tester.getRect(miniDeck).bottom,
      lessThanOrEqualTo(tester.getRect(viewer).top),
    );
    expect(tester.getSize(dealt), const Size(deckWidth, deckHeight));
  });

  testWidgets(
    'landscape keeps the deck under the switch and above the interactive board',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2.0; // logical 960×540 landscape
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Triad Flow');

    // SPREAD VIEW is the default — no toggle tap needed.

      final deckRect = tester.getRect(
        find.byKey(const ValueKey('overview-deck')),
      );
      final viewport = tester.getRect(
        find.byKey(const ValueKey('spread-viewport')),
      );
      expect(
        deckRect.top,
        greaterThan(tester.getRect(find.text('SPREAD VIEW')).bottom),
      );
      expect(deckRect.center.dx, closeTo(viewport.center.dx, 1));
      expect(deckRect.bottom, lessThanOrEqualTo(viewport.top));
      expect(
        viewport.contains(tester.getCenter(find.text('1 · State'))),
        isTrue,
      );
      expect(
        viewport.contains(tester.getCenter(find.text('3 · Vector'))),
        isTrue,
      );
    },
  );
}
