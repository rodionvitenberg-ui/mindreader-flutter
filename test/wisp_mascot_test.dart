import 'package:flutter/material.dart' hide Element;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/guide_event.dart';
import 'package:mindreader/core/models/guide_hint.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/widgets/reading_guide.dart';
import 'package:mindreader/features/digital_table/widgets/wisp_face_painter.dart';
import 'package:mindreader/features/digital_table/widgets/wisp_mascot.dart';
import 'package:mindreader/features/digital_table/widgets/wisp_mood.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

/// G2.2 — the companion's face: the pure mood mapping and the real wisp in the
/// guide bar. Mimicry is the point, so every expression must be reachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GuideHint hint(GuideEventType type) => GuideHint(
    id: 'test-${type.name}',
    eventType: type,
    title: 'Title',
    body: 'Body',
  );

  group('wispMoodFor', () {
    test('a quiet companion sleeps while nothing is asked', () {
      expect(wispMoodFor(null), WispMood.sleeping);
    });

    test('an actionable step is met with curiosity', () {
      expect(wispMoodFor(hint(GuideEventType.dealingStarted)), WispMood.curious);
      expect(
        wispMoodFor(hint(GuideEventType.revealingStarted)),
        WispMood.curious,
      );
    });

    test('an opposing pair is met with sympathy, not celebration', () {
      expect(
        wispMoodFor(hint(GuideEventType.relationshipTapped), tension: true),
        WispMood.empathetic,
      );
      expect(
        wispMoodFor(hint(GuideEventType.relationshipTapped)),
        WispMood.curious,
      );
    });

    test('a finished spread is the one celebration', () {
      expect(
        wispMoodFor(hint(GuideEventType.spreadCompleted)),
        WispMood.greeting,
      );
      expect(
        wispMoodFor(hint(GuideEventType.spreadCompleted), tension: true),
        WispMood.greeting,
      );
    });
  });

  test('every expression paints without throwing', () {
    for (final mood in WispMood.values) {
      final recorder = ui.PictureRecorder();
      WispFacePainter(
        mood: mood,
        blinkProgress: 0,
        gaze: const Offset(.4, -.3),
        pulse: .5,
      ).paint(Canvas(recorder), const Size.square(96));
      recorder.endRecording().dispose();
    }
  });

  group('WispMascot in the guide bar', () {
    late SpreadController spread;
    late AppSettingsController settings;
    late GuidedReadingController guide;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      spread = SpreadController();
      settings = AppSettingsController();
      await settings.initialLoad;
      guide = GuidedReadingController(spread: spread, settings: settings);
      await settings.setAid(ReadingAid.guide, true);
    });

    tearDown(() {
      guide.dispose();
      settings.dispose();
      spread.dispose();
    });

    Future<void> pumpBar(WidgetTester tester, {bool reduced = false}) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: spread),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: guide),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Scaffold(body: ReadingGuide()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    WispMood moodOf(WidgetTester tester) =>
        tester.widget<WispMascot>(find.byType(WispMascot)).mood;

    testWidgets('renders the authored sprite under a painted face', (
      tester,
    ) async {
      await pumpBar(tester);
      spread.activateSpread();
      await tester.pump();

      final mascot = find.byType(WispMascot);
      final sprite = tester.widget<Image>(
        find.descendant(of: mascot, matching: find.byType(Image)),
      );
      // `cacheWidth` wraps the asset in a ResizeImage — unwrap it to prove the
      // authored sprite (not a placeholder) is what gets drawn.
      final provider = sprite.image is ResizeImage
          ? (sprite.image as ResizeImage).imageProvider
          : sprite.image;
      expect(
        (provider as AssetImage).assetName,
        'assets/images/wisp_body.png',
      );
      expect(
        find.descendant(of: mascot, matching: find.byType(CustomPaint)),
        findsWidgets,
      );
    });

    testWidgets('rides along with the hint and reacts to tension', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.byType(WispMascot), findsNothing); // Step 1 — no table yet.

      spread.activateSpread();
      await tester.pump();
      expect(moodOf(tester), WispMood.curious);

      spread.loadScannedSpread(
        system: DivinationSystem.tarot,
        cards: [
          for (final element in [Element.fire, Element.water, Element.air])
            TarotDivinationCard(
              tarotDeck.firstWhere((c) => c.element == element),
            ),
        ],
        reversed: const [false, false, false],
        spreadType: SpreadType.three,
      );
      await tester.pump();
      expect(moodOf(tester), WispMood.greeting);

      // Touching the opposing pair turns the celebration into sympathy.
      guide.explainRelationship(
        spread.relationships.firstWhere((r) => r.isContradictory),
      );
      await tester.pump();
      expect(moodOf(tester), WispMood.empathetic);

      guide.clearRelationship();
      await tester.pump();
      expect(moodOf(tester), WispMood.greeting);

      await settings.setAid(ReadingAid.guide, false);
      await tester.pump();
      expect(find.byType(WispMascot), findsNothing);
    });

    testWidgets('reduce motion keeps the companion still', (tester) async {
      await pumpBar(tester, reduced: true);
      spread.activateSpread();
      await tester.pump();
      expect(find.byType(WispMascot), findsOneWidget);

      // A repeating float/breath would never settle; with reduce-motion the
      // companion must stop scheduling frames.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
