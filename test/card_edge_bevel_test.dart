import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/features/digital_table/widgets/foil_glint.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:provider/provider.dart';

/// Sprint 5: the 3D flip is REPLACED by the meditative 750ms "arcane
/// materialization" reveal — ZERO rotateY, no harsh 90° jump:
/// * the card breathes (scale 1.0 → 1.035 → 1.0) flat on the table plane;
/// * the back dissolves into obsidian darkness and the face emerges from
///   the center outward through a radial ShaderMask;
/// * a FoilGlint light sweep crosses the revealed face;
/// * no rectangular overlay strips (ColoredBox) inside the card subtree.
void main() {
  test('reveal is the meditative 750ms', () {
    expect(cardRevealDuration, const Duration(milliseconds: 750));
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

  testWidgets(
      'mid-reveal: foil sweep + radial mask, ZERO rotateY, no side strips',
      (tester) async {
    await pumpCard(tester);

    final card = find.byType(TarotCard3DWidget);
    await tester.tapAt(tester.getCenter(card));
    await tester.pump(); // reveal ticker starts
    await tester.pump(const Duration(milliseconds: 375)); // halfway point

    // The specular sheen sweeps across the revealed face.
    expect(find.byType(FoilGlint), findsOneWidget);
    // The face materializes through a radial ShaderMask from the center.
    expect(find.byType(ShaderMask), findsOneWidget);
    // No ColoredBox/bevel strips or rectangular overlay layers protrude
    // inside the card subtree during the reveal.
    expect(
      find.descendant(of: card, matching: find.byType(ColoredBox)),
      findsNothing,
    );
  });

  testWidgets('reveal completes clean: sheen gone, no artifacts left behind',
      (tester) async {
    await pumpCard(tester);

    final card = find.byType(TarotCard3DWidget);
    await tester.tapAt(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // 750ms reveal
    await tester.pump();

    expect(find.byType(FoilGlint), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    // The card keeps its exact 220×360 footprint — nothing sticks out.
    expect(tester.getSize(card), const Size(220, 360));
  });
}

