import '../l10n/app_strings.dart';
import '../models/custom_spread.dart';
import '../models/natal_chart.dart';
import 'natal_calculator_service.dart';

/// Primary lunar syzygy phases supported by ritual notifications & spreads.
enum LunarPhase { newMoon, fullMoon }

/// One astronomical lunar phase peak (UTC).
class LunarPhaseEvent {
  const LunarPhaseEvent({
    required this.phase,
    required this.utcTime,
  });

  final LunarPhase phase;
  final DateTime utcTime;
}

/// Active or nearest upcoming New/Full Moon ritual window.
class LunarRitualWindow {
  const LunarRitualWindow({
    required this.phase,
    required this.peakUtc,
    required this.isActiveNow,
    required this.daysUntil,
  });

  final LunarPhase phase;
  final DateTime peakUtc;
  final bool isActiveNow;
  final int daysUntil;
}

/// Computes upcoming astronomical New Moon (elongation = 0°) and Full Moon
/// (elongation = 180°) instants offline using [NatalCalculatorService].
class LunarPhaseService {
  LunarPhaseService._();

  static double _signedElongationError(DateTime utc, double targetAngle) {
    final sun = NatalCalculatorService.computeEclipticLongitude(
      PlanetId.sun,
      utc,
    );
    final moon = NatalCalculatorService.computeEclipticLongitude(
      PlanetId.moon,
      utc,
    );
    var diff = (moon - sun - targetAngle) % 360.0;
    if (diff < 0) diff += 360.0;
    if (diff >= 180.0) diff -= 360.0;
    return diff;
  }

  /// Returns the next [count] astronomical occurrences of [phase] strictly
  /// after [fromUtc] (defaults to `DateTime.now().toUtc()`).
  static List<LunarPhaseEvent> upcoming(
    LunarPhase phase, {
    DateTime? fromUtc,
    int count = 6,
  }) {
    if (count <= 0) return const [];
    final target = phase == LunarPhase.newMoon ? 0.0 : 180.0;
    final events = <LunarPhaseEvent>[];
    var cursor = (fromUtc ?? DateTime.now()).toUtc();
    const step = Duration(hours: 12);
    const maxSteps = 1000; // > 500 days safety bound per phase search

    for (var i = 0; i < maxSteps && events.length < count; i++) {
      final next = cursor.add(step);
      final e0 = _signedElongationError(cursor, target);
      final e1 = _signedElongationError(next, target);
      if (e0 <= 0 && e1 > 0 && (e1 - e0).abs() < 180.0) {
        var lo = cursor.millisecondsSinceEpoch;
        var hi = next.millisecondsSinceEpoch;
        for (var iter = 0; iter < 30; iter++) {
          final mid = (lo + hi) ~/ 2;
          final em = _signedElongationError(
            DateTime.fromMillisecondsSinceEpoch(mid, isUtc: true),
            target,
          );
          if (em <= 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        final exact = DateTime.fromMillisecondsSinceEpoch(hi, isUtc: true);
        events.add(LunarPhaseEvent(phase: phase, utcTime: exact));
        // Synodic month is 29.27..29.83 days; jumping 25 days skips straight
        // to the approach window of the following cycle.
        cursor = exact.add(const Duration(days: 25));
      } else {
        cursor = next;
      }
    }
    return events;
  }

  /// Convenience helper for the very next occurrence of [phase].
  static LunarPhaseEvent? next(LunarPhase phase, {DateTime? fromUtc}) {
    final list = upcoming(phase, fromUtc: fromUtc, count: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Detects if [nowUtc] sits inside an active New Moon or Full Moon ritual
  /// window (±[halfWindow], default 36h around exact syzygy), otherwise returns
  /// the nearest upcoming New/Full Moon peak.
  static LunarRitualWindow currentOrNextWindow({
    DateTime? nowUtc,
    Duration halfWindow = const Duration(hours: 36),
  }) {
    final ref = (nowUtc ?? DateTime.now()).toUtc();
    final lookback = ref.subtract(halfWindow);
    final candidates = <LunarPhaseEvent>[
      for (final phase in LunarPhase.values)
        ...upcoming(phase, fromUtc: lookback, count: 1),
    ];
    for (final event in candidates) {
      if (event.utcTime.difference(ref).abs() <= halfWindow) {
        return LunarRitualWindow(
          phase: event.phase,
          peakUtc: event.utcTime,
          isActiveNow: true,
          daysUntil: 0,
        );
      }
    }
    final upcomingEvents = <LunarPhaseEvent>[
      for (final phase in LunarPhase.values)
        ...upcoming(phase, fromUtc: ref, count: 1),
    ]..sort((a, b) => a.utcTime.compareTo(b.utcTime));
    final nearest = upcomingEvents.first;
    final hours = nearest.utcTime.difference(ref).inHours;
    return LunarRitualWindow(
      phase: nearest.phase,
      peakUtc: nearest.utcTime,
      isActiveNow: false,
      daysUntil: (hours / 24.0).ceil().clamp(1, 30),
    );
  }

  /// Curated 3-card ritual spread for New Moon or Full Moon, built on top of
  /// [CustomSpreadConfig] so it launches directly on the Digital Table.
  static CustomSpreadConfig lunarSpreadFor(
    LunarPhase phase,
    AppLanguage lang,
  ) {
    return switch (phase) {
      LunarPhase.newMoon => CustomSpreadConfig.fromQuestions(
        name: AppStrings.t(lang, 'ritual.lunarRitual.newMoonName'),
        questions: [
          AppStrings.t(lang, 'ritual.lunarRitual.newMoonQ0'),
          AppStrings.t(lang, 'ritual.lunarRitual.newMoonQ1'),
          AppStrings.t(lang, 'ritual.lunarRitual.newMoonQ2'),
        ],
        compareNeighbors: true,
      ),
      LunarPhase.fullMoon => CustomSpreadConfig.fromQuestions(
        name: AppStrings.t(lang, 'ritual.lunarRitual.fullMoonName'),
        questions: [
          AppStrings.t(lang, 'ritual.lunarRitual.fullMoonQ0'),
          AppStrings.t(lang, 'ritual.lunarRitual.fullMoonQ1'),
          AppStrings.t(lang, 'ritual.lunarRitual.fullMoonQ2'),
        ],
        compareNeighbors: true,
      ),
    };
  }
}
