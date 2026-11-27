import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/l10n/app_language.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/services/share_card_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/features/share/share_card_canvas.dart';
import 'package:mindreader/features/share/share_card_payload.dart';
import 'package:mindreader/features/share/share_card_preview_sheet.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeShareAdapter implements ShareAdapter {
  Uint8List? lastBytes;
  String? lastFilename;
  String? lastText;

  @override
  Future<void> sharePngBytes(
    Uint8List bytes, {
    required String filename,
    String? text,
  }) async {
    lastBytes = bytes;
    lastFilename = filename;
    lastText = text;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Table footer has 3 buttons [Share | Analyze (SeerEyeIcon) | Reset] and Share opens 9:16 editorial preview',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final spread = SpreadController();
      final history = SessionHistoryController()..load();
      final astral = AstralController();
      final settings = AppSettingsController();
      spread.activateSpread();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: spread),
            ChangeNotifierProvider(create: (_) => OracleSessionController()),
            ChangeNotifierProvider(create: (_) => OracleVoiceService()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: astral),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(
              create: (_) =>
                  GuidedReadingController(spread: spread, settings: settings),
            ),
            ChangeNotifierProvider.value(value: history),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProfileController(history: history, astral: astral),
            ),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: const Scaffold(body: TableWorkspace()),
          ),
        ),
      );
      await tester.pump();

      final shareBtn = find.byKey(const ValueKey('share-spread-button'));
      final analyzeBtn = find.byKey(const ValueKey('analyze-reading-button'));
      final resetBtn = find.byKey(const ValueKey('reset-table-button'));

      expect(shareBtn, findsOneWidget);
      expect(analyzeBtn, findsOneWidget);
      expect(resetBtn, findsOneWidget);

      // Horizontal order: Share (left) < Analyze (center) < Reset (right).
      expect(
        tester.getCenter(shareBtn).dx,
        lessThan(tester.getCenter(analyzeBtn).dx),
      );
      expect(
        tester.getCenter(analyzeBtn).dx,
        lessThan(tester.getCenter(resetBtn).dx),
      );

      // Deal & reveal all 3 cards so Share becomes active.
      for (var i = 0; i < 3; i++) {
        spread.dealNextCard();
        spread.flipSlot(i);
      }
      await tester.pump();

      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ShareCardPreviewSheet), findsOneWidget);
      expect(find.byType(ShareCardCanvas), findsOneWidget);
      expect(find.text('TAROT TREE  ·  SOSHALLITBE.CYOU'), findsOneWidget);

      // Switch atmosphere and cycle phrases.
      await tester.tap(find.byKey(const ValueKey('share-bg-oak')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('share-cycle-phrase')));
      await tester.pump();
    },
  );

  testWidgets(
    'ShareCardPreviewSheet renders 9:16 Daily Card and exports PNG bytes via ShareAdapter',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final fakeAdapter = _FakeShareAdapter();
      final payload = ShareCardPayload.fromDailyCard(
        card: tarotDeck[17], // XVII The Star
        isReversed: false,
        lang: AppLanguage.en,
        now: DateTime(2026, 11, 24),
      );
      expect(payload.phraseOptions.length, greaterThanOrEqualTo(2));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: ShareCardPreviewSheet(
                payload: payload,
                adapter: fakeAdapter,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShareCardCanvas), findsOneWidget);
      expect(find.text(tarotDeck[17].name), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('share-confirm-button')));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && fakeAdapter.lastBytes == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();

      expect(fakeAdapter.lastBytes, isNotNull);
      expect(fakeAdapter.lastBytes!.length, greaterThan(100));
      expect(fakeAdapter.lastFilename, 'tarot_tree_story.png');
    },
  );
}
