import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_language.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/services/lunar_phase_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/rituals/daily_rituals_screen.dart';
import 'package:mindreader/features/rituals/widgets/daily_card_ritual_sheet.dart';
import 'package:mindreader/features/share/share_card_preview_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/daily_ritual_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LunarPhaseService ritual windows & spreads', () {
    test('detects active New Moon window within ±36h and builds 3-card lunar spread', () {
      // Known 2026 New Moon: Jan 18, 2026 ~19:52 UTC
      final exactNewMoon = LunarPhaseService.next(
        LunarPhase.newMoon,
        fromUtc: DateTime.utc(2026, 1, 1),
      )!;
      final active = LunarPhaseService.currentOrNextWindow(
        nowUtc: exactNewMoon.utcTime.add(const Duration(hours: 10)),
      );
      expect(active.phase, LunarPhase.newMoon);
      expect(active.isActiveNow, isTrue);
      expect(active.daysUntil, 0);

      // Well outside the window -> upcoming phase with positive daysUntil.
      final quiet = LunarPhaseService.currentOrNextWindow(
        nowUtc: exactNewMoon.utcTime.add(const Duration(days: 6)),
      );
      expect(quiet.isActiveNow, isFalse);
      expect(quiet.daysUntil, greaterThan(0));

      final newSpread = LunarPhaseService.lunarSpreadFor(
        LunarPhase.newMoon,
        AppLanguage.ru,
      );
      final fullSpread = LunarPhaseService.lunarSpreadFor(
        LunarPhase.fullMoon,
        AppLanguage.en,
      );
      expect(newSpread.cardCount, 3);
      expect(fullSpread.cardCount, 3);
      expect(newSpread.name, contains('Новолуние'));
      expect(fullSpread.name, contains('Full Moon'));
    });
  });

  group('DailyRitualController', () {
    test('draws daily card once per day, increments streak, and persists to history', () async {
      final today = DateTime(2026, 11, 24, 9, 0);
      final history = SessionHistoryController()..load();
      final ctrl = DailyRitualController(clock: () => today);
      await ctrl.load();

      expect(ctrl.drawnToday, isFalse);
      expect(ctrl.streak, 0);
      expect(ctrl.last7Days, hasLength(7));

      final entry = await ctrl.drawTodayCard(
        history: history,
        rng: Random(42),
      );
      expect(ctrl.drawnToday, isTrue);
      expect(ctrl.todayCard?.cardId, entry.cardId);
      expect(ctrl.streak, 1);
      expect(ctrl.last7Days.last.completed, isTrue);
      expect(history.sessions, hasLength(1));
      expect(history.sessions.single.cards.single.cardId, entry.cardId);

      // Re-drawing on the same day returns the exact same card.
      final second = await ctrl.drawTodayCard(
        history: history,
        rng: Random(99),
      );
      expect(second.cardId, entry.cardId);
      expect(history.sessions, hasLength(1));

      // Fresh controller instance reloads the saved Daily Card & streak.
      final reloaded = DailyRitualController(clock: () => today);
      await reloaded.load();
      expect(reloaded.drawnToday, isTrue);
      expect(reloaded.todayCard?.cardId, entry.cardId);
      expect(reloaded.streak, 1);
    });
  });

  testWidgets(
    'DailyRitualsScreen draws 30s Daily Card, opens Share preview, and launches Lunar Ritual spread',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final history = SessionHistoryController()..load();
      final daily = DailyRitualController()..load();
      CustomSpreadConfig? launchedLunar;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: history),
            ChangeNotifierProvider.value(value: daily),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: DailyRitualsScreen(
                isActive: true,
                onStartLunarSpread: (s) => launchedLunar = s,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily-card-hero-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('lunar-ritual-card')), findsOneWidget);

      // Draw Daily Card -> opens 30s reveal sheet with Share button.
      await tester.tap(find.byKey(const ValueKey('daily-card-cta')));
      await tester.pumpAndSettle();
      expect(find.byType(DailyCardRitualSheet), findsOneWidget);
      expect(daily.drawnToday, isTrue);
      expect(daily.streak, 1);

      // Tap Share inside Daily Card sheet -> opens 9:16 editorial preview.
      await tester.tap(find.byKey(const ValueKey('daily-card-share-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardPreviewSheet), findsOneWidget);

      // Close Share sheet and Daily Card sheet.
      await tester.tap(find.byKey(const ValueKey('share-sheet-close')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Launch lunar ritual spread.
      await tester.tap(find.byKey(const ValueKey('lunar-ritual-start-button')));
      await tester.pump();
      expect(launchedLunar, isNotNull);
      expect(launchedLunar!.cardCount, 3);
    },
  );
}
