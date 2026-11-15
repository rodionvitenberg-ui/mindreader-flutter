import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';

void main() {
  testWidgets('boots into the Digital Table with 3 empty slots',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    expect(find.text('3 · TRIAD FLOW'), findsOneWidget); // header pill label
    // 3 empty slot placeholders with their role labels.
    expect(find.text('Current State'), findsOneWidget);
    expect(find.text('Hidden Barrier'), findsOneWidget);
    expect(find.text('Action Vector'), findsOneWidget);
  });

  testWidgets('swipe down on the deck deals, tap flips the card',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Strictly touch-scoped: the deal must trigger from the deck widget.
    final deck = find.byType(InteractiveDeckWidget);
    expect(deck, findsOneWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump(); // start the flight ticker
    await tester.pump(const Duration(milliseconds: 600)); // flight animation
    await tester.pump();

    // First slot is now a face-down board card.
    final boardCards = find.byType(TarotCard3DWidget);
    expect(boardCards, findsOneWidget);
    expect(find.text('Current State'), findsNothing); // placeholder replaced

    // Tap flips it face-up (600 ms) and the placeholder is gone for good.
    await tester.tap(boardCards.first);
    await tester.pump(); // ticker must capture its start time first
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    // Tapping the face-up card opens the reflection sheet.
    await tester.tap(boardCards.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Card Reflection'), findsOneWidget);
  });

  testWidgets('spread selector resets the table to 7 slots',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.ensureVisible(find.text('7 · DEEP SYNTHESIS'));
    await tester.pump();
    await tester.tap(find.text('7 · DEEP SYNTHESIS'));
    await tester.pump();

    expect(find.text('The Heart of the Matter'), findsOneWidget);
    expect(find.text('The Outcome'), findsOneWidget);
    expect(find.text('Current State'), findsNothing);
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

    // Back on the Digital Table with no empty placeholders left.
    expect(find.text('DIGITAL TABLE'), findsOneWidget);
    expect(find.text('Current State'), findsNothing);
    expect(find.text('Action Vector'), findsNothing);
    // All 3 scanned cards are face-up already.
    expect(find.byType(TarotCard3DWidget), findsNWidgets(3));
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
}
