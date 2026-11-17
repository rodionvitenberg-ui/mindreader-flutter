import 'dart:math' as math;

import '../data/astro_ephemeris_tables.dart';
import '../models/natal_chart.dart';
import '../models/tarot_card_model.dart' show Element;

/// ASTRAL Phase 1 — the 100% offline, deterministic ephemeris engine.
///
/// Astronomy: Meeus "Astronomical Algorithms" — Sun ch.25 (coarse), Moon
/// ch.47 (truncated main series), Mercury..Neptune ch.32 (VSOP87 series),
/// Pluto ch.37. Houses are a 1:1 port of Swiss Ephemeris `swehouse.cpp`
/// (Placidus iterative semi-arcs, Koch, Whole Sign, Porphyry fallback for
/// |latitude| >= 90 − ε). All angles in degrees; all times UTC.
///
/// Verified against swetest 2.10.04 anchors
/// (see test/natal_calculator_test.dart).
class NatalCalculatorService {
  NatalCalculatorService._();

  // ---------------------------------------------------------------------
  // Time
  // ---------------------------------------------------------------------

  /// Julian Day for a UTC instant (Meeus 7.1 via unix epoch).
  static double julianDay(DateTime utc) =>
      utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  /// Julian centuries T from J2000.0.
  static double julianCenturies(DateTime utc) =>
      (julianDay(utc) - 2451545.0) / 36525.0;

  // ---------------------------------------------------------------------
  // Obliquity & nutation (Meeus ch.22)
  // ---------------------------------------------------------------------

  static double _meanLongitudeSun(double t) =>
      _norm360(280.46646 + t * (36000.76983 + t * 0.0003032));

  static double _meanLongitudeMoon(double t) =>
      _norm360(218.3165 + t * 481267.8813);

  static double _omega(double t) => 125.04452 - 1934.136261 * t;

  /// Mean obliquity of the ecliptic (IAU 2006 polynomial — matches
  /// Swiss Ephemeris 2.10 to 0.0002").
  static double meanObliquity(DateTime utc) {
    final t = julianCenturies(utc);
    final seconds =
        84381.406 -
        t *
            (46.836769 +
                t *
                    (0.0001831 -
                        t * (0.0020034 - t * (5.76e-7 - t * 4.34e-8))));
    return seconds / 3600.0;
  }

  /// Nutation in longitude Δψ in degrees (main 4 terms, Meeus 22.2).
  static double nutationInLongitude(DateTime utc) {
    final t = julianCenturies(utc);
    final l = _rad(_meanLongitudeSun(t));
    final lp = _rad(_meanLongitudeMoon(t));
    final omega = _rad(_omega(t));
    return (-17.20 * math.sin(omega) -
            1.32 * math.sin(2 * l) -
            0.23 * math.sin(2 * lp) +
            0.21 * math.sin(2 * omega)) /
        3600.0;
  }

  /// Nutation in obliquity Δε in degrees (main terms).
  static double _nutationInObliquity(DateTime utc) {
    final t = julianCenturies(utc);
    final l = _rad(_meanLongitudeSun(t));
    final lp = _rad(_meanLongitudeMoon(t));
    final omega = _rad(_omega(t));
    return (9.20 * math.cos(omega) +
            0.57 * math.cos(2 * l) +
            0.10 * math.cos(2 * lp) -
            0.09 * math.cos(2 * omega)) /
        3600.0;
  }

  /// True obliquity ε = ε0 + Δε.
  static double trueObliquity(DateTime utc) =>
      meanObliquity(utc) + _nutationInObliquity(utc);

  // ---------------------------------------------------------------------
  // Sidereal time (Meeus 12.4) & angles
  // ---------------------------------------------------------------------

  /// Greenwich mean sidereal time in degrees.
  static double greenwichMeanSiderealTime(DateTime utc) {
    final jd = julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;
    return _norm360(
      280.46061837 +
          360.98564736629 * (jd - 2451545.0) +
          0.000387933 * t * t -
          t * t * t / 38710000.0,
    );
  }

  /// Local apparent sidereal time (RAMC) in degrees for an east longitude.
  static double localSiderealTime(
    DateTime utc, {
    required double eastLongitude,
  }) {
    final gast =
        greenwichMeanSiderealTime(utc) +
        nutationInLongitude(utc) * math.cos(_rad(trueObliquity(utc)));
    return _norm360(gast + eastLongitude);
  }

  /// Midheaven ecliptic longitude, degrees.
  static double midheaven({
    required DateTime utc,
    required double eastLongitude,
  }) {
    final ramc = localSiderealTime(utc, eastLongitude: eastLongitude);
    return _mcFromRamc(ramc, trueObliquity(utc));
  }

  static double _mcFromRamc(double ramc, double eps) {
    final r = _rad(ramc);
    return _norm360(
      _deg(math.atan2(math.sin(r), math.cos(r) * math.cos(_rad(eps)))),
    );
  }

