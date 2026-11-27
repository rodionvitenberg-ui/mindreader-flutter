import 'package:flutter/foundation.dart';

import '../core/services/local_storage_service.dart';

/// Device-local progress tracker for offline 2-minute micro-learning sessions.
class TrainingController extends ChangeNotifier {
  TrainingController({LocalStorageService? storage})
    : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  int sessionsCompleted = 0;
  int totalCorrect = 0;
  int totalAnswered = 0;
  final Set<String> _masteredCardKeys = <String>{};
  bool loaded = false;
  bool _disposed = false;
  Future<void>? _initialLoad;

  Future<void> get initialLoad => _initialLoad ?? Future<void>.value();

  Set<String> get masteredCardKeys => Set.unmodifiable(_masteredCardKeys);

  int get masteredCount => _masteredCardKeys.length;

  double get accuracy => totalAnswered == 0 ? 0.0 : totalCorrect / totalAnswered;

  Future<void> load() {
    final future = _loadInternal();
    _initialLoad ??= future;
    return future;
  }

  Future<void> _loadInternal() async {
    try {
      final raw = await _storage.loadTrainingStats();
      if (_disposed) return;
      if (raw != null) {
        sessionsCompleted =
            (raw['sessionsCompleted'] as int? ?? 0) > sessionsCompleted
            ? raw['sessionsCompleted'] as int
            : sessionsCompleted;
        totalCorrect = (raw['totalCorrect'] as int? ?? 0) > totalCorrect
            ? raw['totalCorrect'] as int
            : totalCorrect;
        totalAnswered = (raw['totalAnswered'] as int? ?? 0) > totalAnswered
            ? raw['totalAnswered'] as int
            : totalAnswered;
        final keys = (raw['mastered'] as List? ?? const []).cast<String>();
        _masteredCardKeys.addAll(keys);
      }
    } catch (_) {
      // Keep in-memory state if storage is unavailable.
    } finally {
      loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  void recordSession({
    required int correct,
    required int total,
    required Iterable<String> newlyMasteredKeys,
  }) {
    sessionsCompleted += 1;
    totalCorrect += correct;
    totalAnswered += total;
    _masteredCardKeys.addAll(newlyMasteredKeys);
    if (!_disposed) notifyListeners();
    _storage
        .saveTrainingStats({
          'sessionsCompleted': sessionsCompleted,
          'totalCorrect': totalCorrect,
          'totalAnswered': totalAnswered,
          'mastered': _masteredCardKeys.toList()..sort(),
        })
        .then((_) {}, onError: (Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
