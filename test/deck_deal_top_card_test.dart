import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/interactive_deck_widget.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// Sprint 1/3 — True Top-Card Extraction: the downward grab applies the
/// finger translation DIRECTLY to the actual topmost rendered card layer
/// (no spawned proxy) and hands off the true top card of the shuffled
/// deck (depth 0) starting from that card's exact stack position.
void main() {
  Widget harness({required void Function(DeckDealReleaseRequest) onDeal}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpreadController()),
        ChangeNotifierProvider(create: (_) => DeckPackController()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveDeckWidget(
              key: const ValueKey('deck'),
              randomSeed: 42,
              onDealRelease: onDeal,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('downward grab drags the actual top card and deals depth 0',
      (tester) async {
    DeckDealReleaseRequest? request;
    await tester.pumpWidget(harness(onDeal: (r) => request = r));
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    expect(deck, findsOneWidget);

    await tester.dragFrom(tester.getCenter(deck), const Offset(0, 100));
    await tester.pump();

    expect(request, isNotNull);
    // The true top card of the shuffled deck — never a picked mid-stack
    // layer or a fake spawned proxy.
    expect(request!.depth, 0);

    // The flight starts at the grabbed card's exact stack position:
    // deckTopCardDy(78) == 0 for a full deck, plus the topmost layer's
    // 19 × 0.35 px stack offset, plus the finger travel.
    final baseDy = deckTopCardDy(78) + 19 * layerThicknessPx;
    expect(request!.cardOffsetLocal.dx, 0);
    expect(request!.cardOffsetLocal.dy, greaterThan(baseDy + 40));
    expect(request!.cardOffsetLocal.dy, lessThan(baseDy + 100));
  });

  testWidgets('the dragged card is the rendered top layer itself — no proxy',
      (tester) async {
    await tester.pumpWidget(harness(onDeal: (_) {}));
    await tester.pump();

    final deck = find.byType(InteractiveDeckWidget);
    final gesture =
        await tester.startGesture(tester.getCenter(deck));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();

    // Mid-drag the deck still renders exactly its visible fan layers —
    // the top card itself carries the drag transform, no additional proxy
    // card was spawned on top.
    final backs = find.descendant(
      of: find.byType(InteractiveDeckWidget),
      matching: find.byType(CardBack),
    );
    expect(tester.widgetList(backs).length, fanLayerCount);

    await gesture.up();
    await tester.pump();
  });
}
