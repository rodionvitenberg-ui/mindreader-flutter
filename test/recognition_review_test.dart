import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/lenormand_data.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/spread_inference_service.dart';
import 'package:mindreader/features/camera_scan/widgets/recognition_review_sheet.dart';

void main() {
  final tarot0 = TarotDivinationCard(tarotDeck[0]);
  final tarot1 = TarotDivinationCard(tarotDeck[1]);
  final tarot2 = TarotDivinationCard(tarotDeck[2]);

  SpreadInferenceResult infer(int count) => const SpreadInferenceService().infer(
        SpreadInferenceInput(
          system: DivinationSystem.tarot,
          detectedCount: count,
        ),
      );

  testWidgets('renders count, proposed spread and reorders on confirm',
      (tester) async {
    RecognitionReviewResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await RecognitionReviewSheet.show(
                    context,
                    cards: [tarot0, tarot1, tarot2],
                    reversed: [false, false, false],
                    inference: infer(3),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('3 RECOGNIZED'), findsOneWidget);
    expect(find.textContaining('Triad Flow'), findsWidgets);
    expect(find.text('1 · ${tarot0.name}'), findsOneWidget);

    // Move the first card down — order is confirmed by the reader.
    await tester.tap(find.byTooltip('Move down').first);
    await tester.pump();
    expect(find.text('1 · ${tarot1.name}'), findsOneWidget);

    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.cards.first.name, tarot1.name);
    expect(captured!.spread?.tarot, SpreadType.three);
  });

  testWidgets('orientation toggle is shown for tarot, hidden for lenormand',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => RecognitionReviewSheet.show(
                  context,
                  cards: [tarot0],
                  reversed: [false],
                  inference: infer(1),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Toggle orientation'), findsOneWidget);
  });

  testWidgets('lenormand cards show no orientation toggle or REVERSED label',
      (tester) async {
    final lenormand = LenormandDivinationCard(lenormandDeck[0]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => RecognitionReviewSheet.show(
                  context,
                  cards: [lenormand],
                  reversed: [false],
                  inference: const SpreadInferenceService().infer(
                    SpreadInferenceInput(
                      system: DivinationSystem.lenormand,
                      detectedCount: 1,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Toggle orientation'), findsNothing);
    expect(find.text('REVERSED'), findsNothing);
  });

  testWidgets('remove drops a card from the confirmed list', (tester) async {
    RecognitionReviewResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await RecognitionReviewSheet.show(
                    context,
                    cards: [tarot0, tarot1],
                    reversed: [false, false],
                    inference: infer(2),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('2 RECOGNIZED'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pump();
    expect(find.text('1 RECOGNIZED'), findsOneWidget);

    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pumpAndSettle();
    expect(captured!.cards.length, 1);
  });

  testWidgets('freeform shows no spread and keeps every card', (tester) async {
    RecognitionReviewResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured = await RecognitionReviewSheet.show(
                    context,
                    cards: [tarot0, tarot1, tarot2],
                    reversed: [false, false, false],
                    inference: infer(8), // no 8-card template → Freeform
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('FREEFORM'), findsOneWidget);

    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pumpAndSettle();
    // Freeform: spread is null, all cards preserved in order.
    expect(captured!.spread, isNull);
    expect(captured!.cards.length, 3);
  });
}
