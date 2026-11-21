import 'dart:math' as math;

import '../models/natal_chart.dart';
import 'natal_calculator_service.dart';

/// Finds active transits over a local calendar day. Positions are sampled
/// every three hours, then candidate minima and orb crossings are refined.
class TransitForecastService {
  static DailyHoroscopeReport forDay(NatalChart chart, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(
      day.year,
      day.month,
      day.day + 1,
    ).subtract(const Duration(milliseconds: 1));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    const step = Duration(hours: 3);
    final samples = [
      for (
        var instant = startMs;
        instant < endMs;
        instant += step.inMilliseconds
      )
        instant,
      endMs,
    ];
    final sky = <(PlanetId, int), double>{};
    double longitude(PlanetId body, int moment) => sky.putIfAbsent(
      (body, moment),
      () => NatalCalculatorService.computeEclipticLongitude(
        body,
        DateTime.fromMillisecondsSinceEpoch(moment, isUtc: true),
      ),
    );

    final matches = <_TransitMatch>[];
    for (final body in PlanetId.values.where((p) => p.isBody)) {
      for (final natal in chart.planets) {
        if (!chart.timeKnown &&
            (natal.planet == PlanetId.moon || natal.planet.isAngle)) {
          continue;
        }
        double separation(int time) {
          final angle = (longitude(body, time) - natal.longitude).abs();
          return math.min(angle, 360 - angle);
        }

        final angles = samples.map(separation).toList();
        for (final type in AspectType.values) {
          double orb(int time) => (separation(time) - type.baseAngle).abs();
          var closest = samples.first;
          for (var i = 0; i < samples.length; i++) {
            final sample = (angles[i] - type.baseAngle).abs();
            if (sample < orb(closest)) closest = samples[i];
            if (i == 0) continue;
            final previous = angles[i - 1] - type.baseAngle;
            final targets =
                type == AspectType.conjunction || type == AspectType.opposition
                ? [type.baseAngle]
                : [type.baseAngle, -type.baseAngle];
            for (final target in targets) {
              final exactLongitude = natal.longitude + target;
              double signedOrb(int time) =>
                  (longitude(body, time) - exactLongitude + 180) % 360 - 180;
              final before = signedOrb(samples[i - 1]);
              final after = signedOrb(samples[i]);
              if (before * after < 0 && (before - after).abs() < 180) {
                final crossing = _boundary(
                  samples[i - 1],
                  samples[i],
                  (time) => signedOrb(time) < 0,
                );
                if (orb(crossing) < orb(closest)) closest = crossing;
              }
            }
            if (i + 1 < samples.length &&
                sample <= previous.abs() &&
                sample <= (angles[i + 1] - type.baseAngle).abs() &&
                (sample < previous.abs() ||
                    sample < (angles[i + 1] - type.baseAngle).abs())) {
              final minimum = _minimum(samples[i - 1], samples[i + 1], orb);
              if (orb(minimum) < orb(closest)) closest = minimum;
            }
          }
          final distance = orb(closest);
          if (distance <= type.maxOrb) {
            matches.add((
              body: body,
              natal: natal.planet,
              type: type,
              closest: closest,
              distance: distance,
              orb: orb,
            ));
          }
        }
      }
    }
    matches.sort((a, b) => a.distance.compareTo(b.distance));
    return NatalCalculatorService.computeDailyHoroscope(
      chart,
      forDate: DateTime(day.year, day.month, day.day, 12),
      dayTransits: [for (final match in matches.take(5)) _describe(match)],
    );
  }

  static DailyTransitItem _describe(_TransitMatch match) {
    bool activeAt(int instant) => match.orb(instant) <= match.type.maxOrb;
    DateTime utc(int ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    DateTime? findEdge(int direction) {
      // Bound the search and keep samples closer together for faster bodies.
      final step =
          Duration(hours: match.body == PlanetId.moon ? 3 : 12).inMilliseconds *
          direction;
      final limit = const Duration(days: 366).inMilliseconds;
      var inside = match.closest;
      while ((inside - match.closest).abs() < limit) {
        final probe = inside + step;
        if (!activeAt(probe)) {
          final from = math.min(inside, probe);
          final until = math.max(inside, probe);
          return utc(_boundary(from, until, activeAt));
        }
        inside = probe;
      }
      return null;
    }

    return NatalCalculatorService.describeTransit(
      match.body,
      match.natal,
      match.type,
      match.distance,
      closestAt: utc(match.closest),
      activeFrom: findEdge(-1),
      activeUntil: findEdge(1),
    );
  }

  static int _boundary(int left, int right, bool Function(int) predicate) {
    final initial = predicate(left);
    while (right - left > 1000) {
      final mid = (left + right) ~/ 2;
      if (predicate(mid) == initial) {
        left = mid;
      } else {
        right = mid;
      }
    }
    return (left + right) ~/ 2;
  }

  static int _minimum(int left, int right, double Function(int) value) {
    while (right - left > 1000) {
      final a = left + (right - left) ~/ 3;
      final b = right - (right - left) ~/ 3;
      if (value(a) < value(b)) {
        right = b;
      } else {
        left = a;
      }
    }
    return (left + right) ~/ 2;
  }
}

typedef _TransitMatch = ({
  PlanetId body,
  PlanetId natal,
  AspectType type,
  int closest,
  double distance,
  double Function(int) orb,
});
