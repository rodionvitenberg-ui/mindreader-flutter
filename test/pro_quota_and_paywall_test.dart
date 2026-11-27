import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/backend_auth_service.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/astral/astral_screen.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/features/shell/widgets/pro_subscription_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/backend_auth_controller.dart';
import 'package:mindreader/state/daily_quota_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('DailyQuotaController enforces 3 Quick Scan, 1 Guided, 1 Live, 3 Oracle messages and resets next day', () {
    var now = DateTime(2026, 11, 26, 12, 0);
    final quota = DailyQuotaController(clock: () => now);

    // Quick Scan: 3 free/day
    for (var i = 0; i < 3; i++) {
      expect(quota.canUseCameraMode(ReadingMode.quickScan, isPro: false), isTrue);
      quota.recordCameraMode(ReadingMode.quickScan);
    }
    expect(quota.canUseCameraMode(ReadingMode.quickScan, isPro: false), isFalse);
    expect(quota.canUseCameraMode(ReadingMode.quickScan, isPro: true), isTrue);

    // Guided Spread: 1 free/day
    expect(quota.canUseCameraMode(ReadingMode.guidedSpread, isPro: false), isTrue);
    quota.recordCameraMode(ReadingMode.guidedSpread);
    expect(quota.canUseCameraMode(ReadingMode.guidedSpread, isPro: false), isFalse);

    // Live Oracle: 1 free/day
    expect(quota.canUseCameraMode(ReadingMode.liveOracle, isPro: false), isTrue);
    quota.recordCameraMode(ReadingMode.liveOracle);
    expect(quota.canUseCameraMode(ReadingMode.liveOracle, isPro: false), isFalse);

    // Oracle messages: 3 free per thread, 4th blocked
    expect(quota.canSendOracleMessage(0, isPro: false), isTrue);
    expect(quota.canSendOracleMessage(2, isPro: false), isTrue);
    expect(quota.canSendOracleMessage(3, isPro: false), isFalse);
    expect(quota.canSendOracleMessage(3, isPro: true), isTrue);

    // Next day resets daily camera limits automatically.
    now = DateTime(2026, 11, 27, 0, 5);
    expect(quota.canUseCameraMode(ReadingMode.quickScan, isPro: false), isTrue);
    expect(quota.remainingToday(ReadingMode.quickScan), 3);
  });

  test('proCheckoutDestination includes plan and email query params', () {
    final uri = proCheckoutDestination(
      plan: 'early_monthly',
      email: 'reader@example.com',
      locale: 'ru',
      promoOverride: 'https://soshallitbe.cyou',
    );
    expect(uri.host, 'soshallitbe.cyou');
    expect(uri.path, '/pro/');
    expect(uri.queryParameters['plan'], 'early_monthly');
    expect(uri.queryParameters['email'], 'reader@example.com');
    expect(uri.queryParameters['lang'], 'ru');
  });

  testWidgets(
    'Oracle chat softly closes thought on 4th free message and opens PRO glass sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final spread = SpreadController()..setSpreadType(SpreadType.one);
      spread.activateSpread();
      spread.dealNextCard();
      spread.flipSlot(0);

      final session = OracleSessionController();
      session.initial = const StructuredSynthesis(
        narrative: 'The Star brings calm clarity.',
        elementalAlchemy: 'Air and Water.',
        verdict: 'Trust the next step.',
        followUp: 'What feels lighter?',
      );
      // Pre-fill 3 completed user turns in this thread.
      for (var i = 1; i <= 3; i++) {
        session.addUserMessage('Question $i');
        session.addOracleMessage('Answer $i');
      }

      final settings = AppSettingsController();
      final quota = DailyQuotaController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: spread),
            ChangeNotifierProvider.value(value: session),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: quota),
            ChangeNotifierProvider(create: (_) => OracleVoiceService()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider(create: (_) => SessionHistoryController()),
            ChangeNotifierProvider(create: (_) => AstralController()),
            ChangeNotifierProvider(create: (_) => BackendAuthController()),
            ChangeNotifierProvider(
              create: (c) => GuidedReadingController(
                spread: c.read<SpreadController>(),
                settings: c.read<AppSettingsController>(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => UserProfileController()),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: const Scaffold(body: TableWorkspace()),
          ),
        ),
      );
      await tester.pump();

      // Jump directly to Chat pane (index 1).
      tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .jumpToPage(chatPane);
      await tester.pump();

      // Attempt to send the 4th message.
      await tester.enterText(
        find.byKey(const ValueKey('oracle-input')),
        'One more question?',
      );
      await tester.tap(find.byKey(const ValueKey('oracle-send')));
      await tester.pumpAndSettle();

      // Oracle appended the calm closing line AND slid up the PRO sheet.
      expect(
        session.messages.last.text,
        AppStrings.g('oracle.quota.softClosing'),
      );
      expect(find.byKey(const ValueKey('pro-subscription-sheet')), findsOneWidget);
      expect(find.text('\$4.99'), findsOneWidget);
      expect(find.text('\$6.99'), findsOneWidget);
    },
  );

  testWidgets(
    'Astral locks Synastry and 3rd profile for Free users, and Check Status unlocks via /api/v1/account/me/',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/config/public/') {
          return http.Response(
            jsonEncode({
              'systems': ['tarot', 'lenormand', 'runes'],
              'guestAccess': true,
              'emailVerification': false,
              'devPayments': false,
              'proOffer': {
                'earlySupporterTotal': 100,
                'earlySupporterRemaining': 87,
                'earlyMonthlyMinor': 499,
                'standardMonthlyMinor': 699,
                'annualMinor': 3999,
              },
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/auth/login/') {
          return http.Response(
            jsonEncode({
              'id': 'u-1',
              'verified': true,
              'email': 'paid@example.com',
              'name': 'Paid Reader',
              'emailConfirmed': true,
              'isPro': true,
              'proPlan': 'early_monthly',
              'earlySupporterSlot': 14,
              'token': 'tok-123',
              'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
            }),
            200,
          );
        }
        if (req.url.path == '/api/v1/account/me/') {
          return http.Response(
            jsonEncode({
              'id': 'u-1',
              'verified': true,
              'email': 'paid@example.com',
              'name': 'Paid Reader',
              'emailConfirmed': true,
              'isPro': true,
              'proPlan': 'early_monthly',
              'earlySupporterSlot': 14,
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final auth = BackendAuthController(
        service: BackendAuthService(baseUrl: 'https://api.example.test', client: client),
      );
      await auth.initialLoad;
      // Sign in so check-status can hit /api/v1/account/me/ directly.
      await auth.signInWithPassword(email: 'paid@example.com', password: 'password123');

      final settings = AppSettingsController();
      final astral = AstralController();
      // Add 2 free profiles: 3rd must be blocked.
      astral.generateChart(
        NatalCalculatorService.calculateNatalChart(
          id: 'p1',
          profileName: 'Self',
          birthDateUtc: DateTime.utc(1994, 5, 12, 4, 0),
          birthLocalYear: 1994,
          birthLocalMonth: 5,
          birthLocalDay: 12,
          birthLocalHour: 10,
          birthLocalMinute: 0,
          timeKnown: true,
          cityName: 'Bishkek',
          country: 'KG',
          latitude: 42.87,
          longitude: 74.59,
          timezoneOffsetHours: 6,
          houseSystem: HouseSystem.placidus,
        ),
      );
      astral.generateChart(
        NatalCalculatorService.calculateNatalChart(
          id: 'p2',
          profileName: 'Partner',
          birthDateUtc: DateTime.utc(1995, 8, 22, 10, 0),
          birthLocalYear: 1995,
          birthLocalMonth: 8,
          birthLocalDay: 22,
          birthLocalHour: 15,
          birthLocalMinute: 0,
          timeKnown: true,
          cityName: 'Almaty',
          country: 'KZ',
          latitude: 43.24,
          longitude: 76.95,
          timezoneOffsetHours: 5,
          houseSystem: HouseSystem.placidus,
        ),
      );
      expect(astral.canCreateOrGenerateChart(), isFalse);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: astral),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => UserProfileController()),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: const Scaffold(body: AstralScreen()),
          ),
        ),
      );
      await tester.pump();

      // Switching to Synastry tab shows the PRO lock gate.
      await tester.tap(find.byKey(const ValueKey('astral-window-synastry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('synastry-pro-gate')), findsOneWidget);

      // Open PRO sheet from Synastry lock, check live remaining slots (87/100),
      // and tap "ALREADY PAID? CHECK STATUS" -> unlocks immediately!
      await tester.tap(find.byKey(const ValueKey('synastry-unlock-pro-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pro-subscription-sheet')), findsOneWidget);
      expect(find.textContaining('87'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pro-check-status-button')));
      await tester.pumpAndSettle();

      expect(settings.isProUnlocked, isTrue);
      expect(astral.isProUnlocked, isTrue);
      expect(astral.canCreateOrGenerateChart(), isTrue);
      expect(find.byKey(const ValueKey('synastry-pro-gate')), findsNothing);
    },
  );
}