  /// Ascendant ecliptic longitude, degrees.
  ///
  /// Uses the swehouse.c `Asc1` quadrant dispatch (the raw atan2 form of
  /// the same triangle returns the opposite point, i.e. ASC + 180°).
  static double ascendant({
    required DateTime utc,
    required double latitude,
    required double eastLongitude,
  }) {
    final ramc = localSiderealTime(utc, eastLongitude: eastLongitude);
    final eps = trueObliquity(utc);
    return _asc1(
      ramc + 90,
      latitude,
      math.sin(_rad(eps)),
      math.cos(_rad(eps)),
    );
  }

  // ---------------------------------------------------------------------
  // Angle helpers (degree-based, mirroring swehouse.c semantics)
  // ---------------------------------------------------------------------

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;
  static double _sind(double x) => math.sin(_rad(x));
  static double _cosd(double x) => math.cos(_rad(x));
  static double _tand(double x) => math.tan(_rad(x));
  static double _asind(double x) => _deg(math.asin(x.clamp(-1.0, 1.0)));
  static double _atand(double x) => _deg(math.atan(x));

  static double _norm360(double x) {
    var v = x % 360.0;
    if (v < 0) v += 360.0;
    return v;
  }

  /// Signed difference a − b normalized to [−180, 180) (swe_difdeg2n).
  static double _difdeg2n(double a, double b) {
    var d = (a - b) % 360.0;
    if (d >= 180.0) d -= 360.0;
    return d;
  }

  /// Asc2 from swehouse.c: oblique triangle crossing of ecliptic and the
  /// great circle of pole height f; x in 0..90, f in −90..+90.
  static double _asc2(double x, double f, double sine, double cose) {
    var ass = -_tand(f) * sine + cose * _cosd(x);
    if (ass.abs() < 1e-12) ass = 0;
    var sinx = _sind(x);
    if (sinx.abs() < 1e-12) sinx = 0;
    if (sinx == 0) {
      ass = ass < 0 ? -1e-12 : 1e-12;
    } else if (ass == 0) {
      ass = sinx < 0 ? -90.0 : 90.0;
    } else {
      ass = _atand(sinx / ass);
    }
    if (ass < 0) ass = 180 + ass;
    return ass;
  }

  /// Asc1 from swehouse.c: Ascendant ecliptic longitude for right
  /// ascension x1, geographic latitude f, obliquity (sine, cose).
  static double _asc1(double x1, double f, double sine, double cose) {
    x1 = _norm360(x1);
    final n = (x1 / 90).floor() + 1;
    if ((90 - f).abs() < 1e-9) return 180;
    if ((90 + f).abs() < 1e-9) return 0;
    final double ass;
    if (n == 1) {
      ass = _asc2(x1, f, sine, cose);
    } else if (n == 2) {
      ass = 180 - _asc2(180 - x1, -f, sine, cose);
    } else if (n == 3) {
      ass = 180 + _asc2(x1 - 180, -f, sine, cose);
    } else {
      ass = 360 - _asc2(360 - x1, f, sine, cose);
    }
    return _norm360(ass);
  }

  // ---------------------------------------------------------------------
  // House systems (port of Swiss Ephemeris swehouse.cpp)
  // ---------------------------------------------------------------------

  /// 12 house cusp ecliptic longitudes for the given birth moment and
  /// system. Placidus and Koch fall back to Porphyry inside the polar
  /// circle (|latitude| >= 90 − ε) — never NaN.
  static List<double> computeHouseCusps({
    required double latitude,
    required double eastLongitude,
    required DateTime utc,
    required HouseSystem system,
  }) {
    final ramc = localSiderealTime(utc, eastLongitude: eastLongitude);
    final eps = trueObliquity(utc);
    final sine = math.sin(_rad(eps));
    final cose = math.cos(_rad(eps));
    final tane = math.tan(_rad(eps));
    final fi = latitude;
    final tanfi = _tand(fi);
    final mc = _mcFromRamc(ramc, eps);
    final ac = _asc1(ramc + 90, fi, sine, cose);

    switch (system) {
      case HouseSystem.wholeSign:
        return _wholeSignCusps(ac);
      case HouseSystem.koch:
        if (fi.abs() >= 90 - eps) return _porphyryCusps(ac, mc);
        return _kochCusps(ramc, fi, mc, ac, sine, cose, tanfi);
      case HouseSystem.placidus:
        if (fi.abs() >= 90 - eps) return _porphyryCusps(ac, mc);
        return _placidusCusps(ramc, fi, mc, ac, sine, cose, tane, tanfi);
    }
  }

  /// Whole sign: cusp 1 = 0° of the Ascendant's sign, +30° each.
  static List<double> _wholeSignCusps(double ac) {
    final start = (ac / 30.0).floor() * 30.0;
    return [for (var i = 0; i < 12; i++) (start + i * 30.0) % 360.0];
  }

