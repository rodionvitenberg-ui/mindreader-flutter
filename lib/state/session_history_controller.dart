import 'package:flutter/foundation.dart';

import '../core/l10n/app_strings.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/spread_check_in_service.dart';
import 'spread_controller.dart';
import 'spread_session_snapshot.dart';

/// Local-first archive of completed reading sessions — Pane 2 (Spread
/// History & Notebooks). One writer: this controller.
class SessionHistoryController extends ChangeNotifier {
  SessionHistoryController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;
  final List<SpreadSessionSnapshot> _sessions = [];
  bool loaded = false;
  int _defaultCheckInDays = SpreadCheckInService.defaultCadenceDays;
  bool _checkInDaysSetByUser = false;
  Future<void>? _initialLoad;

  /// Completes once the first [load] finishes (or immediately if not started).
  Future<void> get initialLoad => _initialLoad ?? Future<void>.value();

  List<SpreadSessionSnapshot> get sessions => List.unmodifiable(_sessions);

  /// Default check-in horizon in days (3, 7, or 14) for newly saved spreads.
  int get defaultCheckInDays => _defaultCheckInDays;

  void setDefaultCheckInDays(int days) {
    final normalized = SpreadCheckInService.normalizeCadence(days);
    _checkInDaysSetByUser = true;
    if (_defaultCheckInDays == normalized) return;
    _defaultCheckInDays = normalized;
    notifyListeners();
    _storage.saveCheckInDefaultDays(normalized).then(
      (_) {},
      onError: (Object _) {},
    );
  }

  SpreadSessionSnapshot? findByTimestamp(String timestamp) {
    for (final s in _sessions) {
      if (s.timestamp == timestamp) return s;
    }
    return null;
  }

  List<SpreadSessionSnapshot> dueCheckIns({DateTime? now}) =>
      SpreadCheckInService.dueSessions(_sessions, now: now);

  /// Closes (or snoozes, when [outcome] is [SpreadOutcome.stillUnfolding]) the
  /// Zeigarnik reality check-in loop for a saved spread.
  Future<void> saveReflection(
    String timestamp, {
    required SpreadOutcome outcome,
    String? note,
    DateTime? now,
  }) async {
    final existing = findByTimestamp(timestamp);
    if (existing == null) return;
    final ref = now ?? DateTime.now();
    final trimmed = note?.trim();
    final snooze = outcome == SpreadOutcome.stillUnfolding;
    final updated = existing.copyWith(
      outcome: outcome,
      reflectionNote: trimmed ?? existing.reflectionNote,
      reflectedAt: snooze ? null : ref.toIso8601String(),
      clearReflectedAt: snooze,
      checkInDueAt: snooze
          ? ref.add(Duration(days: _defaultCheckInDays)).toIso8601String()
          : existing.checkInDueAt,
      checkInDismissed: false,
    );
    await upsert(updated);
  }

  Future<void> dismissCheckIn(String timestamp) async {
    final existing = findByTimestamp(timestamp);
    if (existing == null) return;
    await upsert(existing.copyWith(checkInDismissed: true));
  }

  /// Loads the archive from the local store WITHOUT blocking the UI: the
  /// pane renders immediately and merges disk data in when it arrives
  /// (in-memory sessions captured meanwhile are never dropped).
  Future<void> load() {
    final future = _loadInternal();
    _initialLoad ??= future;
    return future;
  }

  Future<void> _loadInternal() async {
    loaded = true;
    notifyListeners();
    try {
      final storedDays = await _storage.loadCheckInDefaultDays();
      if (!_checkInDaysSetByUser) {
        _defaultCheckInDays = storedDays;
      }
      final raw = await _storage.loadSessions();
      final fromDisk = raw.map(SpreadSessionSnapshot.fromJson).toList();
      for (final s in fromDisk) {
        if (!_sessions.any((x) => x.timestamp == s.timestamp)) {
          _sessions.add(s);
        }
      }
      _sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (_) {
      // Corrupt JSON or unavailable storage — keep the in-memory archive.
    }
  }

  /// Upserts the captured session (identity = timestamp), newest first.
  /// The caller never waits on the local store — the write happens in the
  /// background.
  Future<void> upsert(SpreadSessionSnapshot snapshot) async {
    _sessions
      ..removeWhere((s) => s.timestamp == snapshot.timestamp)
      ..insert(0, snapshot);
    notifyListeners();
    _persist(snapshot);
  }

  void _persist(SpreadSessionSnapshot snapshot) {
    _storage.upsertSession(snapshot.toJson()).then(
      (_) {},
      onError: (Object _) {
        // Storage unavailable — the in-memory archive still works.
      },
    );
  }

  /// Merges an imported archive (device migration). Identity is the
  /// timestamp, exactly like [upsert] — an existing session is never
  /// duplicated, and the in-memory order stays newest-first.
  void restoreSessions(List<SpreadSessionSnapshot> imported) {
    var changed = false;
    for (final snapshot in imported) {
      if (_sessions.any((s) => s.timestamp == snapshot.timestamp)) continue;
      _sessions.add(snapshot);
      changed = true;
    }
    if (!changed) return;
    _sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
    for (final snapshot in imported) {
      _persist(snapshot);
    }
  }

  Future<void> deleteSession(String timestamp) async {
    _sessions.removeWhere((s) => s.timestamp == timestamp);
    notifyListeners();
    _storage.deleteSession(timestamp).then(
      (_) {},
      onError: (Object _) {},
    );
  }

  Future<void> deleteAll() async {
    _sessions.clear();
    notifyListeners();
    _storage.deleteAllSessions().then(
      (_) {},
      onError: (Object _) {
        // ignore: storage unavailable
      },
    );
  }

  /// Derives the thematic notebook from the reader's question and context notes.
  static String notebookFor(SpreadController ctrl) {
    final all = [
      if (ctrl.readingQuestion.trim().isNotEmpty) ctrl.readingQuestion.trim(),
      for (final s in ctrl.slots)
        if (s.userContext != null) s.userContext!,
      ...ctrl.sessionContextNotes,
    ].join(' ').toLowerCase();
    final relationship = AppStrings.g('history.keywords.relationship')
        .toLowerCase()
        .split('|');
    if (relationship.any(all.contains)) return 'relationships';
    final career = AppStrings.g('history.keywords.career').toLowerCase().split('|');
    if (career.any(all.contains)) return 'career';
    return 'all';
  }
}
