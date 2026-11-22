import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/models/guide_event.dart';
import 'package:mindreader/core/models/guide_hint.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/widgets/guide_mascot.dart';
import 'package:mindreader/features/digital_table/widgets/reading_guide.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GuideHint hint(GuideEventType type) => GuideHint(
    id: 'test-${type.name}',
    eventType: type,
    title: 'Title',
    body: 'Body',
  );

  group('guideMascotMoodFor', () {
    test('no hint means the companion idles quietly', () {
      expect(guideMascotMoodFor(null), GuideMascotMood.idle);
    });

    test('an actionable hint makes the companion point', () {
      expect(
        guideMascotMoodFor(hint(GuideEventType.dealingStarted)),
        GuideMascotMood.hint,
      );
    });

    test('a finished spread makes the companion celebrate', () {
      expect(
        guideMascotMoodFor(hint(GuideEventType.spreadCompleted)),
        GuideMascotMood.celebrate,
      );
    });
  });

  group('GuideMascot in the guide bar', () {
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

    testWidgets('it rides along with the hint and celebrates a full spread', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.byType(GuideMascot), findsNothing); // Step 1 — no table yet.

      spread.activateSpread();
      await tester.pump();
      final mascot = find.byType(GuideMascot);
      expect(mascot, findsOneWidget);
      expect(tester.widget<GuideMascot>(mascot).mood, GuideMascotMood.hint);

      for (var i = 0; i < 3; i++) {
        spread.dealNextCard();
      }
      spread.flipSlot(0);
      spread.flipSlot(1);
      spread.flipSlot(2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<GuideMascot>(find.byType(GuideMascot)).mood,
        GuideMascotMood.celebrate,
      );

      await settings.setAid(ReadingAid.guide, false);
      await tester.pump();
      expect(find.byType(GuideMascot), findsNothing);
    });

    testWidgets('reduce motion keeps the star still and idle-free', (
      tester,
    ) async {
      await pumpBar(tester, reduced: true);
      spread.activateSpread();
      await tester.pump();
      expect(find.byType(GuideMascot), findsOneWidget);

      // A repeating idle pulse would never settle; with reduce-motion the
      // mascot must stop scheduling frames.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
