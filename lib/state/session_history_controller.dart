import 'package:flutter/foundation.dart';

import '../core/services/local_storage_service.dart';
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

  List<SpreadSessionSnapshot> get sessions => List.unmodifiable(_sessions);

  /// Loads the archive from the local store WITHOUT blocking the UI: the
  /// pane renders immediately and merges disk data in when it arrives
  /// (in-memory sessions captured meanwhile are never dropped).
  Future<void> load() async {
    loaded = true;
    notifyListeners();
    try {
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

  /// Derives the thematic notebook from the reader's context chips/notes.
  static String notebookFor(SpreadController ctrl) {
    final all = [
      for (final s in ctrl.slots)
        if (s.userContext != null) s.userContext!,
      ...ctrl.sessionContextNotes,
    ].join(' ').toLowerCase();
    if (all.contains('relationship') || all.contains('love')) {
      return 'Relationships';
    }
    if (all.contains('career') ||
        all.contains('money') ||
        all.contains('crossroad') ||
        all.contains('path')) {
      return 'Career & Path';
    }
    return 'All Readings';
  }
}
