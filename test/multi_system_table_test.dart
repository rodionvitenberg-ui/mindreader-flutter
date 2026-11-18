import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_rune_stones_widget.dart';
import 'package:mindreader/features/digital_table/widgets/lenormand_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// SPRINT 1/2 — the redesigned Digital Table header and Almanac drive all
/// three systems from the UI:
/// * Row 1 FOCUS/SPREAD toggle (the static "DIGITAL TABLE" title is gone),
/// * Row 2 TAROT | LENORMAND | RUNES selector,
/// * Row 3 the system-filtered pack pill + the concise spread pill
///   (no "78 IN DECK" counter, no RITUAL button),
/// * RUNES swaps the paper deck for the 3D stone cluster.
void main() {
  testWidgets('header: 3 clean rows, no old title / counter / ritual', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    expect(find.text('DIGITAL TABLE'), findsNothing);
    expect(find.text('RITUAL'), findsNothing);
    expect(find.textContaining('IN DECK'), findsNothing);

    // Row 1: the segmented view toggle.
    expect(find.text('FOCUS VIEW'), findsOneWidget);
    expect(find.text('SPREAD VIEW'), findsOneWidget);
    // Row 2: the system selector.
    expect(find.text('TAROT'), findsOneWidget);
    expect(find.text('LENORMAND'), findsOneWidget);
    expect(find.text('RUNES'), findsOneWidget);
    // Row 3: pack + spread pills.
    expect(find.byKey(const ValueKey('system-pack-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('spread-selector-pill')), findsOneWidget);
  });

  testWidgets('switching to LENORMAND swaps the pack pill and spread label', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('LENORMAND'));
    await tester.pump();

    // Pack pill shows the active Lenormand pack.
    expect(find.text('ANTIQUE PETIT LENORMAND'), findsOneWidget);
    // Spread pill shows the Lenormand spread label.
    expect(find.textContaining('3 · LENORMAND LINE'), findsOneWidget);
    // The card deck stays (Lenormand uses the same 3D card physics).
    expect(find.byType(InteractiveDeckWidget), findsOneWidget);
    expect(find.byType(InteractiveRuneStonesWidget), findsNothing);
  });

  testWidgets('switching to RUNES replaces the deck with the stone cluster', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('RUNES'));
    await tester.pump();

    expect(find.byType(InteractiveDeckWidget), findsNothing);
    expect(find.byType(InteractiveRuneStonesWidget), findsOneWidget);
    // Pack pill shows the active rune stone set.
    expect(find.text('OBSIDIAN & LAVENDER QUARTZ'), findsOneWidget);
    // The cast hint replaces the deal hint.
    expect(find.text('SWIPE ↓ TO CAST'), findsOneWidget);
  });

  testWidgets('almanac system switcher drives per-system grids and filters', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('ALMANAC'));
    await tester.pump();

    // Row 1 system switcher is present; tarot filters default.
    expect(find.byKey(const ValueKey('almanac-system-tarot')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('almanac-system-lenormand')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('almanac-system-runes')), findsOneWidget);
    expect(find.text('All (78)'), findsOneWidget);
    expect(find.text('Major (22)'), findsOneWidget);

    // LENORMAND: suit pills instead of arcana pills.
    await tester.tap(find.byKey(const ValueKey('almanac-system-lenormand')));
    await tester.pump();
    expect(find.text('All (36)'), findsOneWidget);
    expect(find.textContaining('♥ Hearts (9)'), findsOneWidget);
    expect(find.text('All (78)'), findsNothing);

    // RUNES: element bar + Aett pills.
    await tester.tap(find.byKey(const ValueKey('almanac-system-runes')));
    await tester.pump();
    expect(find.text('All (24)'), findsOneWidget);
    expect(find.textContaining('Freyr’s Aett (8)'), findsOneWidget);
    expect(find.textContaining('Hagal’s Aett (8)'), findsOneWidget);
    expect(find.textContaining('Tyr’s Aett (8)'), findsOneWidget);
  });

  testWidgets('lenormand cards render after a system switch on the table', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('LENORMAND'));
    await tester.pump();

    // Deal one card from the deck.
    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.byType(LenormandCard3DWidget), findsOneWidget);
  });

  testWidgets('face-down lenormand card flips via tap with a stable key', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('LENORMAND'));
    await tester.pump();

    // Deal one card from the deck.
    final deck = find.byType(InteractiveDeckWidget);
    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    final card = find.byType(LenormandCard3DWidget);
    expect(card, findsOneWidget);
    // The card widget (stable key) must survive the flip — no remount.
    final elementBefore = tester.element(card);

    // Bring the dealt card into the viewport, then tap to flip.
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    final elementAfter = tester.element(card);
    expect(
      identical(elementBefore, elementAfter),
      isTrue,
      reason: 'flip must NOT remount the card (stable key)',
    );
    // The tap actually flipped the card to face-up (not just key stability).
    final ctrl = tester.element(card).read<SpreadController>();
    expect(ctrl.slots.first.state == SlotState.faceUp, isTrue,
        reason: 'tap on a face-down card must flip it');
  });

  testWidgets('rune heap depletes 24 → 23 → 21 as stones are cast', (
    tester,
  ) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('RUNES'));
    await tester.pump();

    final heap = find.byType(InteractiveRuneStonesWidget);
    expect(heap, findsOneWidget);

    // Each downward cast deals one stone and shrinks the heap/ledger.
    Future<void> cast() async {
      await tester.dragFrom(tester.getCenter(heap), const Offset(0, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }

    await cast();
    await cast();
    await cast();

    // The ledger (and the heap it mirrors) deplete 24 → 21.
    final ctrl = tester.element(heap).read<SpreadController>();
    expect(
      ctrl.remaining,
      21,
      reason: 'three casts must remove three stones from the 24-stone pile',
    );
  });
}
