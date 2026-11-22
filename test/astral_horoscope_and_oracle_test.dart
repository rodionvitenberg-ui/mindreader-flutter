import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/models/oracle_handoff.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/astral/natal_profile_detail_sheet.dart';
import 'package:mindreader/features/astral/synastry_summary_sheet.dart';
import 'package:mindreader/features/astral/widgets/daily_horoscope_card.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';

/// ASTRAL Phase 4 — the daily horoscope card, the full natal profile sheet,
/// 2-profile synastry and the cross-tab Oracle Chat handoff.

NatalChart _chart(String name, {DateTime? birthUtc, DateTime? birthLocal}) {
  final utc = birthUtc ?? DateTime.utc(1988, 6, 15, 14, 30);
  final local = birthLocal ?? DateTime.utc(1988, 6, 15, 20, 30);
  return NatalCalculatorService.calculateNatalChart(
    id: 'chart-$name',
    profileName: name,
    birthDateUtc: utc,
    birthLocalYear: local.year,
    birthLocalMonth: local.month,
    birthLocalDay: local.day,
    birthLocalHour: local.hour,
    birthLocalMinute: local.minute,
    timeKnown: true,
    cityName: name == 'Partner' ? 'Astana' : 'Bishkek',
    country: 'Kazakhstan',
    latitude: 42.87,
    longitude: 74.57,
    timezoneOffsetHours: 6,
    houseSystem: HouseSystem.placidus,
    createdAt: DateTime.utc(2026, 11, 17),
  );
}

NatalChart _selfChart() => _chart('Self');

NatalChart _partnerChart() => _chart(
  'Partner',
  birthUtc: DateTime.utc(1991, 3, 21, 8, 5),
  birthLocal: DateTime.utc(1991, 3, 21, 14, 5),
);

