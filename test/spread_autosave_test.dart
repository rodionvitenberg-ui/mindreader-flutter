import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/services/local_storage_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/spread_history_pane.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<({SpreadController spread, SessionHistoryController history})>
      mountWorkspace(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final spread = SpreadController();
    final history = SessionHistoryController()..load();
    final astral = AstralController();
    final settings = AppSettingsController();
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
    return (spread: spread, history: history);
  }

  testWidgets(
    'revealing the last base card auto-saves without AI, extra cards upsert the same entry, and restore lands on the Table',
    (tester) async {
      final (:spread, :history) = await mountWorkspace(tester);

      spread.activateSpread();
      // Deal 3 cards face down & flip only the first 2 — not yet saved.
      for (var i = 0; i < 3; i++) {
        spread.dealNextCard();
      }
      spread.flipSlot(0);
      spread.flipSlot(1);
      await tester.pump();
      expect(history.sessions, isEmpty);

      // Flip the last base card → automatic save WITHOUT initiating AI chat.
      spread.flipSlot(2);
      await tester.pump();
      expect(history.sessions, hasLength(1));
      final firstTimestamp = history.sessions.single.timestamp;
      expect(history.sessions.single.cards, hasLength(3));
      expect(history.sessions.single.synthesis, isNull);
      expect(history.sessions.single.messages, isEmpty);

      // Reading day is recorded automatically for the streak.
      final days = await LocalStorageService().loadReadingDays();
      expect(days, isNotEmpty);

      // Draw and reveal an extra 4th card → dynamically upserts the SAME entry.
      final extraIndex = spread.dealNextCardOrClarifier();
      expect(extraIndex, 3);
      spread.flipSlot(3);
      await tester.pump();
      expect(history.sessions, hasLength(1));
      expect(history.sessions.single.timestamp, firstTimestamp);
      expect(history.sessions.single.cards, hasLength(4));
      expect(history.sessions.single.cards[3].faceDown, isFalse);

      // Adding a card note also updates the same entry dynamically.
      spread.updateSlotUserContext(0, text: 'Career move in spring');
      await tester.pump();
      expect(history.sessions, hasLength(1));
      expect(
        history.sessions.single.cards[0].userContext,
        contains('Career move in spring'),
      );
      expect(history.sessions.single.notebook, 'career');

      // Reset table → starts a fresh reading revision; previous spread stays saved.
      final savedCardIds = [
        for (final c in history.sessions.single.cards) c.cardId,
      ];
      spread.resetTable();
      await tester.pump();
      expect(history.sessions, hasLength(1));
      expect(spread.dealtCount, 0);

      // Jump to History pane: tile shows card names and NO AI badge.
      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(historyPane);
      await tester.pumpAndSettle();
      expect(find.byType(SpreadHistoryPane), findsOneWidget);
      expect(find.byKey(const ValueKey('history-ai-badge')), findsNothing);
      expect(
        find.textContaining(cardNamesSummaryForSnapshot(history.sessions.single)),
        findsOneWidget,
      );

      // Tap saved spread without AI → restores all 4 cards AND lands on Table (Pane 0).
      await tester.tap(find.text('3 · THREE CARDS'));
      await tester.pumpAndSettle();
      expect(pageView.controller!.page!.round(), tablePane);
      expect(spread.slots, hasLength(4));
      expect(
        [for (final s in spread.slots) s.card!.id],
        savedCardIds,
      );
      expect(spread.slots.every((s) => s.state == SlotState.faceUp), isTrue);
    },
  );

  testWidgets(
    'Lenormand spreads auto-save with the Lenormand spread label',
    (tester) async {
      final (:spread, :history) = await mountWorkspace(tester);
      spread.setSystem(DivinationSystem.lenormand);
      spread.setLenormandSpread(LenormandSpread.one);
      spread.activateSpread();
      spread.dealNextCard();
      spread.flipSlot(0);
      await tester.pump();

      expect(history.sessions, hasLength(1));
      expect(history.sessions.single.system, DivinationSystem.lenormand);
      expect(
        spreadTitleForSnapshot(history.sessions.single),
        LenormandSpread.one.label,
      );
    },
  );
}
