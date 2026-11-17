import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/astro_cities_data.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/natal_calculator_service.dart';

/// ASTRAL Phase 1 — offline ephemeris engine verification.
///
/// Every numeric anchor below is an exact reference value from an
/// independent authority:
///  * Swiss Ephemeris 2.10.04 (`swetest`, Astrodienst) for planetary
///    longitudes, ASC/MC and house cusps (apparent positions, UT).
///  * Jean Meeus "Astronomical Algorithms" worked examples (ch. 25, 37, 47).
///  * NASA moon-phase instants (2000).
void main() {
  final j2000Ut = DateTime.utc(2000, 1, 1);
  final bishkekUt = DateTime.utc(1988, 6, 15, 14, 30);

  group('astronomical core (Meeus)', () {
    test('julian day & centuries from J2000.0', () {
      expect(NatalCalculatorService.julianDay(DateTime.utc(2000, 1, 1, 12)),
          closeTo(2451545.0, 1e-9));
      expect(NatalCalculatorService.julianDay(DateTime.utc(1999, 1, 1)),
          closeTo(2451179.5, 1e-9));
      expect(NatalCalculatorService.julianCenturies(DateTime.utc(2000, 1, 1, 12)),
          closeTo(0.0, 1e-12));
    });

    test('mean & true obliquity of the ecliptic at J2000', () {
      // swetest: Epsilon (t/m) 23°26'15.6467 / 23°26'21.4066
      expect(NatalCalculatorService.meanObliquity(j2000Ut),
          closeTo(23.4392796, 2e-6));
      expect(NatalCalculatorService.trueObliquity(j2000Ut),
          closeTo(23.4376796, 1e-5));
    });

    test('nutation in longitude matches swetest (-13.93")', () {
      expect(NatalCalculatorService.nutationInLongitude(j2000Ut),
          closeTo(-13.9311 / 3600.0, 0.2 / 3600.0));
    });

    test('GMST at J2000.0 is 280.4606°', () {
      expect(
          NatalCalculatorService
              .greenwichMeanSiderealTime(DateTime.utc(2000, 1, 1, 12)),
          closeTo(280.46061837, 1e-4));
    });

    test('RAMC (apparent sidereal) matches swetest ARMC 99.9642°', () {
      // swetest: ARMC 9 cn 57'51.2959" = 99.9642489 (lon 0, 0 UT)
      expect(
          NatalCalculatorService.localSiderealTime(
              j2000Ut, eastLongitude: 0.0),
          closeTo(99.9642489, 0.005));
    });
  });

  group('Sun, Moon & Pluto vs Meeus book examples', () {
    test('Sun apparent longitude 1992-10-13 (Meeus 25.a)', () {
      // Book: true 199°54'36", apparent 199°54'32", R = 0.99766.
      final (lon, radius) = NatalCalculatorService.sunApparentPosition(
          DateTime.utc(1992, 10, 13));
      expect(lon, closeTo(199.908889, 0.02));
      expect(radius, closeTo(0.99766, 2e-4));
    });

    test('Moon geocentric longitude 1992-04-12 (Meeus 47.a)', () {
      final (lon, lat) = NatalCalculatorService.moonGeocentricPosition(
          DateTime.utc(1992, 4, 12));
      expect(lon, closeTo(133.162655, 0.05));
      expect(lat, closeTo(-3.229126, 0.02));
    });

    test('Pluto heliocentric position 1992-10-13 (Meeus 37)', () {
      final (lon, lat, radius) = NatalCalculatorService.plutoHeliocentricPosition(
          DateTime.utc(1992, 10, 13));
      expect(lon, closeTo(232.74071, 0.01));
      expect(lat, closeTo(14.58782, 0.01));
      expect(radius, closeTo(29.711111, 2e-4));
    });
  });

  group('planetary longitudes vs swetest anchor (2000-01-01 0 UT)', () {
    const expected = <PlanetId, double>{
      PlanetId.sun: 279.8592144,
      PlanetId.moon: 217.2932858,
      PlanetId.mercury: 271.1118066,
      PlanetId.venus: 240.9614107,
      PlanetId.mars: 327.5754696,
      PlanetId.jupiter: 25.2331293,
      PlanetId.saturn: 40.4058642,
      PlanetId.uranus: 314.7840718,
      PlanetId.neptune: 303.1752554,
      PlanetId.pluto: 251.4371718,
    };
    final tolerances = <PlanetId, double>{
      PlanetId.sun: 0.02,
      PlanetId.moon: 0.06,
      PlanetId.mercury: 0.05,
      PlanetId.venus: 0.05,
      PlanetId.mars: 0.05,
      PlanetId.jupiter: 0.05,
      PlanetId.saturn: 0.05,
      PlanetId.uranus: 0.05,
      PlanetId.neptune: 0.05,
      PlanetId.pluto: 0.03,
    };
    expected.forEach((planet, lon) {
      test('${planet.name} ≈ $lon°', () {
        expect(
            NatalCalculatorService.computeEclipticLongitude(planet, j2000Ut),
            closeTo(lon, tolerances[planet]!));
      });
    });
  });

  group('planetary longitudes vs swetest anchor (Bishkek 1988-06-15)', () {
    const expected = <PlanetId, double>{
      PlanetId.sun: 84.6912575,
      PlanetId.moon: 99.0966769,
      PlanetId.mercury: 81.0125172,
      PlanetId.venus: 80.5840942,
      PlanetId.mars: 344.9710986,
      PlanetId.jupiter: 52.8008640,
      PlanetId.saturn: 269.6082290,
      PlanetId.uranus: 269.2417077,
      PlanetId.neptune: 279.2073750,
      PlanetId.pluto: 220.0799500,
    };
    expected.forEach((planet, lon) {
      test('${planet.name} ≈ $lon°', () {
        expect(
            NatalCalculatorService.computeEclipticLongitude(planet, bishkekUt),
            closeTo(lon, planet == PlanetId.moon ? 0.06 : 0.05));
      });
    });
  });

  group('Mercury retrograde detection (2024-08 window)', () {
    test('Mercury is retrograde mid-August 2024', () {
      expect(
          NatalCalculatorService.isRetrograde(
              PlanetId.mercury, DateTime.utc(2024, 8, 15)),
          isTrue);
      expect(
          NatalCalculatorService.isRetrograde(
              PlanetId.mercury, DateTime.utc(2024, 7, 1)),
          isFalse);
      expect(
          NatalCalculatorService.isRetrograde(
              PlanetId.sun, DateTime.utc(2024, 8, 15)),
          isFalse);
    });
  });

  group('ASC / MC vs swetest', () {
    test('2000-01-01 0 UT, lon 0, lat 52.5', () {
      expect(
          NatalCalculatorService.ascendant(
              utc: j2000Ut, latitude: 52.5, eastLongitude: 0.0),
          closeTo(186.9377666, 0.01));
      expect(
          NatalCalculatorService.midheaven(utc: j2000Ut, eastLongitude: 0.0),
          closeTo(99.1566657, 0.01));
    });

    test('Bishkek 1988-06-15 14:30 UT', () {
      expect(
          NatalCalculatorService.ascendant(
              utc: bishkekUt, latitude: 42.87, eastLongitude: 74.57),
          closeTo(263.2329846, 0.01));
      expect(
          NatalCalculatorService.midheaven(
              utc: bishkekUt, eastLongitude: 74.57),
          closeTo(197.5273947, 0.01));
    });
  });

  group('house systems vs swetest', () {
    final placidus52 = <double>[
      186.9377666, 211.4233791, 242.2614193, 279.1566657, 314.9872041,
      344.1682795, 6.9377666, 31.4233791, 62.2614193, 99.1566657,
      134.9872041, 164.1682795,
    ];
    final koch52 = <double>[
      186.9377666, 215.5071031, 244.4186097, 279.1566657, 309.7343822,
      338.2478878, 6.9377666, 35.5071031, 64.4186097, 99.1566657,
      129.7343822, 158.2478878,
    ];
    final whole52 = <double>[
      180, 210, 240, 270, 300, 330, 0, 30, 60, 90, 120, 150,
    ];

    test('Placidus 12 cusps, lat 52.5', () {
      final cusps = NatalCalculatorService.computeHouseCusps(
          latitude: 52.5,
          eastLongitude: 0.0,
          utc: j2000Ut,
          system: HouseSystem.placidus);
      for (var i = 0; i < 12; i++) {
        expect(cusps[i], closeTo(placidus52[i], 0.01), reason: 'cusp ${i + 1}');
      }
    });

    test('Koch 12 cusps, lat 52.5', () {
      final cusps = NatalCalculatorService.computeHouseCusps(
          latitude: 52.5,
          eastLongitude: 0.0,
          utc: j2000Ut,
          system: HouseSystem.koch);
      for (var i = 0; i < 12; i++) {
        expect(cusps[i], closeTo(koch52[i], 0.01), reason: 'cusp ${i + 1}');
      }
    });

    test('Whole sign 12 cusps, lat 52.5 (cusp 1 = 0° Libra)', () {
      final cusps = NatalCalculatorService.computeHouseCusps(
          latitude: 52.5,
          eastLongitude: 0.0,
          utc: j2000Ut,
          system: HouseSystem.wholeSign);
      for (var i = 0; i < 12; i++) {
        expect(cusps[i], closeTo(whole52[i], 1e-9), reason: 'cusp ${i + 1}');
      }
    });

    test('the three systems produce distinct cusp sets', () {
      expect(placidus52, isNot(orderedEquals(koch52)));
      expect(placidus52, isNot(orderedEquals(whole52)));
    });

    test('high latitude 68°N: Placidus/Koch fall back to Porphyry, no NaN',
        () {
      // swetest: "error: House method Placidus failed, Porphyry calculated
      // instead" — these exact cusps.
      final porphyry68 = <double>[
        185.2361445, 216.5429843, 247.8498242, 279.1566657, 307.8498242,
        336.5429843, 5.2361445, 36.5429843, 67.8498242, 99.1566657,
        127.8498242, 156.5429843,
      ];
      for (final system in [HouseSystem.placidus, HouseSystem.koch]) {
        final cusps = NatalCalculatorService.computeHouseCusps(
            latitude: 68.0,
            eastLongitude: 0.0,
            utc: j2000Ut,
            system: system);
        expect(cusps.length, 12);
        for (var i = 0; i < 12; i++) {
          expect(cusps[i].isFinite, isTrue);
          expect(cusps[i], closeTo(porphyry68[i], 0.01),
              reason: '$system cusp ${i + 1}');
        }
      }
    });

    test('high latitude 68°N: Whole sign stays at sign boundaries', () {
      final cusps = NatalCalculatorService.computeHouseCusps(
          latitude: 68.0,
          eastLongitude: 0.0,
          utc: j2000Ut,
          system: HouseSystem.wholeSign);
      expect(cusps, orderedEquals(whole52));
    });
  });


  group('aspect detection & sorting', () {
    NatalPlanetPosition pos(PlanetId id, double lon) => NatalPlanetPosition(
          planet: id,
          longitude: lon,
          sign: ZodiacSignX.fromLongitude(lon),
          degreeInSign: lon % 30,
          house: 1,
          isRetrograde: false,
          interpretation: 'x',
        );

    test('trine/sextile/square detected with correct orbs & strength', () {
      final aspects = NatalCalculatorService.computeAspects([
        pos(PlanetId.sun, 0.0),
        pos(PlanetId.moon, 120.0),
        pos(PlanetId.mercury, 87.0),
        pos(PlanetId.venus, 60.5),
      ]);
      final trine = aspects.firstWhere((a) =>
          (a.bodyA == PlanetId.sun && a.bodyB == PlanetId.moon) ||
          (a.bodyA == PlanetId.moon && a.bodyB == PlanetId.sun));
      expect(trine.type, AspectType.trine);
      expect(trine.exactAngle, closeTo(120.0, 1e-9));
      expect(trine.orb, closeTo(0.0, 1e-9));
      expect(trine.strength, closeTo(1.0, 1e-9));

      final sextile = aspects.firstWhere((a) =>
          (a.bodyA == PlanetId.venus && a.bodyB == PlanetId.sun) ||
          (a.bodyA == PlanetId.sun && a.bodyB == PlanetId.venus));
      expect(sextile.type, AspectType.sextile);
      expect(sextile.orb, closeTo(0.5, 1e-9));
      expect(sextile.strength, closeTo(1 - 0.5 / 5, 1e-9));

      final square = aspects.firstWhere((a) =>
          (a.bodyA == PlanetId.mercury && a.bodyB == PlanetId.sun) ||
          (a.bodyA == PlanetId.sun && a.bodyB == PlanetId.mercury));
      expect(square.type, AspectType.square);
      expect(square.orb, closeTo(3.0, 1e-9));
      expect(square.strength, closeTo(1 - 3.0 / 7, 1e-9));
    });

    test('sorted tightest-orb first, strength in 0..1', () {
      final aspects = NatalCalculatorService.computeAspects([
        pos(PlanetId.sun, 0.0),
        pos(PlanetId.moon, 120.0),
        pos(PlanetId.mercury, 87.0),
        pos(PlanetId.venus, 60.5),
        pos(PlanetId.mars, 3.0),
      ]);
      for (var i = 1; i < aspects.length; i++) {
        expect(aspects[i - 1].orb <= aspects[i].orb + 1e-9, isTrue);
      }
      for (final a in aspects) {
        expect(a.strength, inInclusiveRange(0.0, 1.0));
      }
      expect(aspects.first.type, AspectType.trine);
    });

    test('no aspect beyond max orb', () {
      final aspects = NatalCalculatorService.computeAspects([
        pos(PlanetId.sun, 0.0),
        pos(PlanetId.moon, 10.0), // beyond conjunction orb 8
      ]);
      expect(aspects, isEmpty);
    });
  });

  group('full natal chart (Bishkek birth)', () {
    late NatalChart chart;
    setUpAll(() {
      chart = NatalCalculatorService.calculateNatalChart(
        id: 'test-bishkek',
        profileName: 'Test Profile',
        birthDateUtc: bishkekUt,
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
        createdAt: DateTime.utc(2026, 1, 1),
      );
    });

    test('planets, ASC & MC match swetest', () {
      const expected = <PlanetId, double>{
        PlanetId.sun: 84.6912575,
        PlanetId.moon: 99.0966769,
        PlanetId.mercury: 81.0125172,
        PlanetId.venus: 80.5840942,
        PlanetId.mars: 344.9710986,
        PlanetId.jupiter: 52.8008640,
        PlanetId.saturn: 269.6082290,
        PlanetId.uranus: 269.2417077,
        PlanetId.neptune: 279.2073750,
        PlanetId.pluto: 220.0799500,
        PlanetId.ascendant: 263.2329846,
        PlanetId.midheaven: 197.5273947,
      };
      for (final entry in expected.entries) {
        final position = chart.planets.firstWhere((p) => p.planet == entry.key,
            orElse: () => fail('missing ${entry.key}'));
        expect(position.longitude, closeTo(entry.value, 0.05),
            reason: entry.key.name);
      }
    });

    test('signs, degrees & houses are coherent', () {
      final sun = chart.planets.firstWhere((p) => p.planet == PlanetId.sun);
      expect(sun.sign, ZodiacSign.gemini);
      expect(sun.degreeInSign, closeTo(24.6912575, 0.05));
      expect(sun.formattedDegree, startsWith('24°'));
      final asc =
          chart.planets.firstWhere((p) => p.planet == PlanetId.ascendant);
      expect(asc.house, 1);
      final mc =
          chart.planets.firstWhere((p) => p.planet == PlanetId.midheaven);
      expect(mc.house, 10);
      for (final p in chart.planets) {
        expect(p.house, inInclusiveRange(1, 12));
        expect(p.longitude, inInclusiveRange(0.0, 360.0));
        expect(p.interpretation, isNotEmpty);
      }
      expect(chart.houseCusps.length, 12);
    });



    test('recalculateWithHouseSystem switches cusps instantly', () {
      final whole = NatalCalculatorService.recalculateWithHouseSystem(
          chart, HouseSystem.wholeSign);
      expect(whole.houseSystem, HouseSystem.wholeSign);
      expect(whole.houseCusps,
          orderedEquals(<double>[240, 270, 300, 330, 0, 30, 60, 90, 120, 150, 180, 210]));
      for (var i = 0; i < whole.planets.length; i++) {
        expect(whole.planets[i].longitude, chart.planets[i].longitude);
      }
      for (final p in whole.planets) {
        expect(p.house, inInclusiveRange(1, 12));
      }
    });

    test('JSON round-trip preserves the chart', () {
      final restored = NatalChart.fromJson(chart.toJson());
      expect(restored.id, chart.id);
      expect(restored.profileName, chart.profileName);
      expect(restored.birthDateUtc, chart.birthDateUtc);
      expect(restored.birthLocalHour, chart.birthLocalHour);
      expect(restored.timeKnown, chart.timeKnown);
      expect(restored.cityName, chart.cityName);
      expect(restored.latitude, chart.latitude);
      expect(restored.longitude, chart.longitude);
      expect(restored.timezoneOffsetHours, chart.timezoneOffsetHours);
      expect(restored.houseSystem, chart.houseSystem);
      expect(restored.houseCusps, orderedEquals(chart.houseCusps));
      expect(restored.planets.length, chart.planets.length);
      for (var i = 0; i < restored.planets.length; i++) {
        final a = restored.planets[i];
        final b = chart.planets[i];
        expect(a.planet, b.planet);
        expect(a.longitude, closeTo(b.longitude, 1e-9));
        expect(a.house, b.house);
        expect(a.isRetrograde, b.isRetrograde);
      }
      expect(restored.aspects.length, chart.aspects.length);
    });
  });

  group('moon phase (NASA 2000 instants)', () {
    test('new moon 2000-01-06 18:14 UT', () {
      final phase = NatalCalculatorService.computeMoonPhase(
          DateTime.utc(2000, 1, 6, 18, 14));
      expect(phase.name, 'New Moon');
      expect(phase.illumination, lessThan(0.03));
    });

    test('first quarter 2000-01-14 13:34 UT', () {
      final phase = NatalCalculatorService.computeMoonPhase(
          DateTime.utc(2000, 1, 14, 13, 34));
      expect(phase.name, 'First Quarter');
      expect(phase.illumination, closeTo(0.5, 0.04));
    });

    test('full moon 2000-01-21 04:40 UT', () {
      final phase = NatalCalculatorService.computeMoonPhase(
          DateTime.utc(2000, 1, 21, 4, 40));
      expect(phase.name, 'Full Moon');
      expect(phase.illumination, greaterThan(0.97));
    });

    test('last quarter 2000-01-28 07:57 UT', () {
      final phase = NatalCalculatorService.computeMoonPhase(
          DateTime.utc(2000, 1, 28, 7, 57));
      expect(phase.name, 'Last Quarter');
      expect(phase.illumination, closeTo(0.5, 0.04));
    });
  });

  group('daily horoscope (live transits)', () {
    late NatalChart chart;
    setUpAll(() {
      chart = NatalCalculatorService.calculateNatalChart(
        id: 'horo',
        profileName: 'H',
        birthDateUtc: bishkekUt,
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
        createdAt: DateTime.utc(2026, 1, 1),
      );
    });

    test('report invariants & deterministic for a fixed date', () {
      final report = NatalCalculatorService.computeDailyHoroscope(
          chart, forDate: DateTime.utc(2024, 1, 1, 12));
      expect(report.date, DateTime.utc(2024, 1, 1, 12));
      expect(report.moonPhaseName, isNotEmpty);
      expect(report.moonPhaseGlyph, isNotEmpty);
      expect(report.moonIllumination, inInclusiveRange(0.0, 1.0));
      expect(report.transitingMoonSign, isNotNull);
      expect(report.transitingMoonHouse, inInclusiveRange(1, 12));
      expect(report.overallTheme, isNotEmpty);
      expect(report.energyScore, inInclusiveRange(1, 100));
      expect(report.transits.length, inInclusiveRange(3, 5));
      for (var i = 1; i < report.transits.length; i++) {
        expect(report.transits[i - 1].orb <= report.transits[i].orb + 1e-9,
            isTrue, reason: 'transits sorted by orb');
      }
      for (final t in report.transits) {
        expect(t.transitLabel,
            matches(RegExp(r'^Transit [A-Za-z]+ [☌⚹□△☍] Natal [A-Za-z]+$')));
        expect(t.title, isNotEmpty);
        expect(t.advice, isNotEmpty);
        expect(t.orb, greaterThanOrEqualTo(0));
      }
      final again = NatalCalculatorService.computeDailyHoroscope(
          chart, forDate: DateTime.utc(2024, 1, 1, 12));
      expect(again.overallTheme, report.overallTheme);
      expect(again.energyScore, report.energyScore);
    });
  });



  group('domain models', () {
    test('HouseSystem labels & Russian subtitles', () {
      expect(HouseSystem.placidus.label, 'PLACIDUS');
      expect(HouseSystem.koch.label, 'KOCH');
      expect(HouseSystem.wholeSign.label, 'WHOLE SIGN');
      expect(HouseSystem.placidus.ruSubtitle, isNotEmpty);
      expect(HouseSystem.koch.ruSubtitle, isNotEmpty);
      expect(HouseSystem.wholeSign.ruSubtitle, isNotEmpty);
    });

    test('ZodiacSign glyphs, elements, modalities, rulers', () {
      expect(ZodiacSign.values.length, 12);
      expect(ZodiacSign.aries.glyph, '♈');
      expect(ZodiacSign.pisces.glyph, '♓');
      expect(ZodiacSign.aries.element, Element.fire);
      expect(ZodiacSign.cancer.element, Element.water);
      expect(ZodiacSign.gemini.element, Element.air);
      expect(ZodiacSign.taurus.element, Element.earth);
      expect(ZodiacSign.aries.modality, ZodiacModality.cardinal);
      expect(ZodiacSign.taurus.modality, ZodiacModality.fixed);
      expect(ZodiacSign.gemini.modality, ZodiacModality.mutable);
      expect(ZodiacSign.aries.ruler, PlanetId.mars);
      expect(ZodiacSign.leo.ruler, PlanetId.sun);
      expect(ZodiacSign.scorpio.ruler, PlanetId.pluto);
      expect(ZodiacSignX.fromLongitude(0.0), ZodiacSign.aries);
      expect(ZodiacSignX.fromLongitude(359.99), ZodiacSign.pisces);
    });

    test('PlanetId: 12 entries with glyphs & archetypes', () {
      expect(PlanetId.values.length, 12);
      expect(PlanetId.sun.glyph, '☉');
      expect(PlanetId.moon.glyph, '☽');
      expect(PlanetId.mercury.glyph, '☿');
      expect(PlanetId.venus.glyph, '♀');
      expect(PlanetId.mars.glyph, '♂');
      expect(PlanetId.jupiter.glyph, '♃');
      expect(PlanetId.saturn.glyph, '♄');
      expect(PlanetId.uranus.glyph, '♅');
      expect(PlanetId.neptune.glyph, '♆');
      expect(PlanetId.pluto.glyph, '♇');
      expect(PlanetId.ascendant.glyph, 'ASC');
      expect(PlanetId.midheaven.glyph, 'MC');
      for (final p in PlanetId.values) {
        expect(p.title, isNotEmpty);
        expect(p.archetype, isNotEmpty);
      }
    });

    test('AspectType orbs, glyphs, harmony', () {
      expect(AspectType.conjunction.baseAngle, 0);
      expect(AspectType.conjunction.maxOrb, 8);
      expect(AspectType.sextile.baseAngle, 60);
      expect(AspectType.sextile.maxOrb, 5);
      expect(AspectType.square.baseAngle, 90);
      expect(AspectType.square.maxOrb, 7);
      expect(AspectType.trine.baseAngle, 120);
      expect(AspectType.trine.maxOrb, 7);
      expect(AspectType.opposition.baseAngle, 180);
      expect(AspectType.opposition.maxOrb, 8);
      expect(AspectType.conjunction.glyph, '☌');
      expect(AspectType.sextile.glyph, '⚹');
      expect(AspectType.square.glyph, '□');
      expect(AspectType.trine.glyph, '△');
      expect(AspectType.opposition.glyph, '☍');
      expect(AspectType.trine.harmony, AspectHarmony.harmonious);
      expect(AspectType.square.harmony, AspectHarmony.tense);
      expect(AspectType.conjunction.harmony, AspectHarmony.intense);
    });
  });


  group('offline city catalog', () {
    test('75+ cities with sane coordinates', () {
      expect(astroCities.length, greaterThanOrEqualTo(75));
      for (final c in astroCities) {
        expect(c.latitude, inInclusiveRange(-90.0, 90.0));
        expect(c.longitude, inInclusiveRange(-180.0, 180.0));
        expect(c.name, isNotEmpty);
        expect(c.country, isNotEmpty);
      }
    });

    test('Bishkek & key CIS cities present with accurate data', () {
      final bishkek = astroCities.firstWhere((c) => c.name == 'Bishkek');
      expect(bishkek.latitude, closeTo(42.8746, 0.01));
      expect(bishkek.longitude, closeTo(74.5698, 0.01));
      expect(bishkek.timezoneOffsetHours, 6);
      for (final name in [
        'Karakol', 'Osh', 'Almaty', 'Astana', 'Tashkent', 'Moscow',
        'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg', 'Kyiv', 'Minsk',
        'Tbilisi', 'Yerevan', 'Baku', 'London', 'Paris', 'Berlin',
        'New York', 'Los Angeles', 'Tokyo',
      ]) {
        expect(astroCities.any((c) => c.name == name), isTrue,
            reason: name);
      }
    });

    test('case-insensitive search', () {
      expect(searchAstroCities('bishk'), isNotEmpty);
      expect(searchAstroCities('BISHKEK').first.name, 'Bishkek');
      expect(searchAstroCities('mos').map((c) => c.name), contains('Moscow'));
      expect(searchAstroCities('zzzz'), isEmpty);
    });
  });
}
