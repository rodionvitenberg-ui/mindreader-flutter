import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/foil_glint.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:provider/provider.dart';

/// Sprint 4: the flip must be CLEAN. The old 3D edge-bevel strips (the
/// rectangular side bars that stuck out during rotateY) are gone — the
/// only overlay mid-flip is the FoilGlint specular sheen, fully inside
/// the card's rounded border.
void main() {
  test('flip is the ceremonial 680ms', () {
    expect(cardFlipDuration, const Duration(milliseconds: 680));
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeckPackController(),
        child: MaterialApp(
          home: Center(
            child: TarotCard3DWidget(
              card: tarotDeck[0],
              isReversed: false,
              state: SlotState.faceDown,
              width: 220,
              height: 360,
              tilt: false,
              onFlip: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mid-flip: foil sheen present, ZERO side strips inside the card',
      (tester) async {
    await pumpCard(tester);

    final card = find.byType(TarotCard3DWidget);
    await tester.tapAt(tester.getCenter(card));
    await tester.pump(); // flip ticker starts
    await tester.pump(const Duration(milliseconds: 340)); // edge-on moment

    // The specular sheen slides across the surface mid-flip.
    expect(find.byType(FoilGlint), findsOneWidget);
    // No ColoredBox/bevel strips or any rectangular overlay layers
    // protrude inside the card subtree during the flip.
    expect(
      find.descendant(of: card, matching: find.byType(ColoredBox)),
      findsNothing,
    );
  });

  testWidgets('flip completes clean: sheen gone, no artifacts left behind',
      (tester) async {
    await pumpCard(tester);

    final card = find.byType(TarotCard3DWidget);
    await tester.tapAt(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.byType(FoilGlint), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    // The card keeps its exact 220×360 footprint — nothing sticks out.
    expect(tester.getSize(card), const Size(220, 360));
  });
}

