import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_mode.dart';

/// Local-first spread history. No accounts, no cloud — the device is the
/// single store of truth.
class LocalStorageService {
  static const _historyKey = 'spread_history';

  static const _deckPromoUrlsKey = 'deck_promo_urls_v1';
  static const _deckIdKey = 'active_deck_id';
  static const _lenormandPackKey = 'active_lenormand_pack_id';
  static const _runePackKey = 'active_rune_pack_id';
  static const _ritualEnabledKey = 'ritual_enabled';
  static const _ritualMorningKey = 'ritual_morning_minutes';
  static const _ritualEveningKey = 'ritual_evening_minutes';
  static const _readingDaysKey = 'reading_days';
  static const _sessionsKey = 'spread_sessions_v2';

  static const _astralProfilesKey = 'astral_profiles';
  static const _astralTotalChartsKey = 'astral_total_charts_generated';
  static const _astralProKey = 'astral_is_pro_unlocked';
  static const _astralActiveProfileKey = 'astral_active_profile_index';
  static const _astralHouseSystemKey = 'astral_default_house_system';

  // App settings (Iteration 2): UI language + the shared PRO flag.
  static const _appLanguageKey = 'app_language';
  static const _settingsSectionPrefix = 'settings_section.';
  static const _proUnlockedKey = 'is_pro_unlocked';

  // Digital Table view mode (Iteration 4): SPREAD VIEW is the default.
  static const _tableSpreadOverviewKey = 'table_view_spread';

  // Guided Reading memory (G1): the reader's detail level + every conceptual
  // lesson the mentor has already taught. Device-local, like everything else.
  static const _guideDetailKey = 'guide_detail';
  static const _guidedSeenKey = 'guided_seen_v1';

  // Onboarding (G3): the intro runs once per install until replayed.
  static const _onboardingCompletedKey = 'onboarding_completed_v1';

  // Camera reading mode (Phase 1): the last physical mode chosen in Camera.
  static const _cameraModeKey = 'camera_mode';

  static const _userProfileKey = 'user_profile_v1';
  static const _backendAuthSessionKey = 'backend_auth_session_v1';
  static const _installedStorePacksKey = 'installed_store_packs_v1';
  static const _storeOwnedIdsKey = 'store_owned_ids_v1';

  Future<bool?> loadReadingAid(String aid) async =>
      (await SharedPreferences.getInstance()).getBool('reading_aid.$aid');

  Future<void> saveReadingAid(String aid, bool value) async {
    await (await SharedPreferences.getInstance()).setBool('reading_aid.$aid', value);
  }

  Future<String?> loadGuideDetail() async =>
      (await SharedPreferences.getInstance()).getString(_guideDetailKey);

  Future<void> saveGuideDetail(String detail) async {
    await (await SharedPreferences.getInstance()).setString(_guideDetailKey, detail);
  }

  /// Every conceptual lesson the mentor has already delivered. Missing storage
  /// reads as "nothing learned yet" — never as an error.
  Future<Set<String>> loadGuidedSeen() async {
    final ids = (await SharedPreferences.getInstance())
            .getStringList(_guidedSeenKey) ??
        const <String>[];
    return ids.toSet();
  }

  Future<void> saveGuidedSeen(Set<String> ids) async {
    await (await SharedPreferences.getInstance())
        .setStringList(_guidedSeenKey, ids.toList()..sort());
  }

  /// Null → the intro has never been finished on this device.
  Future<bool?> loadOnboardingCompleted() async =>
      (await SharedPreferences.getInstance()).getBool(_onboardingCompletedKey);

  Future<void> saveOnboardingCompleted(bool completed) async {
    await (await SharedPreferences.getInstance())
        .setBool(_onboardingCompletedKey, completed);
  }