DailyHoroscopeReport _report(NatalChart chart) =>
    NatalCalculatorService.computeDailyHoroscope(
      chart,
      forDate: DateTime.utc(2026, 11, 17),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Synastry + horoscope engine', () {
    test('cross-chart aspects pair A points with B points, tightest first', () {
      final a = _selfChart();
      final b = _partnerChart();
      final aspects = NatalCalculatorService.computeSynastryAspects(a, b);
      expect(aspects, isNotEmpty);

      final aPlanets = a.planets.map((p) => p.planet).toSet();
      final bPlanets = b.planets.map((p) => p.planet).toSet();
      for (final aspect in aspects) {
        expect(aPlanets.contains(aspect.bodyA), isTrue);
        expect(bPlanets.contains(aspect.bodyB), isTrue);
      }
      for (var i = 1; i < aspects.length; i++) {
        expect(aspects[i].orb, greaterThanOrEqualTo(aspects[i - 1].orb));
      }
    });

    test('synastry elemental balance counts both ten-body charts', () {
      final balance = NatalCalculatorService.synastryElementBalance(
        _selfChart(),
        _partnerChart(),
      );
      final total = balance.values.fold<int>(0, (sum, v) => sum + v);
      expect(total, 20);
      expect(balance.length, 4);
    });

    test('house themes cover 1..12 and clamp out-of-range values', () {
      for (var house = 1; house <= 12; house++) {
        expect(NatalCalculatorService.houseTheme(house), isNotEmpty);
      }
      expect(
        NatalCalculatorService.houseTheme(0),
        NatalCalculatorService.houseTheme(1),
      );
      expect(
        NatalCalculatorService.houseTheme(99),
        NatalCalculatorService.houseTheme(12),
      );
    });

    test('DailyTransitItem JSON round-trip preserves the harmony register', () {
      const item = DailyTransitItem(
        title: 'Mars stirs your Moon',
        transitLabel: 'Transit Mars square Natal Moon',
        orb: 1.25,
        advice: 'Name the friction.',
        harmony: AspectHarmony.tense,
      );
      final back = DailyTransitItem.fromJson(item.toJson());
      expect(back.harmony, AspectHarmony.tense);
      expect(back.orb, 1.25);
      expect(back.transitLabel, item.transitLabel);
    });

    test('daily horoscope transits carry their aspect harmony', () {
      final report = _report(_selfChart());
      for (final transit in report.transits) {
        expect(transit.harmony, isA<AspectHarmony>());
      }
    });
  });

  group('Oracle natal handoff prompts', () {
    final chart = _selfChart();
    final report = _report(chart);
    final partner = _partnerChart();

    test('buildNatalPrompt summarizes the big three and today sky', () {
      final prompt = OracleSynthesisService.buildNatalPrompt(chart, report);
      expect(prompt, contains('Natal profile: Self'));
      expect(prompt, contains('Big Three:'));
      expect(prompt, contains('Dominant element:'));
      expect(prompt, contains('Moon in house'));
    });

    test('buildSynastryPrompt names both profiles and cross aspects', () {
      final prompt = OracleSynthesisService.buildSynastryPrompt(chart, partner);
      expect(prompt, contains('Synastry: Self'));
      expect(prompt, contains('Partner'));
      expect(prompt, contains('Tightest cross-chart aspects:'));
    });

    test('offline natal reading falls back to the chart synthesis', () async {
      final text = await OracleSynthesisService().synthesizeNatalReading(
        prompt: OracleSynthesisService.buildNatalPrompt(chart, report),
        chart: chart,
        horoscope: report,
        history: const [],
      );
      expect(text, contains('Reading the chart of Self'));
      expect(text, contains('Ascendant'));
    });

    test('offline synastry reading mentions both profiles', () async {
      final text = await OracleSynthesisService().synthesizeNatalReading(
        prompt: OracleSynthesisService.buildSynastryPrompt(chart, partner),
        chart: chart,
        otherChart: partner,
        history: const [],
      );
      expect(text.toLowerCase(), contains('comparing your charts'));
      expect(text, contains('Self'));
      expect(text, contains('Partner'));
    });
  });

  group('DailyHoroscopeCard', () {
    testWidgets('renders the cosmic weather, moon house and transit cards', (
      tester,
    ) async {
      final report = _report(_selfChart());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: DailyHoroscopeCard(report: report),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('daily-horoscope-card')),
        findsOneWidget,
      );
      expect(find.textContaining('MOON IN HOUSE'), findsOneWidget);
      expect(find.text('LIVE TRANSITS'), findsOneWidget);
      if (report.transits.isNotEmpty) {
        expect(
          find.byKey(ValueKey('transit-${report.transits.first.transitLabel}')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('NatalProfileDetailSheet', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      NatalChart chart, {
      ValueChanged<HouseSystem>? onHouse,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: NatalProfileDetailSheet(
              chart: chart,
              onHouseSystemChanged: onHouse,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    final charts = <String, NatalChart>{
      'Self': _selfChart(),
      'Partner': _partnerChart(),
    };

    for (final entry in charts.entries) {
      testWidgets(
        'shows the full ledger and live house switch for ${entry.key}',
        (tester) async {
          HouseSystem? switched;
          await pumpDetail(tester, entry.value, onHouse: (s) => switched = s);

          expect(find.text('BIG THREE'), findsOneWidget);
          expect(find.text('FULL PLACEMENTS'), findsOneWidget);
          expect(find.text('ASPECT MATRIX'), findsOneWidget);
          expect(find.text('Sun'), findsOneWidget);
          expect(find.text('Ascendant'), findsOneWidget);

          await tester.ensureVisible(find.text('KOCH'));
          await tester.tap(find.text('KOCH'));
          await tester.pump();

          expect(switched, HouseSystem.koch);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('SynastrySummarySheet', () {
    testWidgets('renders both charts and hands a synastry to the Oracle', (
      tester,
    ) async {
      final a = _selfChart();
      final b = _partnerChart();
      OracleHandoff? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SynastrySummarySheet(
              a: a,
              b: b,
              onSendToOracle: (handoff) => captured = handoff,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SYNASTRY · 2 PROFILES'), findsOneWidget);
      expect(find.text('Self × Partner'), findsOneWidget);
      expect(find.text('ELEMENTAL BALANCE'), findsOneWidget);
      expect(find.text('CROSS-CHART ASPECTS'), findsOneWidget);
      expect(find.textContaining('WATER'), findsOneWidget);

      final cta = find.text('✦ DISCUSS THIS SYNASTRY WITH THE ORACLE');
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.isSynastry, isTrue);
      expect(captured!.prompt, contains('Self'));
      expect(captured!.prompt, contains('Partner'));
      expect(tester.takeException(), isNull);
    });
  });

  group('ASTRAL to Oracle handoff', () {
    testWidgets('streams the natal reading into the Oracle Chat pane', (
      tester,
    ) async {
      final chart = _selfChart();
      final report = _report(chart);
      final handoff = ValueNotifier<OracleHandoff?>(null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SpreadController()),
            ChangeNotifierProvider(create: (_) => OracleSessionController()),
            ChangeNotifierProvider(create: (_) => OracleVoiceService()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider(
              create: (_) => SessionHistoryController()..load(),
            ),
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(
              create: (context) => GuidedReadingController(
                spread: context.read<SpreadController>(),
                settings: context.read<AppSettingsController>(),
              ),
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
        chart: chart,
        horoscope: report,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Natal profile: Self'), findsOneWidget);
      expect(find.textContaining('Reading the chart of Self'), findsOneWidget);
      handoff.dispose();
    });
  });
}
