import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_flags.dart';
import '../core/models/reading_mode.dart';

/// Local-first daily quota tracker for Free vs PRO soft limits.
///
/// Free daily caps (reset automatically at local midnight):
/// - Quick Scan: 3 / day
/// - Guided Spread: 1 / day
/// - Live Oracle: 1 session / day
/// - Oracle thread dialogue: up to 3 user follow-up messages per reading
class DailyQuotaController extends ChangeNotifier {
  DailyQuotaController({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    initialLoad = load();
  }

  late final Future<void> initialLoad;

  static const int maxFreeQuickScans = 3;
  static const int maxFreeGuidedSpreads = 1;
  static const int maxFreeLiveOracleSessions = 1;
  static const int maxFreeOracleMessagesPerThread = 3;

  final DateTime Function() _clock;

  String _dayKey = '';
  int _quickScans = 0;
  int _guidedSpreads = 0;
  int _liveOracleSessions = 0;

  String _todayKey() {
    final now = _clock();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _ensureToday() {
    final today = _todayKey();
    if (_dayKey != today) {
      _dayKey = today;
      _quickScans = 0;
      _guidedSpreads = 0;
      _liveOracleSessions = 0;
    }
  }

  int limitFor(ReadingMode mode) => switch (mode) {
        ReadingMode.quickScan => maxFreeQuickScans,
        ReadingMode.guidedSpread => maxFreeGuidedSpreads,
        ReadingMode.liveOracle => maxFreeLiveOracleSessions,
        ReadingMode.standard => 9999,
      };

  int usedToday(ReadingMode mode) {
    _ensureToday();
    return switch (mode) {
      ReadingMode.quickScan => _quickScans,
      ReadingMode.guidedSpread => _guidedSpreads,
      ReadingMode.liveOracle => _liveOracleSessions,
      ReadingMode.standard => 0,
    };
  }

  int remainingToday(ReadingMode mode) {
    final rem = limitFor(mode) - usedToday(mode);
    return rem < 0 ? 0 : rem;
  }

  bool canUseCameraMode(ReadingMode mode, {required bool isPro}) {
    if (!kProRestrictionsEnabled || isPro || mode == ReadingMode.standard) {
      return true;
    }
    return usedToday(mode) < limitFor(mode);
  }

  bool canSendOracleMessage(int sentUserMessagesInThread, {required bool isPro}) {
    if (!kProRestrictionsEnabled || isPro) return true;
    return sentUserMessagesInThread < maxFreeOracleMessagesPerThread;
  }

  void recordCameraMode(ReadingMode mode) {
    if (mode == ReadingMode.standard) return;
    _ensureToday();
    switch (mode) {
      case ReadingMode.quickScan:
        _quickScans++;
      case ReadingMode.guidedSpread:
        _guidedSpreads++;
      case ReadingMode.liveOracle:
        _liveOracleSessions++;
      case ReadingMode.standard:
        return;
    }
    notifyListeners();
    _persist();
  }

  Future<void> load() async {
    final today = _todayKey();
    _dayKey = today;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDay = prefs.getString('daily_quota.day');
      if (savedDay == today) {
        _quickScans = prefs.getInt('daily_quota.quickScan') ?? 0;
        _guidedSpreads = prefs.getInt('daily_quota.guidedSpread') ?? 0;
        _liveOracleSessions = prefs.getInt('daily_quota.liveOracle') ?? 0;
      } else {
        _quickScans = 0;
        _guidedSpreads = 0;
        _liveOracleSessions = 0;
      }
    } catch (_) {
      // Keep in-memory counters if preferences are unavailable.
    }
    notifyListeners();
  }

  void _persist() {
    final day = _dayKey;
    final qs = _quickScans;
    final gs = _guidedSpreads;
    final lo = _liveOracleSessions;
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('daily_quota.day', day);
      await prefs.setInt('daily_quota.quickScan', qs);
      await prefs.setInt('daily_quota.guidedSpread', gs);
      await prefs.setInt('daily_quota.liveOracle', lo);
    }).then((_) {}, onError: (Object _) {});
  }
}
