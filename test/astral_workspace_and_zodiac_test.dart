import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/astral/astral_screen.dart';
import 'package:mindreader/features/astral/widgets/synastry_window.dart';
import 'package:mindreader/main.dart';

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
    testWidgets('renders the resonance score, four axes and the Oracle CTA', (
      tester,
    ) async {
      final a = _chart('Self', DateTime.utc(1988, 6, 15, 14, 30));
      final b = _chart('Partner', DateTime.utc(1990, 3, 20, 8, 15));
      Object? handoff;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SynastryWindow(a: a, b: b, onDiscuss: (h) => handoff = h),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Self × Partner'), findsOneWidget);
      expect(find.text('OVERALL RESONANCE'), findsNothing);
      await tester.tap(find.text('Compatibility details'));
      await tester.pumpAndSettle();
      expect(find.text('COMPATIBILITY AXES'), findsOneWidget);
      expect(find.text('EMOTIONAL BOND'), findsOneWidget);
      expect(find.text('ATTRACTION & SPARK'), findsOneWidget);
      expect(find.text('MENTAL & COMMUNICATION'), findsOneWidget);
      expect(find.text('GROWTH & FRICTION'), findsOneWidget);
      expect(find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'), findsOneWidget);
      expect(handoff, isNull);

      await tester.ensureVisible(find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'));
      await tester.pump();
      await tester.tap(find.text('✦ DISCUSS SYNASTRY WITH ORACLE →'));
      await tester.pump();
      expect(handoff, isNotNull);
    });
  });

  group('AstralScreen glass isolation & 3-window stability', () {
    testWidgets(
      'uses no nested Scaffold, isolates glass controls from PageView, and '
      'keeps all three windows populated across switches',
      (tester) async {
        await tester.pumpWidget(const MindreaderApp());
        await tester.pump();

        await tester.tap(find.text('ASTRAL'));
        await tester.pump();

        // No redundant nested Scaffold inside AstralScreen.
        expect(
          find.descendant(
            of: find.byType(AstralScreen),
            matching: find.byType(Scaffold),
          ),
          findsNothing,
        );

        // Every glass control inside AstralScreen belongs to a local isolated
        // TaroGlassLayer below AstralScreen (not the outer tab layer spanning
        // across PageView and its scrolling children).
        final outerAstralLayer = tester.element(
          find.ancestor(
            of: find.byType(AstralScreen),
            matching: find.byType(TaroGlassLayer),
          ).first,
        );
        final switcherLayer = tester.element(
          find.ancestor(
            of: find.byKey(const ValueKey('astral-window-natalChart')),
            matching: find.byType(TaroGlassLayer),
          ).first,
        );
        expect(switcherLayer, isNot(same(outerAstralLayer)));

        // Window 0 (Natal) visible.
        expect(find.byKey(const ValueKey('natal-wheel-placeholder')), findsOneWidget);

        // Jump directly 0 -> 2 (Synastry) without losing content.
        await tester.tap(find.byKey(const ValueKey('astral-window-synastry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('synastry-window')), findsOneWidget);

        // Switch 2 -> 1 (Horoscope) and verify content renders cleanly.
        await tester.tap(find.byKey(const ValueKey('astral-window-horoscope')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('horoscope-window')), findsOneWidget);

        // Return 1 -> 0 (Natal).
        await tester.tap(find.byKey(const ValueKey('astral-window-natalChart')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('natal-wheel-placeholder')), findsOneWidget);
      },
    );
  });
}