  Future<Map<String, bool>> loadSettingsSections() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith(_settingsSectionPrefix) && prefs.get(key) is bool)
          key.substring(_settingsSectionPrefix.length): prefs.getBool(key)!,
    };
  }

  Future<void> saveSettingsSection(String section, bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_settingsSectionPrefix$section', expanded);
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Newest first, unlimited local storage.
  Future<void> saveSpread(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.insert(0, entry);
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
  /// Unlimited local storage — older sessions are never truncated.
  Future<void> upsertSession(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    final ts = entry['timestamp'] as String?;
    sessions.removeWhere((s) => s['timestamp'] == ts);
    sessions.insert(0, entry);
    await prefs.setString(_sessionsKey, jsonEncode(sessions));
  }

  Future<void> deleteAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
  }

  // ---- active deck packs (one per divination system) ----

  Future<Map<String, String>> loadDeckPromoUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deckPromoUrlsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveDeckPromoUrls(Map<String, String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deckPromoUrlsKey, jsonEncode(urls));
  }

  Future<Map<String, dynamic>?> loadBackendAuthSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backendAuthSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBackendAuthSession(Map<String, dynamic>? session) async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_backendAuthSessionKey);
    } else {
      await prefs.setString(_backendAuthSessionKey, jsonEncode(session));
    }
  }

  Future<List<Map<String, dynamic>>> loadInstalledStorePacks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installedStorePacksKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveInstalledStorePacks(List<Map<String, dynamic>> packs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installedStorePacksKey, jsonEncode(packs));
  }

  Future<Set<String>> loadStoreOwnedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storeOwnedIdsKey) ?? const <String>[]).toSet();
  }

  Future<void> saveStoreOwnedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storeOwnedIdsKey, ids.toList()..sort());
  }

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

  // ---- app settings: language + shared PRO subscription ----

  Future<String?> loadAppLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appLanguageKey);
  }

  Future<void> saveAppLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, code);
  }

  Future<bool> loadProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proUnlockedKey) ?? false;
  }

  Future<void> saveProUnlocked(bool unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proUnlockedKey, unlocked);
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

  // ---- ASTRAL natal profiles (Phase 2) ----

  /// Saved natal profiles, oldest first (JSON payloads).
  Future<List<Map<String, dynamic>>> loadAstralProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_astralProfilesKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveAstralProfiles(List<Map<String, dynamic>> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_astralProfilesKey, jsonEncode(profiles));
  }

  Future<int> loadAstralTotalChartsGenerated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_astralTotalChartsKey) ?? 0;
  }

  Future<void> saveAstralTotalChartsGenerated(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_astralTotalChartsKey, count);
  }

  Future<bool> loadAstralProUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_astralProKey) ?? false;
  }

  Future<void> saveAstralProUnlocked(bool unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_astralProKey, unlocked);
  }

  Future<int> loadAstralActiveProfileIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_astralActiveProfileKey) ?? 0;
  }

  Future<void> saveAstralActiveProfileIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_astralActiveProfileKey, index);
  }

  Future<String?> loadAstralHouseSystem() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_astralHouseSystemKey);
  }

  Future<void> saveAstralHouseSystem(String system) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_astralHouseSystemKey, system);
  }

  /// True when the Digital Table last rendered in SPREAD VIEW (default true).
  Future<bool> loadTableSpreadOverview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tableSpreadOverviewKey) ?? true;
  }

  Future<void> saveTableSpreadOverview(bool isSpread) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tableSpreadOverviewKey, isSpread);
  }

  // ---- camera reading mode (Phase 1 — Camera UI) ----

  /// Last chosen physical reading mode in the Camera. Returns null when
  /// nothing was saved yet (the caller owns the QUICK SCAN default) or when
  /// the stored name is no longer a valid mode.
  Future<ReadingMode?> loadCameraMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cameraModeKey);
    if (raw == null) return null;
    return ReadingMode.values.asNameMap()[raw];
  }

  Future<void> saveCameraMode(ReadingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cameraModeKey, mode.name);
  }

  // ---- Local-only user profile (Zero-Knowledge, device storage) ----

  /// The whole profile lives in ONE key so a write is atomic and the
  /// controller has exactly one decision point.
  Future<Map<String, dynamic>?> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userProfileKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveUserProfile(Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(json));
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

