import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/theme/app_theme.dart';
import 'package:mindreader/features/astral/widgets/synastry_window.dart';

/// STEP 2 — the 3-window Astral workspace engine: 2-profile synastry
/// (resonance score + 4 axes), the 7-day power/tension forecast and the
/// synastry window rendering.

NatalChart _chart(String name, DateTime birthUtc) =>
    NatalCalculatorService.calculateNatalChart(
      id: 'chart-$name',
      profileName: name,
      birthDateUtc: birthUtc,
      birthLocalYear: birthUtc.year,
      birthLocalMonth: birthUtc.month,
      birthLocalDay: birthUtc.day,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeSynastry', () {
    final a = _chart('Self', DateTime.utc(1988, 6, 15, 14, 30));
    final b = _chart('Partner', DateTime.utc(1990, 3, 20, 8, 15));

    test('returns four axes and a 0..100 overall resonance score', () {
      final report = NatalCalculatorService.computeSynastry(a, b);
      expect(report.axes.length, 4);
      expect(report.axes.map((x) => x.title), [
        'Emotional Bond',
        'Attraction & Spark',
        'Mental & Communication',
        'Growth & Friction',
      ]);
      for (final axis in report.axes) {
        expect(axis.score, inInclusiveRange(0, 100));
        expect(axis.text, isNotEmpty);
      }
      expect(report.overallScore, inInclusiveRange(0, 100));
    });

    test('is deterministic for the same two charts', () {
      final one = NatalCalculatorService.computeSynastry(a, b);
      final two = NatalCalculatorService.computeSynastry(a, b);
      expect(one.overallScore, two.overallScore);
      expect(
        one.axes.map((x) => x.score).toList(),
        two.axes.map((x) => x.score).toList(),
      );
    });

    test('round-trips through JSON', () {
      final report = NatalCalculatorService.computeSynastry(a, b);
      final back = SynastryReport.fromJson(report.toJson());
      expect(back.overallScore, report.overallScore);
      expect(back.axes.length, 4);
      expect(back.axes.first.title, 'Emotional Bond');
      expect(back.axes.first.score, report.axes.first.score);
    });
  });

  group('computeSevenDayForecast', () {
    final chart = _chart('Self', DateTime.utc(1988, 6, 15, 14, 30));

    test('returns exactly seven deterministic daily peaks', () {
      final from = DateTime.utc(2026, 11, 17);
      final peaks = NatalCalculatorService.computeSevenDayForecast(
        chart,
        fromDate: from,
      );
      expect(peaks.length, 7);
      for (var i = 0; i < 7; i++) {
        expect(peaks[i].date, from.add(Duration(days: i)));
      }

      final again = NatalCalculatorService.computeSevenDayForecast(
        chart,
        fromDate: from,
      );
      expect(
        peaks.map((p) => p.transit?.title).toList(),
        again.map((p) => p.transit?.title).toList(),
      );
    });

    test('round-trips each peak through JSON', () {
      final peaks = NatalCalculatorService.computeSevenDayForecast(
        chart,
        fromDate: DateTime.utc(2026, 11, 17),
      );
      final back = peaks
          .map((p) => DailyTransitPeak.fromJson(p.toJson()))
          .toList();
      expect(back.length, 7);
      expect(back.first.date, peaks.first.date);
      expect(back.first.transit?.title, peaks.first.transit?.title);
    });
  });

  group('SynastryWindow', () {
    testWidgets('renders the resonance score, four axes and the Oracle CTA',
        (tester) async {
      final a = _chart('Self', DateTime.utc(1988, 6, 15, 14, 30));
      final b = _chart('Partner', DateTime.utc(1990, 3, 20, 8, 15));
      Object? handoff;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SynastryWindow(
                a: a,
                b: b,
                onDiscuss: (h) => handoff = h,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SYNASTRY · 2 PROFILES'), findsOneWidget);
      expect(find.text('COMPATIBILITY AXES'), findsOneWidget);
      expect(find.text('EMOTIONAL BOND'), findsOneWidget);
      expect(find.text('ATTRACTION & SPARK'), findsOneWidget);
      expect(find.text('MENTAL & COMMUNICATION'), findsOneWidget);
      expect(find.text('GROWTH & FRICTION'), findsOneWidget);
      expect(find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'), findsOneWidget);
      expect(handoff, isNull);

      await tester.ensureVisible(
        find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'),
      );
      await tester.pump();
      await tester.tap(find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'));
      await tester.pump();
      expect(handoff, isNotNull);
    });
  });
}
