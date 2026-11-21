import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/astro_cities_data.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/models/oracle_handoff.dart';
import 'package:mindreader/core/services/birth_time_service.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/transit_forecast_service.dart';
import 'package:mindreader/features/astral/astral_screen.dart';
import 'package:mindreader/features/astral/widgets/daily_horoscope_card.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

AstroCity _city(String name) =>
    astroCities.firstWhere((city) => city.name == name);

NatalChart _chart(String name, {bool timeKnown = true}) =>
    NatalCalculatorService.calculateNatalChart(
      id: name.toLowerCase(),
      profileName: name,
      birthDateUtc: DateTime.utc(1988, 6, 15, 14, 30),
      birthLocalYear: 1988,
      birthLocalMonth: 6,
      birthLocalDay: 15,
      birthLocalHour: 20,
      birthLocalMinute: 30,
      timeKnown: timeKnown,
      cityName: 'Bishkek',
      country: 'Kyrgyzstan',
      latitude: 42.8746,
      longitude: 74.5698,
      timezoneOffsetHours: 6,
      houseSystem: HouseSystem.placidus,
    );

void main() {
  test(
    'catalogue zones resolve historical, daylight and repeated birth times',
    () {
      for (final city in astroCities) {
        expect(
          BirthTimeService.resolve(city, DateTime(2024, 1, 15, 12)),
          hasLength(1),
          reason: city.name,
        );
      }
      expect(searchAstroCities('биш').first.name, 'Bishkek');
      expect(
        BirthTimeService.resolve(
          _city('Bishkek'),
          DateTime(1988, 6, 15, 20, 30),
        ).single.utc,
        DateTime.utc(1988, 6, 15, 13, 30),
      );
      expect(
        BirthTimeService.resolve(
          _city('London'),
          DateTime(2024, 7, 1, 12),
        ).single.utc,
        DateTime.utc(2024, 7, 1, 11),
      );
      final ny = _city('New York');
      expect(
        BirthTimeService.resolve(ny, DateTime(2024, 3, 10, 2, 30)),
        isEmpty,
      );
      expect(
        BirthTimeService.resolve(
          ny,
          DateTime(2024, 11, 3, 1, 30),
        ).map((i) => i.utc),
        [DateTime.utc(2024, 11, 3, 5, 30), DateTime.utc(2024, 11, 3, 6, 30)],
      );
    },
  );

  test(
    'unknown and legacy unknown charts omit houses, angles and lunar aspects',
    () {
      final saved = _chart('Older Card').toJson()
        ..['timeKnown'] = false
        ..remove('moonSignUncertain');
      for (final chart in [
        _chart('No time', timeKnown: false),
        NatalChart.fromJson(saved),
      ]) {
        expect(chart.houseCusps, isEmpty);
        expect(
          chart.planets.every((p) => p.planet.isBody && p.house == null),
          isTrue,
        );
        expect(
          chart.aspects.any(
            (a) => a.bodyA == PlanetId.moon || a.bodyB == PlanetId.moon,
          ),
          isFalse,
        );
        final report = NatalCalculatorService.computeDailyHoroscope(chart);
        expect(report.transitingMoonHouse, isNull);
        expect(
          OracleSynthesisService.buildNatalPrompt(chart, report),
          isNot(contains('Ascendant')),
        );
      }
    },
  );

  test(
    'a selected day finds exact aspects and stores the original Oracle context',
    () {
      final chart = _chart('Private Name');
      final localBirth = chart.birthDateUtc.toLocal();
      final chosenDay = DateTime(
        localBirth.year,
        localBirth.month,
        localBirth.day,
      );
      final report = TransitForecastService.forDay(chart, chosenDay);
      final transit = report.transits.firstWhere((t) => t.reachesExact);
      expect(
        transit.closestAt!.difference(chart.birthDateUtc).inSeconds.abs(),
        lessThan(2),
      );
      final bounded = report.transits.firstWhere(
        (t) => t.activeFrom != null && t.activeUntil != null,
      );
      expect(bounded.activeFrom!.isBefore(bounded.closestAt!), isTrue);
      expect(bounded.activeUntil!.isAfter(bounded.closestAt!), isTrue);

      final handoff = OracleHandoff(
        prompt: 'Private Name entered this reading',
        kind: OracleHandoffKind.horoscope,
        chart: chart,
        horoscope: report,
        transit: transit,
      );
      final snapshot = SpreadSessionSnapshot.astral(
        timestamp: DateTime(2026).toIso8601String(),
        kind: SessionKind.horoscopeReading,
        title: chart.profileName,
        astralContext: handoff,
        messages: const [],
      );
      final restored = SpreadSessionSnapshot.fromJson(snapshot.toJson())
          .astralContext!;
      expect(restored.horoscope!.date, report.date);
      expect(restored.transit!.toJson(), transit.toJson());
      final sent = OracleSynthesisService.astralOracleContext(restored);
      expect(sent, contains(transit.transitLabel));
      expect(sent, isNot(contains(chart.profileName)));
      expect(sent, isNot(contains(chart.cityName)));
    },
  );

  test('a synastry session retains both original charts and a zodiac session retains its forecast', () {
    final a = _chart('Alex');
    final b = _chart('Blair');
    final pair = OracleHandoff.fromJson(
      OracleHandoff(
        prompt: 'A × B',
        kind: OracleHandoffKind.synastry,
        chart: a,
        otherChart: b,
      ).toJson(),
    );
    expect(pair.chart?.id, a.id);
    expect(pair.otherChart?.id, b.id);
    expect(
      OracleSynthesisService.astralOracleContext(pair),
      contains('Profile A × Profile B'),
    );

    final forecast = NatalCalculatorService.computeZodiacSignForecast(
      ZodiacSign.libra,
      forDate: DateTime.utc(2026, 11, 15),
    );
    final zodiac = OracleHandoff.fromJson(
      OracleHandoff(
        prompt: 'Libra',
        kind: OracleHandoffKind.zodiac,
        zodiacSign: forecast.sign,
        zodiacForecast: forecast,
      ).toJson(),
    );
    expect(zodiac.zodiacSign, ZodiacSign.libra);
    expect(zodiac.zodiacForecast?.date, forecast.date);
  });

  Future<AstralController> openAstral(
    WidgetTester tester, {
    ValueChanged<OracleHandoff>? onOpenOracle,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = AstralController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => controller),
          ChangeNotifierProvider(create: (_) => AppSettingsController()),
        ],
        child: MaterialApp(home: AstralScreen(onOpenOracle: onOpenOracle)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return controller;
  }

  testWidgets(
    'editing a legacy chart fixes UTC and persists the same profile ID',
    (tester) async {
      final controller = await openAstral(tester);
      final original = _chart('Legacy');
      controller.generateChart(original);
      await tester.pump();

      final details = find.text('OPEN FULL PROFILE');
      await tester.ensureVisible(details);
      await tester.pump();
      await tester.tap(details);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('astral-edit-birth-data')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final save = find.text('Save changes');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.profiles, hasLength(1));
      expect(controller.activeProfile!.id, original.id);
      expect(controller.activeProfile!.timezoneId, 'Asia/Bishkek');
      expect(
        controller.activeProfile!.birthDateUtc,
        DateTime.utc(1988, 6, 15, 13, 30),
      );
    },
  );

  testWidgets(
    'a future day updates the report and synastry can select any second profile',
    (tester) async {
      OracleHandoff? selected;
      final controller = await openAstral(
        tester,
        onOpenOracle: (value) => selected = value,
      );
      for (final name in ['Alex', 'Blair', 'Chris']) {
        controller.generateChart(_chart(name));
      }
      await tester.pump();
      final horoscope = find.byKey(const ValueKey('astral-window-horoscope'));
      await tester.tap(horoscope);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final card = find.byType(DailyHoroscopeCard);
      final today = tester
          .widget<DailyHoroscopeCard>(card)
          .report
          .date
          .toLocal();
      await tester.tap(find.byKey(const ValueKey('astral-show-week')));
      await tester.pump();
      final day = find.byKey(const ValueKey('astral-day-2'));
      await tester.ensureVisible(day);
      await tester.pump();
      await tester.tap(day);
      await tester.pump();
      final later = tester
          .widget<DailyHoroscopeCard>(card)
          .report
          .date
          .toLocal();
      expect(later, DateTime(today.year, today.month, today.day + 2, 12));

      final discuss = find.text('Discuss this transit').first;
      await tester.ensureVisible(discuss);
      await tester.pump();
      await tester.tap(discuss);
      await tester.pump();
      expect(selected?.horoscope?.date.toLocal(), later);
      expect(selected?.transit, isNotNull);

      await tester.tap(find.byKey(const ValueKey('astral-window-synastry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('synastry-second-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blair').last);
      await tester.pumpAndSettle();
      expect(find.text('Chris × Blair'), findsOneWidget);
      expect(find.text('OVERALL RESONANCE'), findsNothing);
    },
  );
}
