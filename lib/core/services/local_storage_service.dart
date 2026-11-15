import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first spread history. No accounts, no cloud — the device is the
/// single store of truth.
class LocalStorageService {
  static const _historyKey = 'spread_history';
  static const _maxEntries = 50;

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
}
