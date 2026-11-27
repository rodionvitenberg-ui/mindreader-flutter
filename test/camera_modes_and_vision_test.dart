import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/services/vision_scanner_service.dart';
import 'package:mindreader/features/camera_scan/camera_scan_screen.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/daily_quota_controller.dart';
import 'package:mindreader/state/live_oracle_controller.dart';
import 'package:mindreader/state/live_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('VisionScannerService.matchTarotCard resolves IDs, synonyms, and rejects unknown text', () {
    expect(VisionScannerService.matchTarotCard(cardId: 'tarot:17')?.name, 'The Star');
    expect(VisionScannerService.matchTarotCard(name: 'Magician')?.name, 'The Magician');
    expect(VisionScannerService.matchTarotCard(name: 'XVII - The Star')?.name, 'The Star');
    expect(VisionScannerService.matchTarotCard(name: 'Knave of Coins')?.name, 'Page of Pentacles');
    expect(VisionScannerService.matchTarotCard(name: '3 of Chalices')?.name, 'Three of Cups');
    expect(VisionScannerService.matchTarotCard(name: 'Not A Real Card'), isNull);
  });

  test('VisionScannerService.detectSpread calls Django /api/v1/vision/scan-spread/ in reading order', () async {
    late Uri capturedUri;
    late String capturedAuth;
    final mockClient = MockClient((request) async {
      capturedUri = request.url;
      capturedAuth = request.headers['Authorization'] ?? '';
      return http.Response(
        jsonEncode({
          'mode': 'quick_scan',
          'strategy': 'crops',
          'provider': 'deepseek-flash',
          'cropCount': 2,
          'cards': [
            {
              'index': 1,
              'cardId': 'tarot:17',
              'deckIndex': 17,
              'name': 'The Star',
              'reversed': false,
              'orientation': 'upright',
              'confidence': 0.96,
              'centerNorm': [0.22, 0.50],
              'isLandscape': false,
            },
            {
              'index': 2,
              'cardId': 'tarot:19',
              'deckIndex': 19,
              'name': 'The Sun',
              'reversed': true,
              'orientation': 'reversed',
              'confidence': 0.92,
              'centerNorm': [0.78, 0.50],
              'isLandscape': true,
            },
          ],
          'warnings': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = VisionScannerService(client: mockClient);
    final cards = await service.detectSpread(
      jpeg: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      mode: 'quick_scan',
      backendBaseUrl: 'https://api.soshallitbe.cyou',
      bearerToken: 'test-token-123',
    );

    expect(capturedUri.path, '/api/v1/vision/scan-spread/');
    expect(capturedAuth, 'Bearer test-token-123');
    expect(cards.length, 2);
    expect(cards[0].card.name, 'The Star');
    expect(cards[0].isReversed, isFalse);
    expect(cards[0].centerNorm, [0.22, 0.50]);
    expect(cards[1].card.name, 'The Sun');
    expect(cards[1].isReversed, isTrue);
    expect(cards[1].isLandscape, isTrue);
  });

  Widget buildCameraHarness({VoidCallback? onHandoff}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsController()),
        ChangeNotifierProvider(create: (_) => SpreadController()),
        ChangeNotifierProvider(create: (_) => OracleSessionController()),
        ChangeNotifierProvider(create: (_) => OracleVoiceService()),
        ChangeNotifierProvider(create: (_) => LiveReadingController()),
        ChangeNotifierProvider(create: (_) => LiveOracleController()),
        ChangeNotifierProvider(create: (_) => DailyQuotaController()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CameraScanScreen(onHandoff: onHandoff ?? () {}),
        ),
      ),
    );
  }

  testWidgets('Guided Spread mounts GuidedSpreadHud, scans card, confirms, and binds slot 0', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCameraHarness());
    await tester.pump(const Duration(milliseconds: 300));

    // Switch camera mode selector to Guided Spread.
    await tester.tap(find.byKey(ValueKey('camera-mode-${ReadingMode.guidedSpread.name}')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('guided-spread-hud')), findsOneWidget);

    // Tap shutter -> scans 1 card, finishes 400ms lock-on, and enters awaitingConfirmation.
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.byKey(const ValueKey('guided-pending-card')), findsOneWidget);

    // Confirm detected card -> binds slot 0 and shows Oracle caption.
    await tester.tap(find.byKey(const ValueKey('guided-primary-CONFIRM')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('camera-oracle-caption')), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('Live Oracle mounts CompactOracle, scans card, appends to live strip & shows commentary', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCameraHarness());
    await tester.pump(const Duration(milliseconds: 300));

    // Switch camera mode selector to Live Oracle.
    await tester.tap(find.byKey(ValueKey('camera-mode-${ReadingMode.liveOracle.name}')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('live-compact-oracle')), findsOneWidget);

    // Tap shutter -> scans 1 card, finishes 400ms lock-on, appends to live strip & shows Oracle caption.
    await tester.tap(find.byKey(const ValueKey('shutter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('live-cards-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-oracle-caption')), findsOneWidget);
  });
}
