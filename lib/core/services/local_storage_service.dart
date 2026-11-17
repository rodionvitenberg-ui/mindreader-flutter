import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first spread history. No accounts, no cloud — the device is the
/// single store of truth.
class LocalStorageService {
  static const _historyKey = 'spread_history';
  static const _maxEntries = 50;

  static const _deckIdKey = 'active_deck_id';
  static const _lenormandPackKey = 'active_lenormand_pack_id';
  static const _runePackKey = 'active_rune_pack_id';
  static const _ritualEnabledKey = 'ritual_enabled';
  static const _ritualMorningKey = 'ritual_morning_minutes';
  static const _ritualEveningKey = 'ritual_evening_minutes';
  static const _readingDaysKey = 'reading_days';
  static const _sessionsKey = 'spread_sessions_v2';
  static const _maxSessions = 100;

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

  // ---- full-session archive (Sprint 2/3 — Pane 2 History & Notebooks) --

  /// Full reading sessions (cards + orientations + contexts + synthesis +
  /// chat dialog), newest first. 100% local JSON.
  Future<List<Map<String, dynamic>>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Upserts one session by its timestamp (identity), newest first.
  Future<void> upsertSession(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    final ts = entry['timestamp'] as String?;
    sessions.removeWhere((s) => s['timestamp'] == ts);
    sessions.insert(0, entry);
    if (sessions.length > _maxSessions) {
      sessions.removeRange(_maxSessions, sessions.length);
    }
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  Future<void> deleteAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  // ---- active deck packs (one per divination system) ----

  Future<String?> loadDeckId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deckIdKey);
  }

  Future<void> saveDeckId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deckIdKey, id);
  }

  Future<String?> loadLenormandPackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lenormandPackKey);
  }

  Future<void> saveLenormandPackId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lenormandPackKey, id);
  }

  Future<String?> loadRunePackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_runePackKey);
  }

  Future<void> saveRunePackId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_runePackKey, id);
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

