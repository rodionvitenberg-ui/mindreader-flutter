import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_language.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/micro_learning_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/training/micro_learning_screen.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/training_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MicroLearningService offline drills', () {
    test('parses local tarot_pair_drills.json and generates all 3 modes offline', () {
      final raw = File('assets/data/tarot_pair_drills.json').readAsStringSync();
      final pairs = TarotPairDrill.parseJson(raw);
      expect(pairs.length, greaterThanOrEqualTo(15));

      for (final system in DivinationSystem.values) {
        for (final mode in DrillMode.values) {
          final qs = MicroLearningService.generateSession(
            system: system,
            mode: mode,
            lang: AppLanguage.ru,
            tarotPairs: pairs,
            count: 6,
            rng: Random(7),
          );
          expect(qs, hasLength(6));
          for (final q in qs) {
            expect(q.options, hasLength(4));
            expect(q.correctIndex, inInclusiveRange(0, 3));
            expect(q.cards, isNotEmpty);
          }
        }
      }
    });
  });

  testWidgets(
    'MicroLearningScreen completes a 6-question 2-minute session and records mastery',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final raw = File('assets/data/tarot_pair_drills.json').readAsStringSync();
      final pairs = TarotPairDrill.parseJson(raw);
      final training = TrainingController()..load();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: training),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: MicroLearningScreen(
              initialSystem: DivinationSystem.tarot,
              initialMode: DrillMode.mixed,
              tarotPairsOverride: pairs,
              randomSeed: 12,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Answer all 6 questions (WispMascot floats continuously so pump, don't settle).
      for (var step = 0; step < 6; step++) {
        final opt0 = find.byKey(const ValueKey('training-option-0'));
        await tester.ensureVisible(opt0);
        await tester.pump();
        await tester.tap(opt0);
        await tester.pump(const Duration(milliseconds: 100));

        final nextBtn = find.byKey(const ValueKey('training-next-button'));
        await tester.ensureVisible(nextBtn);
        await tester.pump();
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const ValueKey('training-completion-card')), findsOneWidget);
      expect(training.sessionsCompleted, 1);
      expect(training.totalAnswered, 6);
    },
  );
}
