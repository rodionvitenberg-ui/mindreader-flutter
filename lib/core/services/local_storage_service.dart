import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first spread history. No accounts, no cloud — the device is the
/// single store of truth.
class LocalStorageService {
  static const _historyKey = 'spread_history';
  static const _maxEntries = 50;

  static const _deckIdKey = 'active_deck_id';
  static const _ritualEnabledKey = 'ritual_enabled';
  static const _ritualMorningKey = 'ritual_morning_minutes';
  static const _ritualEveningKey = 'ritual_evening_minutes';
  static const _readingDaysKey = 'reading_days';

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Newest first, capped at [_maxEntries].
  Future<void> saveSpread(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, entry);
    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  // ---- active deck pack ----

  Future<String?> loadDeckId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deckIdKey);
  }

  Future<void> saveDeckId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deckIdKey, id);
  }

  // ---- daily ritual (local notifications, zero server retention) ----

  Future<bool> loadRitualEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ritualEnabledKey) ?? false;
  }

  Future<void> saveRitualEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ritualEnabledKey, enabled);
  }

  Future<int> loadRitualMinutes(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? (key == _ritualMorningKey ? 540 : 1320);
  }

  Future<int> loadMorningMinutes() => loadRitualMinutes(_ritualMorningKey);
  Future<int> loadEveningMinutes() => loadRitualMinutes(_ritualEveningKey);

  Future<void> saveRitualMinutes(String key, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, minutes);
  }

  Future<void> saveMorningMinutes(int minutes) =>
      saveRitualMinutes(_ritualMorningKey, minutes);
  Future<void> saveEveningMinutes(int minutes) =>
      saveRitualMinutes(_ritualEveningKey, minutes);

  /// Records today as a day with a completed reading (streak counter).
  Future<void> recordReadingDay({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(_readingDaysKey) ?? <String>[];
    final key = _dayKey(now ?? DateTime.now());
    if (!days.contains(key)) {
      days.add(key);
      await prefs.setStringList(_readingDaysKey, days);
    }
  }

  Future<List<String>> loadReadingDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readingDaysKey) ?? const <String>[];
  }
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Consecutive reading days ending today (or yesterday, so a ritual due
/// later today does not break the streak). Pure and unit-testable.
int computeStreak(List<String> days, {DateTime? today}) {
  final set = days.toSet();
  var cursor = _normalized(today ?? DateTime.now());
  if (!set.contains(_dayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (set.contains(_dayKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _normalized(DateTime d) => DateTime(d.year, d.month, d.day);

