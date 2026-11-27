import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_language.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/spread_check_in_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/spread_history_pane.dart';
import 'package:mindreader/features/digital_table/widgets/spread_check_in_sheet.dart';
import 'package:mindreader/features/rituals/daily_rituals_screen.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SpreadSessionSnapshot _makeSpread({
  required DateTime createdAt,
  int? checkInDays = 7,
  String? checkInDueAt,
  SpreadOutcome? outcome,
  String? reflectedAt,
  bool dismissed = false,
}) => SpreadSessionSnapshot(
  timestamp: createdAt.toIso8601String(),
  spreadType: SpreadType.three,
  notebook: 'all',
  cards: const [
    RestoredSpreadCard(cardId: 17, reversed: false, role: 'State'),
    RestoredSpreadCard(cardId: 9, reversed: false, role: 'Shadow'),
    RestoredSpreadCard(cardId: 1, reversed: false, role: 'Vector'),
  ],
  sessionNotes: const [],
  readingQuestion: 'Will the new project launch smoothly?',
  synthesis: null,
  chapters: const [],
  messages: const [],
  checkInDays: checkInDays,
  checkInDueAt: checkInDueAt,
  outcome: outcome,
  reflectedAt: reflectedAt,
  checkInDismissed: dismissed,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SpreadCheckInService', () {
    test('transitions upcoming -> due at 3/7/14 days and completed after reflection', () {
      final created = DateTime(2026, 11, 1, 10, 0);
      final spread7 = _makeSpread(createdAt: created, checkInDays: 7);

      expect(
        SpreadCheckInService.statusFor(
          spread7,
          now: created.add(const Duration(days: 6)),
        ),
        CheckInStatus.upcoming,
      );
      expect(
        SpreadCheckInService.statusFor(
          spread7,
          now: created.add(const Duration(days: 7)),
        ),
        CheckInStatus.due,
      );
      expect(
        SpreadCheckInService.promptFor(
          spread7,
          AppLanguage.ru,
          now: created.add(const Duration(days: 7)),
        ),
        contains('Прошла неделя'),
      );

      final spread3 = _makeSpread(createdAt: created, checkInDays: 3);
      expect(
        SpreadCheckInService.statusFor(
          spread3,
          now: created.add(const Duration(days: 3)),
        ),
        CheckInStatus.due,
      );
      expect(
        SpreadCheckInService.promptFor(
          spread3,
          AppLanguage.ru,
          now: created.add(const Duration(days: 3)),
        ),
        contains('3 дня'),
      );

      final reflected = spread7.copyWith(
        outcome: SpreadOutcome.unfolded,
        reflectionNote: 'Launched on time',
        reflectedAt: created.add(const Duration(days: 8)).toIso8601String(),
      );
      expect(
        SpreadCheckInService.statusFor(
          reflected,
          now: created.add(const Duration(days: 9)),
        ),
        CheckInStatus.completed,
      );
    });

    test('snapshot JSON round-trips check-in and reflection fields cleanly', () {
      final created = DateTime(2026, 11, 1, 10, 0);
      final original = _makeSpread(
        createdAt: created,
        checkInDays: 14,
        outcome: SpreadOutcome.partly,
        reflectedAt: DateTime(2026, 11, 16).toIso8601String(),
      ).copyWith(reflectionNote: 'Half happened as expected');

      final restored = SpreadSessionSnapshot.fromJson(original.toJson());
      expect(restored.checkInDays, 14);
      expect(restored.outcome, SpreadOutcome.partly);
      expect(restored.reflectionNote, 'Half happened as expected');
      expect(restored.reflectedAt, isNotNull);
    });
  });

  testWidgets(
    'due spread displays calm check-in badge in History and Rituals and closes loop via SpreadCheckInSheet',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final history = SessionHistoryController()..load();
      final oldSpread = _makeSpread(
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        checkInDays: 7,
      );
      await history.upsert(oldSpread);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: history),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: SpreadHistoryPane(
                history: history,
                onNewSpread: () {},
                onRestore: (_) {},
                onBackToTable: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badge = find.byKey(
        ValueKey('history-checkin-badge-${oldSpread.timestamp}'),
      );
      expect(badge, findsOneWidget);

      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(find.byType(SpreadCheckInSheet), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('checkin-outcome-unfolded')));
      await tester.enterText(
        find.byKey(const ValueKey('checkin-note-field')),
        'Everything aligned by Friday.',
      );
      await tester.tap(find.byKey(const ValueKey('checkin-save-button')));
      await tester.pumpAndSettle();

      expect(history.dueCheckIns(), isEmpty);
      expect(history.sessions.single.outcome, SpreadOutcome.unfolded);
      expect(
        history.sessions.single.reflectionNote,
        'Everything aligned by Friday.',
      );
      expect(
        find.byKey(ValueKey('history-reflected-badge-${oldSpread.timestamp}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'DailyRitualsScreen shows due check-ins section and lets user change cadence 3/7/14',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final history = SessionHistoryController()..load();
      final due = _makeSpread(
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
        checkInDays: 7,
      );
      await history.upsert(due);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider.value(value: history),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: const Scaffold(body: DailyRitualsScreen(isActive: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rituals-checkin-section')), findsOneWidget);
      expect(
        find.byKey(ValueKey('rituals-checkin-item-${due.timestamp}')),
        findsOneWidget,
      );

      final cadence14 = find.byKey(const ValueKey('checkin-cadence-14'));
      await tester.scrollUntilVisible(cadence14, 250);
      await tester.ensureVisible(cadence14);
      await tester.pumpAndSettle();
      await tester.tap(cadence14);
      await tester.pump();
      expect(history.defaultCheckInDays, 14);
    },
  );
}