  /// Porphyry fallback (swetest 'O'): trisect the short arc ASC↔MC.
  static List<double> _porphyryCusps(double ac0, double mc) {
    var ac = ac0;
    var acmc = _difdeg2n(ac, mc);
    if (acmc < 0) {
      // Within polar circle we swap AC/DC if AC is on the wrong side.
      ac = _norm360(ac + 180);
      acmc = _difdeg2n(ac, mc);
    }
    final cusps = List<double>.filled(12, 0);
    cusps[0] = ac; // 1
    cusps[9] = mc; // 10
    cusps[1] = _norm360(ac + (180 - acmc) / 3); // 2
    cusps[2] = _norm360(ac + (180 - acmc) / 3 * 2); // 3
    cusps[10] = _norm360(mc + acmc / 3); // 11
    cusps[11] = _norm360(mc + acmc / 3 * 2); // 12
    cusps[3] = _norm360(cusps[9] + 180); // 4
    cusps[4] = _norm360(cusps[10] + 180); // 5
    cusps[5] = _norm360(cusps[11] + 180); // 6
    cusps[6] = _norm360(cusps[0] + 180); // 7
    cusps[7] = _norm360(cusps[1] + 180); // 8
    cusps[8] = _norm360(cusps[2] + 180); // 9
    return cusps;
  }

  /// Koch: direct construction from the MC's declination ascensional
  /// difference (swehouse.c case 'K').
  static List<double> _kochCusps(
    double ramc,
    double fi,
    double mc,
    double ac,
    double sine,
    double cose,
    double tanfi,
  ) {
    var sina = _sind(mc) * sine / _cosd(fi);
    if (sina > 1) sina = 1;
    if (sina < -1) sina = -1;
    final cosa = math.sqrt(1 - sina * sina);
    final c = _atand(tanfi / cosa);
    final ad3 = _asind(_sind(c) * sina) / 3.0;
    final cusps = List<double>.filled(12, 0);
    cusps[0] = ac;
    cusps[9] = mc;
    cusps[10] = _asc1(ramc + 30 - 2 * ad3, fi, sine, cose);
    cusps[11] = _asc1(ramc + 60 - ad3, fi, sine, cose);
    cusps[1] = _asc1(ramc + 120 + ad3, fi, sine, cose);
    cusps[2] = _asc1(ramc + 150 + 2 * ad3, fi, sine, cose);
    cusps[3] = _norm360(cusps[9] + 180);
    cusps[4] = _norm360(cusps[10] + 180);
    cusps[5] = _norm360(cusps[11] + 180);
    cusps[6] = _norm360(cusps[0] + 180);
    cusps[7] = _norm360(cusps[1] + 180);
    cusps[8] = _norm360(cusps[2] + 180);
    return cusps;
  }

  /// Placidus: iterative semi-arc trisection (swehouse.c default case).
  static List<double> _placidusCusps(
    double ramc,
    double fi,
    double mc,
    double ac,
    double sine,
    double cose,
    double tane,
    double tanfi,
  ) {
    final a = _asind(tanfi * tane);
    final fh1 = _atand(_sind(a / 3) / tane);
    final fh2 = _atand(_sind(a * 2 / 3) / tane);
    final cusps = List<double>.filled(12, 0);
    cusps[0] = ac;
    cusps[9] = mc;
    cusps[10] = _placidusCusp(ramc + 30, fh1, 3.0, tanfi, sine, cose);
    cusps[11] = _placidusCusp(ramc + 60, fh2, 1.5, tanfi, sine, cose);
    cusps[1] = _placidusCusp(ramc + 120, fh2, 1.5, tanfi, sine, cose);
    cusps[2] = _placidusCusp(ramc + 150, fh1, 3.0, tanfi, sine, cose);
    cusps[3] = _norm360(cusps[9] + 180);
    cusps[4] = _norm360(cusps[10] + 180);
    cusps[5] = _norm360(cusps[11] + 180);
    cusps[6] = _norm360(cusps[0] + 180);
    cusps[7] = _norm360(cusps[1] + 180);
    cusps[8] = _norm360(cusps[2] + 180);
    return cusps;
  }

  /// One Placidus intermediate cusp via pole-height iteration.
  static double _placidusCusp(
    double rectasc,
    double fh,
    double divisor,
    double tanfi,
    double sine,
    double cose,
  ) {
    rectasc = _norm360(rectasc);
    var tant = _tand(_asind(sine * _sind(_asc1(rectasc, fh, sine, cose))));
    if (tant.abs() < 1e-12) return rectasc;
    var f = _atand(_sind(_asind(tanfi * tant) / divisor) / tant);
    var cusp = _asc1(rectasc, f, sine, cose);
    var cuspsv = 0.0;
    for (var i = 1; i <= 100; i++) {
      tant = _tand(_asind(sine * _sind(cusp)));
      if (tant.abs() < 1e-12) {
        cusp = rectasc;
        break;
      }
      f = _atand(_sind(_asind(tanfi * tant) / divisor) / tant);
      cusp = _asc1(rectasc, f, sine, cose);
      if (i > 1 && _difdeg2n(cusp, cuspsv).abs() < 1e-10) break;
      cuspsv = cusp;
    }
    return cusp;
  }

