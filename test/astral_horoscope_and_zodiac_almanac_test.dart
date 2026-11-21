import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/zodiac_almanac_data.dart';
import 'package:mindreader/core/models/chat_message.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/models/oracle_handoff.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/local_storage_service.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/astral/widgets/horoscope_window.dart';
import 'package:mindreader/features/digital_table/spread_history_pane.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

/// Iteration 3 — the ASTRAL 2-window architecture, Astral session auto-save
/// into History and the Almanac's 4th ZODIAC tab.

NatalChart _chart(String name) => NatalCalculatorService.calculateNatalChart(
  id: 'chart-$name',
  profileName: name,
  birthDateUtc: DateTime.utc(1988, 6, 15, 14, 30),
  birthLocalYear: 1988,
  birthLocalMonth: 6,
  birthLocalDay: 15,
  birthLocalHour: 20,
  birthLocalMinute: 30,
  timeKnown: true,
  cityName: 'Bishkek',
  country: 'Kyrgyzstan',
  latitude: 42.87,
  longitude: 74.57,
  timezoneOffsetHours: 6,
  houseSystem: HouseSystem.placidus,
  createdAt: DateTime.utc(2026, 11, 17),
);

class _FakeHistoryStorage extends LocalStorageService {
  final List<Map<String, dynamic>> entries = [];

  @override
  Future<List<Map<String, dynamic>>> loadSessions() async => List.of(entries);

  @override
  Future<void> upsertSession(Map<String, dynamic> entry) async {
    entries.removeWhere((e) => e['timestamp'] == entry['timestamp']);
    entries.insert(0, entry);
  }

  @override
  Future<void> deleteAllSessions() async => entries.clear();
}

