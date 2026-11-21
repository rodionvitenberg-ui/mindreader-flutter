import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/astro_cities_data.dart';

typedef BirthInstant = ({DateTime utc, Duration offset});

/// Resolves wall-clock time using the rules in effect on the birth date.
class BirthTimeService {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  /// Zero results indicate a skipped time. Two results indicate a repeated
  /// time; the user must choose the offset before the chart is calculated.
  static List<BirthInstant> resolve(AstroCity city, DateTime wallClock) {
    final local = DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    );
    final zone = city.timezoneId;
    if (zone == null) {
      final offset = Duration(
        seconds: (city.timezoneOffsetHours * 3600).round(),
      );
      return [(utc: local.subtract(offset), offset: offset)];
    }
    initialize();
    final location = tz.getLocation(zone);
    final candidates = <BirthInstant>[];
    for (final offset in location.zones.map((zone) => zone.offset).toSet()) {
      final instant = local.subtract(Duration(milliseconds: offset));
      if (location.timeZone(instant.millisecondsSinceEpoch).offset == offset) {
        candidates.add((utc: instant, offset: Duration(milliseconds: offset)));
      }
    }
    return candidates..sort((a, b) => a.utc.compareTo(b.utc));
  }

  static String offsetLabel(Duration offset) {
    final seconds = offset.inSeconds.abs();
    String pad(int value) => value.toString().padLeft(2, '0');
    final subminute = seconds % 60;
    return 'UTC${offset.isNegative ? '−' : '+'}'
        '${pad(seconds ~/ 3600)}:${pad(seconds ~/ 60 % 60)}'
        '${subminute == 0 ? '' : ':${pad(subminute)}'}';
  }
}