  /// House number (1..12) containing an ecliptic longitude.
  static int _houseForLongitude(double longitude, List<double> cusps) {
    final d = _norm360(longitude - cusps[0]);
    for (var i = 0; i < 11; i++) {
      final c2 = _norm360(cusps[i + 1] - cusps[0]);
      if (d < c2) return i + 1;
    }
    return 12;
  }

  // ---------------------------------------------------------------------
  // Planetary positions
  // ---------------------------------------------------------------------

  /// Sun true geometric longitude & radius vector (Meeus ch.25 coarse).
  static (double, double) _sunTrueLongitudeAndRadius(DateTime utc) {
    final t = julianCenturies(utc);
    final l0 = 280.46646 + t * (36000.76983 + t * 0.0003032);
    final m = 357.52911 + t * (35999.05029 - t * 0.0001537);
    final e = 0.016708634 - t * (0.000042037 + t * 0.0000001267);
    final mr = _rad(m);
    final c =
        (1.914602 - t * (0.004817 + t * 0.000014)) * math.sin(mr) +
        (0.019993 - t * 0.000101) * math.sin(2 * mr) +
        0.000289 * math.sin(3 * mr);
    final trueLon = _norm360(l0 + c);
    final nu = _rad(m + c);
    final r = 1.000001018 * (1 - e * e) / (1 + e * math.cos(nu));
    return (trueLon, r);
  }

  /// Sun apparent longitude (nutation + aberration) & radius vector.
  static (double, double) sunApparentPosition(DateTime utc) {
    final (trueLon, r) = _sunTrueLongitudeAndRadius(utc);
    final t = julianCenturies(utc);
    final omega = _rad(125.04 - 1934.136 * t);
    final apparent = _norm360(trueLon - 0.00569 - 0.00478 * math.sin(omega));
    return (apparent, r);
  }

  /// Moon geocentric longitude & latitude (Meeus ch.47 main series).
  static (double, double) moonGeocentricPosition(DateTime utc) {
    final t = julianCenturies(utc);
    final lp =
        218.3164477 +
        t *
            (481267.88123421 +
                t * (-0.0015786 + t * (1 / 538841 - t / 65194000)));
    final d =
        297.8501921 +
        t *
            (445267.1114034 +
                t * (-0.0018819 + t * (1 / 545868 - t / 113065000)));
    final m =
        357.5291092 + t * (35999.0502909 + t * (-0.0001536 + t / 24490000));
    final mp =
        134.9633964 +
        t * (477198.8675055 + t * (0.0087414 + t * (1 / 69699 - t / 14712000)));
    final f =
        93.2720950 +
        t *
            (483202.0175233 +
                t * (-0.0036539 + t * (-1 / 3526000 + t / 863310000)));
    final a1 = 119.75 + 131.849 * t;
    final a2 = 53.09 + 479264.290 * t;
    final a3 = 313.45 + 481266.484 * t;
    final e = 1 + (-0.002516 - 0.0000074 * t) * t;
    final e2 = e * e;
    final args = [_rad(d), _rad(m), _rad(mp), _rad(f)];
    var sigmal = 0.0;
    for (final row in astroMoonLr) {
      var arg = 0.0;
      for (var j = 0; j < 4; j++) {
        if (row[j] != 0) arg += row[j] * args[j];
      }
      var cl = row[4];
      if (row[1].abs() == 1) {
        cl *= e;
      } else if (row[1].abs() == 2) {
        cl *= e2;
      }
      sigmal += cl * math.sin(arg);
    }
    sigmal +=
        3958 * math.sin(_rad(a1)) +
        1962 * math.sin(_rad(lp) - _rad(f)) +
        318 * math.sin(_rad(a2));
    var sigmab = 0.0;
    for (final row in astroMoonB) {
      var arg = 0.0;
      for (var j = 0; j < 4; j++) {
        if (row[j] != 0) arg += row[j] * args[j];
      }
      var cb = row[4];
      if (row[1].abs() == 1) {
        cb *= e;
      } else if (row[1].abs() == 2) {
        cb *= e2;
      }
      sigmab += cb * math.sin(arg);
    }
    sigmab +=
        -2235 * math.sin(_rad(lp)) +
        382 * math.sin(_rad(a3)) +
        175 * math.sin(_rad(a1) - _rad(f)) +
        175 * math.sin(_rad(a1) + _rad(f)) +
        127 * math.sin(_rad(lp) - _rad(mp)) -
        115 * math.sin(_rad(lp) + _rad(mp));
    final lon = _norm360(lp + sigmal / 1000000.0);
    final lat = sigmab / 1000000.0;
    return (lon, lat);
  }

  /// One VSOP87 series order (A·cos(B + C·t), t in 100 Julian centuries).
  static double _vsopSeries(List<List<double>> order, double t) {
    var s = 0.0;
    for (final term in order) {
      s += term[0] * math.cos(term[1] + term[2] * t);
    }
    return s;
  }

