import '../l10n/app_strings.dart';
import '../../state/spread_session_snapshot.dart';

/// Lifecycle state of a past spread's reality check-in (Zeigarnik journal).
enum CheckInStatus { none, upcoming, due, completed }

/// Pure, deterministic logic for "reality check-ins" on saved spreads
/// (3, 7, or 14 days after a reading). Zero network, zero Flutter dependency.
class SpreadCheckInService {
  SpreadCheckInService._();

  static const List<int> cadenceOptions = [3, 7, 14];
  static const int defaultCadenceDays = 7;

  static int normalizeCadence(int? days) =>
      cadenceOptions.contains(days) ? days! : defaultCadenceDays;

  /// Computes when a check-in becomes due for [snapshot], or null when the
  /// snapshot is not a divination spread with revealed cards.
  static DateTime? dueDateFor(SpreadSessionSnapshot snapshot) {
    if (snapshot.kind != SessionKind.divinationSpread) return null;
    if (snapshot.cards.isEmpty) return null;
    if (snapshot.checkInDueAt != null) {
      final explicit = DateTime.tryParse(snapshot.checkInDueAt!);
      if (explicit != null) return explicit;
    }
    final created = DateTime.tryParse(snapshot.timestamp);
    if (created == null) return null;
    final days = normalizeCadence(snapshot.checkInDays);
    return created.add(Duration(days: days));
  }

  static CheckInStatus statusFor(
    SpreadSessionSnapshot snapshot, {
    DateTime? now,
  }) {
    if (snapshot.kind != SessionKind.divinationSpread) {
      return CheckInStatus.none;
    }
    if (snapshot.cards.isEmpty) return CheckInStatus.none;
    if (snapshot.reflectedAt != null) return CheckInStatus.completed;
    if (snapshot.checkInDismissed) return CheckInStatus.none;
    final due = dueDateFor(snapshot);
    if (due == null) return CheckInStatus.none;
    final ref = now ?? DateTime.now();
    return !ref.isBefore(due) ? CheckInStatus.due : CheckInStatus.upcoming;
  }

  /// All spreads currently waiting for a calm reality check-in, newest due first.
  static List<SpreadSessionSnapshot> dueSessions(
    List<SpreadSessionSnapshot> sessions, {
    DateTime? now,
  }) {
    return [
      for (final s in sessions)
        if (statusFor(s, now: now) == CheckInStatus.due) s,
    ];
  }

  /// Calm localized prompt tuned to the elapsed time since the reading
  /// (3 days / 1 week / 2 weeks).
  static String promptFor(
    SpreadSessionSnapshot snapshot,
    AppLanguage lang, {
    DateTime? now,
  }) {
    final created = DateTime.tryParse(snapshot.timestamp);
    final ref = now ?? DateTime.now();
    final elapsedDays = created == null
        ? normalizeCadence(snapshot.checkInDays)
        : ref.difference(created).inDays;
    if (elapsedDays >= 12) {
      return AppStrings.t(lang, 'checkin.prompt.14d');
    }
    if (elapsedDays >= 6) {
      return AppStrings.t(lang, 'checkin.prompt.7d');
    }
    return AppStrings.t(lang, 'checkin.prompt.3d');
  }

  static String outcomeLabel(SpreadOutcome outcome, AppLanguage lang) =>
      AppStrings.t(lang, 'checkin.outcome.${outcome.name}');
}
