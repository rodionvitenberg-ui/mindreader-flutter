import 'dart:math' as math;
import 'dart:ui';

/// ASTRAL Phase 3 — pure natal-wheel geometry shared by the painter, the
/// widget hit-testing and the widget tests. No Flutter widgets here.

/// Zodiac ring outer radius inside a square canvas (4 px hairline margin).
double wheelRadius(Size size) => math.min(size.width, size.height) / 2 - 4;

/// Radial layout, as multiples of [wheelRadius]:
/// sign band `[wheelRingInnerFactor, 1.0]`, transit ring, house spoke reach,
/// house-number track, planet orbital track, aspect-chord circle, core.
const double wheelRingInnerFactor = 0.845;
const double wheelTransitFactor = 0.825;
const double wheelHouseOuterFactor = 0.79;
const double wheelHouseLabelFactor = 0.765;
const double wheelHouseNumberFactor = 0.70;
const double wheelPlanetFactor = 0.60;
const double wheelAspectFactor = 0.52;
const double wheelCoreFactor = 0.28;

/// Screen angle (radians) for an ecliptic longitude.
///
/// The Ascendant sits at the exact 9 o'clock left horizon (`pi`) and zodiac
/// degrees progress counter-clockwise — authentic chart geometry.
double chartScreenAngle(double longitude, double ascendantLongitude) =>
    math.pi + (longitude - ascendantLongitude) * math.pi / 180.0;

Offset pointOnCircle(Offset center, double radius, double angle) =>
    center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

/// Signed shortest delta `to - from` in radians, in (-pi, pi].
double shortestAngleDelta(double from, double to) {
  var delta = (to - from) % (2 * math.pi);
  if (delta > math.pi) delta -= 2 * math.pi;
  if (delta <= -math.pi) delta += 2 * math.pi;
  return delta;
}

/// Normalizes an ecliptic longitude into 0..360°.
double norm360(double degrees) {
  final value = degrees % 360.0;
  return value < 0 ? value + 360.0 : value;
}

/// Deterministic collision avoidance for the planet track: returns display
/// longitudes (same order as [longitudes]) keeping at least
/// [minSeparationDeg] between neighbours, preserving their order with the
/// smallest possible shift — conjunct planets never overlap their nodes.
List<double> resolveCollisions(
  List<double> longitudes, {
  double minSeparationDeg = 7.0,
}) {
  final n = longitudes.length;
  if (n < 2) return List.of(longitudes);

  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => longitudes[a].compareTo(longitudes[b]));

  // Unwrap onto a straight line anchored at the smallest longitude.
  final anchor = longitudes[order.first];
  final pos = <double>[
    for (final i in order) _unwrap(longitudes[i], anchor),
  ];

  void relax() {
    for (var k = 1; k < n; k++) {
      final floor = pos[k - 1] + minSeparationDeg;
      if (pos[k] < floor) pos[k] = floor;
    }
    // Close the ring: the last body must keep a gap with the first one.
    final ceiling = pos.first + 360.0 - minSeparationDeg;
    if (pos.last > ceiling) {
      final excess = pos.last - ceiling;
      for (var k = 0; k < n; k++) {
        pos[k] -= excess;
      }
      for (var k = 1; k < n; k++) {
        final floor = pos[k - 1] + minSeparationDeg;
        if (pos[k] < floor) pos[k] = floor;
      }
    }
  }

  // Two passes settle the wrap-around against the forward sweep.
  relax();
  relax();

  final out = List<double>.filled(n, 0);
  for (var k = 0; k < n; k++) {
    out[order[k]] = norm360(pos[k]);
  }
  return out;
}

/// Shortest-path interpolation of zodiac longitudes for the smooth house
/// morph (359° -> 2° sweeps 3° forward, never 357° back).
double lerpLongitude(double from, double to, double t) {
  final deltaDeg =
      shortestAngleDelta(_rad(from), _rad(to)) * 180.0 / math.pi;
  return norm360(from + deltaDeg * t);
}

/// Interpolates two 12-cusp lists for the live house morph.
List<double> lerpCusps(List<double> from, List<double> to, double t) {
  if (from.length != to.length) return List.of(to);
  return [
    for (var i = 0; i < to.length; i++) lerpLongitude(from[i], to[i], t),
  ];
}

double _unwrap(double value, double anchor) {
  var v = value;
  while (v - anchor > 180.0) {
    v -= 360.0;
  }
  while (v - anchor <= -180.0) {
    v += 360.0;
  }
  return v;
}

double _rad(double degrees) => degrees * math.pi / 180.0;
