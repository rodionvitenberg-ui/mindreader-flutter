import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';
import 'package:mindreader/core/theme/app_theme.dart';
import 'package:mindreader/features/astral/widgets/natal_wheel_geometry.dart';
import 'package:mindreader/features/astral/widgets/natal_wheel_painter.dart';
import 'package:mindreader/features/astral/widgets/natal_wheel_widget.dart';

/// ASTRAL Phase 3 — the living natal wheel: 4-stage choreography wiring,
/// tap-to-inspect, in-place house-system morphing and the transits overlay.

NatalChart _chart({HouseSystem house = HouseSystem.placidus}) =>
    NatalCalculatorService.calculateNatalChart(
      id: 'chart-wheel',
      profileName: 'Wheel',
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
      houseSystem: house,
      createdAt: DateTime.utc(2026, 11, 17),
    );

Widget _harness(NatalChart chart) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    backgroundColor: Colors.black,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 340,
          child: NatalWheelWidget(
            chart: chart,
            now: DateTime.utc(2026, 11, 17, 9, 41),
          ),
        ),
      ),
    ),
  ),
);

NatalWheelPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('natal-wheel-canvas')),
  );
  return paint.painter! as NatalWheelPainter;
}

double _ascendant(NatalChart chart) => chart.planets
    .firstWhere((position) => position.planet == PlanetId.ascendant)
    .longitude;

void main() {
  testWidgets('renders the wheel and completes the choreography cleanly', (
    tester,
  ) async {
    final chart = _chart();
    await tester.pumpWidget(_harness(chart));
    await tester.pump();

    expect(find.byKey(const ValueKey('natal-wheel-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('natal-wheel-replay')), findsOneWidget);
    expect(find.byKey(const ValueKey('natal-wheel-transits')), findsOneWidget);
    expect(find.byKey(const ValueKey('planet-inspector-card')), findsNothing);
    expect(find.byKey(const ValueKey('planet-chip-sun')), findsOneWidget);

    final painter = _painter(tester);
    expect(painter.ascendantLongitude, closeTo(_ascendant(chart), 1e-9));
    expect(painter.houseCusps.length, 12);
    expect(painter.transitLongitudes, isNull);

    // Runs all four stages through the real paint path.
    await tester.pump(const Duration(milliseconds: 2300));
    expect(tester.takeException(), isNull);
    expect(_painter(tester).choreography.value, 1.0);
  });
  testWidgets('tapping a planet chip opens and closes the inspector', (
    tester,
  ) async {
    final chart = _chart();
    await tester.pumpWidget(_harness(chart));
    await tester.pump(const Duration(milliseconds: 2400));

    final sunChip = find.byKey(const ValueKey('planet-chip-sun'));
    await tester.ensureVisible(sunChip);
    await tester.tap(sunChip);
    await tester.pump();

    final card = find.byKey(const ValueKey('planet-inspector-card'));
    expect(card, findsOneWidget);
    expect(find.textContaining('SUN · HOUSE'), findsOneWidget);

    final sun = chart.planets.firstWhere((p) => p.planet == PlanetId.sun);
    final aspectCount = chart.aspects
        .where((a) => a.bodyA == PlanetId.sun || a.bodyB == PlanetId.sun)
        .length;
    if (aspectCount > 0) {
      expect(find.text('ACTIVE ASPECTS · $aspectCount'), findsOneWidget);
    } else {
      expect(find.textContaining('NO MAJOR ASPECTS'), findsOneWidget);
    }
    expect(_painter(tester).selectedPlanet, PlanetId.sun);
    expect(sun.house, inInclusiveRange(1, 12));

    await tester.tap(sunChip);
    await tester.pump();

    expect(find.byKey(const ValueKey('planet-inspector-card')), findsNothing);
    expect(_painter(tester).selectedPlanet, isNull);
  });

  testWidgets('live transits overlay mounts and unmounts today\'s ring', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_chart()));
    await tester.pump(const Duration(milliseconds: 2400));

    final pill = find.byKey(const ValueKey('natal-wheel-transits'));
    await tester.ensureVisible(pill);
    await tester.tap(pill);
    await tester.pump(const Duration(milliseconds: 200));

    final transits = _painter(tester).transitLongitudes;
    expect(transits, isNotNull);
    expect(transits!.length, PlanetId.values.where((p) => p.isBody).length);
    for (final longitude in transits.values) {
      expect(longitude, inInclusiveRange(0.0, 360.0));
    }

    await tester.tap(pill);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_painter(tester).transitLongitudes, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('switching the house system morphs cusps without replaying', (
    tester,
  ) async {
    final placidus = _chart();
    await tester.pumpWidget(_harness(placidus));
    await tester.pump(const Duration(milliseconds: 2400));
    expect(_painter(tester).choreography.value, 1.0);

    final wholeSign = _chart(house: HouseSystem.wholeSign);
    await tester.pumpWidget(_harness(wholeSign));
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-morph the spokes sit between the two house systems.
    final mid = _painter(tester).houseCusps;
    expect(mid.length, 12);
    expect(mid, isNot(equals(placidus.houseCusps)));
    expect(mid, isNot(equals(wholeSign.houseCusps)));

    await tester.pump(const Duration(milliseconds: 500));
    final settled = _painter(tester).houseCusps;
    for (var i = 0; i < 12; i++) {
      final delta = shortestAngleDelta(
            settled[i] * math.pi / 180.0,
            wholeSign.houseCusps[i] * math.pi / 180.0,
          ) *
          180.0 /
          math.pi;
      expect(delta.abs(), lessThan(1e-6));
    }
    // The morph never restarts the 2200 ms choreography.
    expect(_painter(tester).choreography.value, 1.0);
    expect(tester.takeException(), isNull);
  });

  test('the ascendant is pinned to the 9 o\'clock horizon', () {
    for (final longitude in [0.0, 45.0, 180.0, 359.9]) {
      expect(chartScreenAngle(longitude, longitude), closeTo(math.pi, 1e-12));
    }
  });

  test('aspect flashes stay ordered inside the final choreography stage', () {
    for (final count in [1, 3, 12, 40]) {
      var previous = -1.0;
      for (var i = 0; i < count; i++) {
        final begin = aspectFlashBegin(i, count);
        expect(begin, greaterThanOrEqualTo(0.72));
        expect(begin, lessThan(1.0));
        expect(begin, greaterThan(previous));
        previous = begin;
      }
    }
    expect(aspectFlashBegin(0, 0), closeTo(0.72, 1e-12));
  });

  test('conjunct planets are nudged apart on the orbit track', () {
    final display = resolveCollisions([10.0, 10.0, 11.0]);
    expect(display.length, 3);
    for (var i = 1; i < display.length; i++) {
      expect(display[i] - display[i - 1], greaterThanOrEqualTo(6.9));
    }
  });
}