  /// VSOP87 heliocentric position (longitude/latitude in radians,
  /// radius in AU) for Mercury..Neptune.
  static (double, double, double) _vsopHeliocentric(
    String planet,
    DateTime utc,
  ) {
    final t = (julianDay(utc) - 2451545.0) / 365250.0;
    double sumSeries(List<List<List<double>>> orders) {
      var sum = 0.0;
      for (var i = orders.length - 1; i > 0; i--) {
        sum = (sum + _vsopSeries(orders[i], t)) * t;
      }
      sum += _vsopSeries(orders[0], t);
      return sum / 1e8; // radians
    }

    final l = sumSeries(astroVsopL[planet]!);
    final b = sumSeries(astroVsopB[planet]!);
    final r = sumSeries(astroVsopR[planet]!);
    return (l, b, r);
  }

  /// General precession in ecliptic longitude from J2000 to the equinox of
  /// date, degrees (Meeus eq. 21.5: 5029.0966"T + 1.11113"T², higher-order
  /// terms remain below 0.0001" over the supported epoch range).
  static double _precessionInLongitude(double t) =>
      1.3969713 * t + 0.0003086 * t * t;

  /// Pluto heliocentric position (Meeus ch.37): longitude/latitude in
  /// degrees, radius in AU. Valid 1885..2099.
  ///
  /// Both angles are referred to the **J2000** equinox (PyMeeus uses the
  /// same convention, see `Pluto.geocentric_position`); callers that work
  /// in the mean equinox of date must precess the longitude first.
  static (double, double, double) plutoHeliocentricPosition(DateTime utc) {
    final t = julianCenturies(utc);
    final jj = 34.35 + 3034.9057 * t;
    final ss = 50.08 + 1222.1138 * t;
    final pp = 238.96 + 144.96 * t;
    var corrLon = 0.0;
    var corrLat = 0.0;
    var corrRad = 0.0;
    for (final row in astroPluto) {
      final alpha = _rad(_norm360(row[0] * jj + row[1] * ss + row[2] * pp));
      corrLon += row[3] * math.sin(alpha) + row[4] * math.cos(alpha);
      corrLat += row[5] * math.sin(alpha) + row[6] * math.cos(alpha);
      corrRad += row[7] * math.sin(alpha) + row[8] * math.cos(alpha);
    }
    final lon = _norm360(238.958116 + 144.96 * t + corrLon / 1e6);
    final lat = -3.908239 + corrLat / 1e6;
    final r = 40.7241346 + corrRad / 1e7;
    return (lon, lat, r);
  }

  /// Heliocentric → geocentric ecliptic longitude (degrees) with one
  /// light-time iteration. The provider returns (lon rad, lat rad, R AU).
  static double _toGeocentricLongitude(
    DateTime utc,
    (double, double, double) Function(DateTime) heliocentric,
  ) {
    var (lp, bp, rp) = heliocentric(utc);
    final (trueLon, re) = _sunTrueLongitudeAndRadius(utc);
    final le = _rad(_norm360(trueLon + 180));
    double x = rp * math.cos(bp) * math.cos(lp) - re * math.cos(le);
    double y = rp * math.cos(bp) * math.sin(lp) - re * math.sin(le);
    final delta = math.sqrt(x * x + y * y);
    final tau = 0.0057755183 * delta; // days of light travel
    if (tau > 0) {
      final shifted = utc.subtract(
        Duration(milliseconds: (tau * 86400000).round()),
      );
      (lp, bp, rp) = heliocentric(shifted);
      x = rp * math.cos(bp) * math.cos(lp) - re * math.cos(le);
      y = rp * math.cos(bp) * math.sin(lp) - re * math.sin(le);
    }
    return _norm360(_deg(math.atan2(y, x)));
  }

  /// Apparent ecliptic longitude (degrees) of one of the ten bodies.
  static double computeEclipticLongitude(PlanetId planet, DateTime utc) {
    if (planet.isAngle) {
      throw ArgumentError(
        'computeEclipticLongitude expects a moving body, not ${planet.name}',
      );
    }
    final dpsi = nutationInLongitude(utc);
    switch (planet) {
      case PlanetId.sun:
        return sunApparentPosition(utc).$1;
      case PlanetId.moon:
        return _norm360(moonGeocentricPosition(utc).$1 + dpsi);
      case PlanetId.mercury:
      case PlanetId.venus:
      case PlanetId.mars:
      case PlanetId.jupiter:
      case PlanetId.saturn:
      case PlanetId.uranus:
      case PlanetId.neptune:
        return _norm360(
          _toGeocentricLongitude(utc, (t) {
                final (l2, b2, r2) = _vsopHeliocentric(planet.name, t);
                return (l2, b2, r2);
              }) +
              dpsi,
        );
      case PlanetId.pluto:
        // Meeus ch.37 is J2000-referred while VSOP87D, the Sun and the
        // house frame are date-referred: precess Pluto into the mean
        // equinox of date, otherwise the geocentric longitude drifts by
        // the accumulated precession (0.16° for a 1988 birth).
        return _norm360(
          _toGeocentricLongitude(utc, (time) {
                final (l2, b2, r2) = plutoHeliocentricPosition(time);
                return (
                  _rad(l2 + _precessionInLongitude(julianCenturies(time))),
                  _rad(b2),
                  r2,
                );
              }) +
              dpsi,
        );
      case PlanetId.ascendant:
      case PlanetId.midheaven:
        throw ArgumentError(
          'computeEclipticLongitude expects a moving body, not ${planet.name}',
        );
    }
  }

