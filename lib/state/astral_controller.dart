import 'package:flutter/foundation.dart';

import '../core/models/natal_chart.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/natal_calculator_service.dart';

/// Outcome of a chart-generation attempt.
enum AstralGenerateResult { generated, proGateBlocked }

/// ASTRAL Phase 2 — the single source of truth for saved natal profiles,
/// the free-tier cap, the PRO gate, the active house system and the cached
/// daily horoscope.
///
/// UI-first persistence (mirrors `SessionHistoryController`): every mutation
/// updates the in-memory state and calls [notifyListeners] FIRST, then pushes
/// the change to [LocalStorageService] in the background with every platform
/// error swallowed — widget tests never block on `SharedPreferences`.
class AstralController extends ChangeNotifier {
  AstralController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  /// Free tier: 2 saved natal profiles (e.g. Self + Partner).
  static const int maxFreeProfiles = 2;

  final LocalStorageService _storage;

  final List<NatalChart> _profiles = [];
  int _activeProfileIndex = 0;
  int _totalChartsGeneratedCount = 0;
  bool _isProUnlocked = false;
  HouseSystem _defaultHouseSystem = HouseSystem.placidus;
  DailyHoroscopeReport? _activeHoroscope;

  List<NatalChart> get profiles => List.unmodifiable(_profiles);

  NatalChart? get activeProfile {
    if (_profiles.isEmpty) return null;
    return _profiles[activeProfileIndex];
  }

  /// Index of the active profile, always clamped into range.
  int get activeProfileIndex => _profiles.isEmpty
      ? 0
      : _activeProfileIndex.clamp(0, _profiles.length - 1);

  int get totalChartsGeneratedCount => _totalChartsGeneratedCount;

  bool get isProUnlocked => _isProUnlocked;

  HouseSystem get activeHouseSystem =>
      activeProfile?.houseSystem ?? _defaultHouseSystem;

  DailyHoroscopeReport? get activeHoroscope => _activeHoroscope;

  /// Free tier allows 2 charts — the saved-profile count AND the lifetime
  /// generation count must stay under the cap. PRO is unlimited.
  bool canCreateOrGenerateChart() =>
      _isProUnlocked ||
      (_profiles.length < maxFreeProfiles &&
          _totalChartsGeneratedCount < maxFreeProfiles);

  /// Adds a freshly computed chart. A 3rd free-tier chart is refused: the
  /// profile list is left untouched and [AstralGenerateResult.proGateBlocked]
  /// is returned so the caller can open the paywall.
  AstralGenerateResult generateChart(NatalChart chart) {
    if (!canCreateOrGenerateChart()) {
      return AstralGenerateResult.proGateBlocked;
    }
    _profiles.add(chart);
    _activeProfileIndex = _profiles.length - 1;
    _totalChartsGeneratedCount++;
    _refreshHoroscope();
    notifyListeners();
    _persistProfiles();
    _persistGenerationCount();
    _persistActiveIndex();
    return AstralGenerateResult.generated;
  }

  /// Switches the active profile in one tap and re-targets the horoscope.
  void setActiveProfile(int index) {
    if (index < 0 || index >= _profiles.length) return;
    if (index == _activeProfileIndex) return;
    _activeProfileIndex = index;
    _refreshHoroscope();
    notifyListeners();
    _persistActiveIndex();
  }

  /// Instant in-place house-system switch on the active profile — always
  /// free and never counted against the generation quota.
  void setHouseSystem(HouseSystem system) {
    final profile = activeProfile;
    if (profile == null) {
      _defaultHouseSystem = system;
      notifyListeners();
      _persistHouseSystem(system);
      return;
    }
    if (profile.houseSystem == system) return;
    _profiles[activeProfileIndex] =
        NatalCalculatorService.recalculateWithHouseSystem(profile, system);
    _refreshHoroscope();
    notifyListeners();
    _persistProfiles();
    _persistHouseSystem(system);
  }

  /// Unlocks ASTRAL PRO (unlimited profiles, synastry, regeneration).
  void unlockPro() {
    if (_isProUnlocked) return;
    _isProUnlocked = true;
    notifyListeners();
    _persistPro();
  }

  /// Removes a saved profile. The lifetime generation counter is NOT
  /// decremented — deleting cannot reset the free-tier cap.
  void deleteProfile(int index) {
    if (index < 0 || index >= _profiles.length) return;
    _profiles.removeAt(index);
    if (_activeProfileIndex >= _profiles.length) {
      _activeProfileIndex = _profiles.isEmpty ? 0 : _profiles.length - 1;
    }
    _refreshHoroscope();
    notifyListeners();
    _persistProfiles();
    _persistActiveIndex();
  }

  /// Merges the on-disk snapshot into the live state. Non-destructive: the
  /// in-memory profiles are never cleared, so a fast first render is safe.
  Future<void> load() async {
    try {
      final fromDisk =
          (await _storage.loadAstralProfiles()).map(NatalChart.fromJson).toList();
      for (final chart in fromDisk) {
        if (!_profiles.any((p) => p.id == chart.id)) {
          _profiles.add(chart);
        }
      }
    } catch (_) {
      // Corrupt JSON / unavailable storage — keep the in-memory profiles.
    }
    try {
      final count = await _storage.loadAstralTotalChartsGenerated();
      if (count > _totalChartsGeneratedCount) {
        _totalChartsGeneratedCount = count;
      }
    } catch (_) {}
    try {
      if (await _storage.loadAstralProUnlocked()) {
        _isProUnlocked = true;
      }
    } catch (_) {}
    try {
      final index = await _storage.loadAstralActiveProfileIndex();
      if (_profiles.isNotEmpty && index >= 0 && index < _profiles.length) {
        _activeProfileIndex = index;
      }
    } catch (_) {}
    try {
      final name = await _storage.loadAstralHouseSystem();
      if (name != null && _profiles.isEmpty) {
        _defaultHouseSystem = HouseSystem.values.byName(name);
      }
    } catch (_) {}
    _refreshHoroscope();
    notifyListeners();
  }

  void _refreshHoroscope() {
    final profile = activeProfile;
    _activeHoroscope =
        profile == null ? null : NatalCalculatorService.computeDailyHoroscope(profile);
  }

  // ---- background persistence (fire-and-forget, errors swallowed) ----

  void _persistProfiles() {
    _storage
        .saveAstralProfiles([for (final p in _profiles) p.toJson()])
        .then((_) {}, onError: (Object _) {});
  }

  void _persistGenerationCount() {
    _storage
        .saveAstralTotalChartsGenerated(_totalChartsGeneratedCount)
        .then((_) {}, onError: (Object _) {});
  }

  void _persistActiveIndex() {
    _storage
        .saveAstralActiveProfileIndex(activeProfileIndex)
        .then((_) {}, onError: (Object _) {});
  }

  void _persistPro() {
    _storage
        .saveAstralProUnlocked(_isProUnlocked)
        .then((_) {}, onError: (Object _) {});
  }

  void _persistHouseSystem(HouseSystem system) {
    _storage
        .saveAstralHouseSystem(system.name)
        .then((_) {}, onError: (Object _) {});
  }
}