/// Swipes horizontally until [pane] is active (800 px test viewport) — the
/// bounded, diagnosable helper lives in `helpers/table_test_helpers.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Astral session snapshots', () {
    test('an astral dialogue round-trips through JSON', () {
      final snapshot = SpreadSessionSnapshot.astral(
        timestamp: '2026-11-17T14:32:00.000Z',
        kind: SessionKind.natalChartReading,
        title: 'Self · Natal',
        natalChartId: 'chart-Self',
        messages: const [
          ChatMessage(role: 'user', text: 'Natal profile: Self'),
          ChatMessage(role: 'oracle', text: 'Reading the chart of Self.'),
        ],
      );

      final back = SpreadSessionSnapshot.fromJson(snapshot.toJson());
      expect(back.kind, SessionKind.natalChartReading);
      expect(back.astralSessionTitle, 'Self · Natal');
      expect(back.natalChartId, 'chart-Self');
      expect(back.messages.length, 2);
      expect(back.messages.last.text, 'Reading the chart of Self.');
      expect(back.cards, isEmpty);
    });

    test('legacy JSON without a kind stays a divination spread', () {
      final back = SpreadSessionSnapshot.fromJson({
        'timestamp': '2026-11-17T14:32:00.000Z',
        'spreadType': 'three',
        'notebook': 'All Readings',
        'cards': const [],
        'sessionNotes': const [],
        'chapters': const [],
        'messages': const [],
      });
      expect(back.kind, SessionKind.divinationSpread);
      expect(back.astralSessionTitle, isNull);
    });
  });

  group('Zodiac quick forecast', () {
    test('is deterministic, complete and 3-sphered', () {
      final date = DateTime.utc(2026, 11, 17);
      final a = NatalCalculatorService.computeZodiacSignForecast(
        ZodiacSign.libra,
        forDate: date,
      );
      final b = NatalCalculatorService.computeZodiacSignForecast(
        ZodiacSign.libra,
        forDate: date,
      );
      expect(a.sign, ZodiacSign.libra);
      expect(a.energyScore, inInclusiveRange(1, 100));
      expect(a.energyScore, b.energyScore);
      expect(a.solarMoonHouse, inInclusiveRange(1, 12));
      expect(a.solarSunHouse, inInclusiveRange(1, 12));
      expect(a.focusSpheres.length, 3);
      expect(a.focusSpheres.map((f) => f.title), [
        'Relationships & Feelings',
        'Career & Decisions',
        'Inner State',
      ]);
      expect(a.overallTheme, contains('Libra'));
      expect(b.overallTheme, a.overallTheme);
    });

    test(
      'the zodiac almanac covers 12 signs, 3 per element, 4 per modality',
      () {
        expect(zodiacAlmanac.length, 12);
        for (final e in Element.values) {
          expect(zodiacEntriesForElement(e).length, 3);
        }
        for (final m in ZodiacModality.values) {
          expect(zodiacEntriesForModality(m).length, 4);
        }
        for (final entry in zodiacAlmanac) {
          expect(entry.dateRange, isNotEmpty);
          expect(entry.keywords.length, 3);
          expect(entry.archetype, isNotEmpty);
          expect(entry.shadow, isNotEmpty);
          expect(entry.loveStyle, isNotEmpty);
          expect(entry.careerVector, isNotEmpty);
          expect(entry.houseAffinity, inInclusiveRange(1, 12));
        }
      },
    );
  });

  group('ASTRAL 3-window workspace', () {
    testWidgets('switches NATAL CHART ⇄ HOROSCOPE ⇄ SYNASTRY', (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await tester.tap(find.text('ASTRAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Window 0 is the natal chart (no profile → the wheel placeholder).
      expect(
        find.byKey(const ValueKey('astral-window-natalChart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('astral-window-horoscope')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('astral-window-synastry')),
        findsOneWidget,
      );
      expect(find.byType(HoroscopeWindow), findsNothing);

      await tester.tap(find.byKey(const ValueKey('astral-window-horoscope')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HoroscopeWindow), findsOneWidget);
      // No natal profile yet → the quick-sign forecast is shown.
      expect(
        find.byKey(const ValueKey('zodiac-forecast-card')),
        findsOneWidget,
      );
      expect(find.text('✦ DISCUSS HOROSCOPE WITH ORACLE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('astral-window-synastry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('synastry-window')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('astral-window-natalChart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HoroscopeWindow), findsNothing);
    });
  });

  group('Astral history', () {
    testWidgets('shows the cosmic badge and restores the conversation', (
      tester,
    ) async {
      final history = SessionHistoryController(storage: _FakeHistoryStorage());
      await history.load();
      await history.upsert(
        SpreadSessionSnapshot.astral(
          timestamp: '2026-11-17T14:32:00.000Z',
          kind: SessionKind.horoscopeReading,
          title: 'Self · Horoscope',
          messages: const [
            ChatMessage(role: 'user', text: 'Daily horoscope for Self'),
            ChatMessage(role: 'oracle', text: 'A flowing day.'),
          ],
        ),
      );
      SpreadSessionSnapshot? restored;

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSettingsController(),
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: SpreadHistoryPane(
                history: history,
                onNewSpread: () {},
                onBackToTable: () {},
                onRestore: (s) => restored = s,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('✦ HOROSCOPE'), findsOneWidget);
      expect(find.text('SELF · HOROSCOPE'), findsOneWidget);
      expect(find.text('A flowing day.'), findsOneWidget);

      await tester.tap(find.text('SELF · HOROSCOPE'));
      await tester.pump();

      expect(restored, isNotNull);
      expect(restored!.kind, SessionKind.horoscopeReading);
      expect(restored!.messages.length, 2);
    });
  });

  group('Astral auto-save', () {
    testWidgets('saves a natal handoff to History and restores it into chat', (
      tester,
    ) async {
      final chart = _chart('Self');
      final report = NatalCalculatorService.computeDailyHoroscope(
        chart,
        forDate: DateTime.utc(2026, 11, 17),
      );
      final handoff = ValueNotifier<OracleHandoff?>(null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SpreadController()),
            ChangeNotifierProvider(create: (_) => OracleSessionController()),
            ChangeNotifierProvider(create: (_) => OracleVoiceService()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider(create: (_) => AstralController()),
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(
              create: (_) => SessionHistoryController()..load(),
            ),
            ChangeNotifierProvider(create: (_) => UserProfileController()),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(body: TableWorkspace(astralHandoff: handoff)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      handoff.value = OracleHandoff(
        prompt: OracleSynthesisService.buildNatalPrompt(chart, report),
        kind: OracleHandoffKind.natalChart,
        chart: chart,
        horoscope: report,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      // The handoff lands on Pane 1 (chat) and is auto-saved into History.
      await goToPane(tester, 2);
      expect(find.text('☉ NATAL'), findsOneWidget);
      expect(find.text('SELF · NATAL'), findsOneWidget);

      await tester.tap(find.text('SELF · NATAL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Natal profile: Self'), findsOneWidget);
      handoff.dispose();
    });
  });

  group('Almanac ZODIAC tab', () {
    testWidgets('4th tab filters by element + modality and opens the sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await tester.tap(find.text('ALMANAC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('almanac-system-zodiac')));
      await tester.pump();

      expect(find.text('ZODIAC'), findsOneWidget);
      expect(find.text('ARIES'), findsOneWidget);
      expect(find.text('PISCES'), findsOneWidget);
      expect(find.text('All (12)'), findsOneWidget);

      // Element: WATER → the three water signs remain.
      await tester.tap(find.byKey(const ValueKey('element-filter-water')));
      await tester.pump();
      expect(find.text('CANCER'), findsOneWidget);
      expect(find.text('SCORPIO'), findsOneWidget);
      expect(find.text('PISCES'), findsOneWidget);
      expect(find.text('ARIES'), findsNothing);

      // Modality: FIXED → Scorpio only.
      await tester.tap(find.byKey(const ValueKey('zodiac-modality-fixed')));
      await tester.pump();
      expect(find.text('SCORPIO'), findsOneWidget);
      expect(find.text('CANCER'), findsNothing);

      // Open the rich detail sheet.
      await tester.tap(find.byKey(const ValueKey('zodiac-tile-scorpio')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('zodiac-detail-sheet')), findsOneWidget);
      expect(find.text('CORE ARCHETYPE'), findsOneWidget);

      // Jump to the sign's Horoscope in ASTRAL.
      await tester.ensureVisible(
        find.byKey(const ValueKey('zodiac-open-horoscope')),
      );
      await tester.tap(find.byKey(const ValueKey('zodiac-open-horoscope')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HoroscopeWindow), findsOneWidget);
      expect(find.text('SCORPIO'), findsWidgets);
    });
  });
}