  /// True when the planet is moving backward in ecliptic longitude
  /// (daily longitude delta < 0).
  static bool isRetrograde(PlanetId planet, DateTime utc) {
    final d1 = computeEclipticLongitude(planet, utc);
    final d2 = computeEclipticLongitude(
      planet,
      utc.add(const Duration(days: 1)),
    );
    return _difdeg2n(d2, d1) < 0;
  }

  // ---------------------------------------------------------------------
  // Moon phase
  // ---------------------------------------------------------------------

  /// Elongation-based moon phase snapshot (8 classical phases).
  static MoonPhase computeMoonPhase(DateTime utc) {
    const names = [
      'New Moon',
      'Waxing Crescent',
      'First Quarter',
      'Waxing Gibbous',
      'Full Moon',
      'Waning Gibbous',
      'Last Quarter',
      'Waning Crescent',
    ];
    const glyphs = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'];
    final sunLon = computeEclipticLongitude(PlanetId.sun, utc);
    final moonLon = computeEclipticLongitude(PlanetId.moon, utc);
    final elongation = _norm360(moonLon - sunLon);
    // Illuminated fraction: 0 at new moon (elongation 0°), 1 at full (180°).
    final illumination = (1 - math.cos(_rad(elongation))) / 2;
    final idx = ((elongation + 22.5) ~/ 45) % 8;
    return MoonPhase(
      name: names[idx],
      glyph: glyphs[idx],
      illumination: illumination,
      elongationDegrees: elongation,
      ageDays: elongation / 360.0 * 29.530588853,
    );
  }

  // ---------------------------------------------------------------------
  // Natal chart
  // ---------------------------------------------------------------------

  /// Compute a full natal chart: 10 planets + ASC/MC, house cusps,
  /// house placements and natal aspects.
  static NatalChart calculateNatalChart({
    required String id,
    required String profileName,
    required DateTime birthDateUtc,
    required int birthLocalYear,
    required int birthLocalMonth,
    required int birthLocalDay,
    required int birthLocalHour,
    required int birthLocalMinute,
    required bool timeKnown,
    required String cityName,
    required String country,
    required double latitude,
    required double longitude,
    required double timezoneOffsetHours,
    required HouseSystem houseSystem,
    DateTime? createdAt,
  }) {
    final cusps = computeHouseCusps(
      latitude: latitude,
      eastLongitude: longitude,
      utc: birthDateUtc,
      system: houseSystem,
    );
    final positions = <NatalPlanetPosition>[];
    for (final planet in PlanetId.values) {
      final double lon;
      if (planet == PlanetId.ascendant) {
        lon = ascendant(
          utc: birthDateUtc,
          latitude: latitude,
          eastLongitude: longitude,
        );
      } else if (planet == PlanetId.midheaven) {
        lon = midheaven(utc: birthDateUtc, eastLongitude: longitude);
      } else {
        lon = computeEclipticLongitude(planet, birthDateUtc);
      }
      final sign = ZodiacSignX.fromLongitude(lon);
      final house = _houseForLongitude(lon, cusps);
      positions.add(
        NatalPlanetPosition(
          planet: planet,
          longitude: lon,
          sign: sign,
          degreeInSign: lon - sign.index * 30.0,
          house: house,
          isRetrograde: planet.isBody && isRetrograde(planet, birthDateUtc),
          interpretation: _positionInterpretation(planet, sign, house),
        ),
      );
    }
    return NatalChart(
      id: id,
      profileName: profileName,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      birthDateUtc: birthDateUtc,
      birthLocalYear: birthLocalYear,
      birthLocalMonth: birthLocalMonth,
      birthLocalDay: birthLocalDay,
      birthLocalHour: birthLocalHour,
      birthLocalMinute: birthLocalMinute,
      timeKnown: timeKnown,
      cityName: cityName,
      country: country,
      latitude: latitude,
      longitude: longitude,
      timezoneOffsetHours: timezoneOffsetHours,
      houseSystem: houseSystem,
      houseCusps: cusps,
      planets: positions,
      aspects: computeAspects(positions),
    );
  }

  /// All natal aspects between the chart points, tightest orb first.
  static List<NatalAspect> computeAspects(List<NatalPlanetPosition> positions) {
    final aspects = <NatalAspect>[];
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final a = positions[i];
        final b = positions[j];
        var angle = (a.longitude - b.longitude).abs() % 360.0;
        if (angle > 180) angle = 360 - angle;
        for (final type in AspectType.values) {
          final deviation = (angle - type.baseAngle).abs();
          if (deviation <= type.maxOrb) {
            aspects.add(
              NatalAspect(
                bodyA: a.planet,
                bodyB: b.planet,
                type: type,
                exactAngle: angle,
                orb: deviation,
                strength: 1 - deviation / type.maxOrb,
                synthesis: _aspectSynthesis(a.planet, b.planet, type),
              ),
            );
          }
        }
      }
    }
    aspects.sort((x, y) => x.orb.compareTo(y.orb));
    return aspects;
  }

  /// Cross-chart aspects between two profiles (synastry): every point in
  /// [a] is paired against every point in [b], tightest orb first, with
  /// [NatalAspect.bodyA] always from profile A and [bodyB] from profile B.
  static List<NatalAspect> computeSynastryAspects(NatalChart a, NatalChart b) {
    final aspects = <NatalAspect>[];
    for (final pa in a.planets) {
      for (final pb in b.planets) {
        var angle = (pa.longitude - pb.longitude).abs() % 360.0;
        if (angle > 180) angle = 360 - angle;
        for (final type in AspectType.values) {
          final deviation = (angle - type.baseAngle).abs();
          if (deviation <= type.maxOrb) {
            aspects.add(
              NatalAspect(
                bodyA: pa.planet,
                bodyB: pb.planet,
                type: type,
                exactAngle: angle,
                orb: deviation,
                strength: 1 - deviation / type.maxOrb,
                synthesis: _aspectSynthesis(pa.planet, pb.planet, type),
              ),
            );
          }
        }
      }
    }
    aspects.sort((x, y) => x.orb.compareTo(y.orb));
    return aspects;
  }

  /// Elemental balance across both profiles' ten moving bodies — the basis
  /// of the synastry "compare our charts" elemental reading.
  static Map<Element, int> synastryElementBalance(NatalChart a, NatalChart b) {
    final balance = {for (final e in Element.values) e: 0};
    for (final p in [...a.planets, ...b.planets]) {
      if (p.planet.isBody) {
        balance[p.sign.element] = balance[p.sign.element]! + 1;
      }
    }
    return balance;
  }

  /// Instantly recompute house cusps & placements for another system —
  /// birth data is re-read from the chart, nothing else changes.
  static NatalChart recalculateWithHouseSystem(
    NatalChart chart,
    HouseSystem system,
  ) {
    final cusps = computeHouseCusps(
      latitude: chart.latitude,
      eastLongitude: chart.longitude,
      utc: chart.birthDateUtc,
      system: system,
    );
    final planets = [
      for (final p in chart.planets)
        NatalPlanetPosition(
          planet: p.planet,
          longitude: p.longitude,
          sign: p.sign,
          degreeInSign: p.degreeInSign,
          house: _houseForLongitude(p.longitude, cusps),
          isRetrograde: p.isRetrograde,
          interpretation: p.interpretation,
        ),
    ];
    return NatalChart(
      id: chart.id,
      profileName: chart.profileName,
      createdAt: chart.createdAt,
      birthDateUtc: chart.birthDateUtc,
      birthLocalYear: chart.birthLocalYear,
      birthLocalMonth: chart.birthLocalMonth,
      birthLocalDay: chart.birthLocalDay,
      birthLocalHour: chart.birthLocalHour,
      birthLocalMinute: chart.birthLocalMinute,
      timeKnown: chart.timeKnown,
      cityName: chart.cityName,
      country: chart.country,
      latitude: chart.latitude,
      longitude: chart.longitude,
      timezoneOffsetHours: chart.timezoneOffsetHours,
      houseSystem: system,
      houseCusps: cusps,
      planets: planets,
      aspects: chart.aspects,
    );
  }

  // ---------------------------------------------------------------------
  // Daily horoscope (live transits)
  // ---------------------------------------------------------------------

  /// The deterministic, non-fatalistic daily horoscope: today's sky
  /// (Sun..Saturn transits against the natal planets + ASC, Moon transit
  /// house, moon phase) summarized into a readable report.
  static DailyHoroscopeReport computeDailyHoroscope(
    NatalChart chart, {
    DateTime? forDate,
  }) {
    final date = (forDate ?? DateTime.now()).toUtc();
    final moonPhase = computeMoonPhase(date);
    final moonLon = computeEclipticLongitude(PlanetId.moon, date);
    final moonSign = ZodiacSignX.fromLongitude(moonLon);
    final moonHouse = _houseForLongitude(moonLon, chart.houseCusps);

    const transitBodies = [
      PlanetId.sun,
      PlanetId.moon,
      PlanetId.mercury,
      PlanetId.venus,
      PlanetId.mars,
      PlanetId.jupiter,
      PlanetId.saturn,
    ];
    final natalTargets = chart.planets
        .where((p) => p.planet.isBody || p.planet == PlanetId.ascendant)
        .toList();

    final candidates = <_TransitCandidate>[];
    for (final transit in transitBodies) {
      final tLon = computeEclipticLongitude(transit, date);
      for (final natal in natalTargets) {
        var angle = (tLon - natal.longitude).abs() % 360.0;
        if (angle > 180) angle = 360 - angle;
        for (final type in AspectType.values) {
          final deviation = (angle - type.baseAngle).abs();
          if (deviation <= type.maxOrb) {
            candidates.add(_TransitCandidate(transit, natal, type, deviation));
          }
        }
      }
    }
    candidates.sort((a, b) => a.orb.compareTo(b.orb));
    final top = candidates.take(5).toList();

    final transits = [
      for (final c in top)
        DailyTransitItem(
          title: '${c.transit.title} stirs your ${c.natal.planet.title}',
          transitLabel:
              'Transit ${c.transit.title} ${c.type.glyph} '
              'Natal ${c.natal.planet.title}',
          orb: c.orb,
          advice: _transitAdvice(c),
          harmony: c.type.harmony,
        ),
    ];

    final dominant = top.isEmpty
        ? AspectHarmony.harmonious
        : top.first.type.harmony;
    final theme = switch (dominant) {
      AspectHarmony.harmonious =>
        'A flowing day: ${moonPhase.name.toLowerCase()} favors gentle '
            'alignment, small steps and letting ease do the work.',
      AspectHarmony.tense =>
        'A day of friction with a purpose: '
            '${moonPhase.name.toLowerCase()} energy asks you to name the '
            'pressure and adjust one thing instead of fighting the weather.',
      AspectHarmony.intense =>
        'An intense day: ${moonPhase.name.toLowerCase()} concentrates '
            'energy — channel it into one deliberate act instead of '
            'letting it scatter.',
    };

    var score = 50.0;
    for (final c in top) {
      final strength = 1 - c.orb / c.type.maxOrb;
      switch (c.type.harmony) {
        case AspectHarmony.harmonious:
          score += strength * 12;
        case AspectHarmony.tense:
          score -= strength * 10;
        case AspectHarmony.intense:
          score += strength * 4;
      }
    }
    score += (moonPhase.illumination - 0.5) * 10;
    final energyScore = score.round().clamp(1, 100);

    return DailyHoroscopeReport(
      date: date,
      moonPhaseName: moonPhase.name,
      moonPhaseGlyph: moonPhase.glyph,
      moonIllumination: moonPhase.illumination,
      transitingMoonSign: moonSign,
      transitingMoonHouse: moonHouse,
      overallTheme: theme,
      energyScore: energyScore,
      transits: transits,
    );
  }

  // ---------------------------------------------------------------------
  // Interpretation texts (deterministic, grounded, non-fatalistic)
  // ---------------------------------------------------------------------

  static const List<String> _houseThemes = [
    'the self you present, the body and the first move',
    'resources, values and what you build with your hands',
    'communication, siblings and the everyday mind',
    'roots, home and the private foundation',
    'play, romance and creative self-expression',
    'work, health and daily service',
    'partnership, marriage and the mirror of the other',
    'intimacy, shared resources and deep transformation',
    'belief, travel and the search for wider meaning',
    'career, reputation and the public summit',
    'friends, community and the future you join',
    'solitude, endings and the inner sanctuary',
  ];

  /// The grounded theme of a natal house, 1..12 (clamped).
  static String houseTheme(int house) => _houseThemes[house.clamp(1, 12) - 1];

  static String _positionInterpretation(
    PlanetId planet,
    ZodiacSign sign,
    int house,
  ) {
    if (planet.isAngle) {
      return '${planet.title} in ${sign.title}: ${planet.archetype}, '
          'colored by ${sign.trait}.';
    }
    return '${planet.title} in ${sign.title}, house $house: '
        '${planet.archetype} expressed through ${sign.trait}; here it plays '
        'out in ${_houseThemes[house - 1]}.';
  }

  static String _aspectSynthesis(PlanetId a, PlanetId b, AspectType type) {
    return '${a.title} ${type.name} ${b.title}: ${type.dynamicLine} '
        'between ${a.archetype} and ${b.archetype}.';
  }

  static const Map<AspectHarmony, String> _harmonyAdvice = {
    AspectHarmony.harmonious:
        'Work with it gently: small consistent steps compound faster '
        'today than force.',
    AspectHarmony.tense:
        'Name the friction before it names you: adjust one concrete '
        'thing rather than resisting the pressure.',
    AspectHarmony.intense:
        'Channel the intensity into one deliberate act instead of '
        'letting it scatter.',
  };

  static String _transitAdvice(_TransitCandidate c) {
    return 'Let ${c.transit.title} touch your natal ${c.natal.planet.title}: '
        '${c.type.dynamicLine}. ${_harmonyAdvice[c.type.harmony]!}';
  }
}

/// One candidate transit pair (transiting body × natal point × aspect).
class _TransitCandidate {
  const _TransitCandidate(this.transit, this.natal, this.type, this.orb);

  final PlanetId transit;
  final NatalPlanetPosition natal;
  final AspectType type;
  final double orb;
}
