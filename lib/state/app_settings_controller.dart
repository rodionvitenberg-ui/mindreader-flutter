import 'package:flutter/foundation.dart';

import '../core/config/app_flags.dart';
import '../core/l10n/app_strings.dart';
import '../core/services/local_storage_service.dart';

enum ReadingAid { positions, guide, relationships }

enum SettingsSection {
  personalContext,
  readingExperience,
  subscription,
  deviceMigration,
  language,
}

/// Iteration 2 — the single source of truth for the UI language and the
/// shared PRO subscription state.
///
/// UI-first persistence (mirrors [DeckPackController] / [AstralController]):
/// every mutation updates the in-memory state and calls [notifyListeners]
/// FIRST, then pushes the change to [LocalStorageService] in the background
/// with every platform error swallowed — widget tests never block on
/// `SharedPreferences`.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService() {
    initialLoad = load();
  }

  /// Completes once the initial startup preference restore finishes.
  late final Future<void> initialLoad;

  final LocalStorageService _storage;

  AppLanguage _language = AppLanguage.en;
  bool _isProUnlocked = false;

  final _aids = <ReadingAid, bool>{ReadingAid.positions: true};
  final _edited = <ReadingAid>{};
  bool enabled(ReadingAid aid) => _aids[aid] ?? false;

  Future<void> setAid(ReadingAid aid, bool value) async {
    _edited.add(aid);
    _aids[aid] = value;
    notifyListeners();
    try {
      await _storage.saveReadingAid(aid.name, value);
    } catch (_) { /* Keep the in-session preference when storage is unavailable. */ }
  }

  final _sectionExpansion = <SettingsSection, bool>{};
  final _editedSections = <SettingsSection>{};

  bool sectionExpanded(SettingsSection section) =>
      _sectionExpansion[section] ?? true;

  Future<void> setSectionExpanded(SettingsSection section, bool expanded) async {
    if (sectionExpanded(section) == expanded) return;
    _editedSections.add(section);
    _sectionExpansion[section] = expanded;
    notifyListeners();
    try {
      await _storage.saveSettingsSection(section.name, expanded);
    } catch (_) {
      // Retain the current layout if local preferences are unavailable.
    }
  }

  AppLanguage get language => _language;

  /// The shared PRO flag. When [kProRestrictionsEnabled] is false (pre-launch)
  /// every PRO gate reads `true` here, so all gated content is available while
  /// the persisted flag + `unlockPro()` remain untouched for the future.
  bool get isProUnlocked => kProRestrictionsEnabled ? _isProUnlocked : true;

  /// Restores the persisted language and PRO state. Non-destructive: an
  /// in-session choice made before the disk read lands is never cleared.
  Future<void> load() async {
    try {
      final code = await _storage.loadAppLanguage();
      if (code != null) {
        _language = AppLanguage.values.firstWhere(
          (l) => l.name == code,
          orElse: () => AppLanguage.en,
        );
      }
    } catch (_) {
      // Storage unavailable — keep the default language.
    }
    try {
      // Backward compatibility: PRO bought through the ASTRAL paywall before
      // the shared flag existed must keep the account unlocked.
      if (await _storage.loadProUnlocked() ||
          await _storage.loadAstralProUnlocked()) {
        _isProUnlocked = true;
      }
    } catch (_) {
      // Same: best-effort restore.
    }
    for (final aid in ReadingAid.values) {
      try {
        final saved = await _storage.loadReadingAid(aid.name);
        if (saved != null && !_edited.contains(aid)) _aids[aid] = saved;
      } catch (_) { /* Use the default on devices without a preference store. */ }
    }
    try {
      final sections = await _storage.loadSettingsSections();
      for (final section in SettingsSection.values) {
        final expanded = sections[section.name];
        if (expanded != null && !_editedSections.contains(section)) {
          _sectionExpansion[section] = expanded;
        }
      }
    } catch (_) {
      // Start with expanded sections on devices without a preference store.
    }
    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    _storage
        .saveAppLanguage(language.name)
        .then((_) {}, onError: (Object _) {});
  }

  /// Unlocks the shared PRO tier. Idempotent — the ProSubscriptionSheet
  /// calls it together with `AstralController.unlockPro()` so the existing
  /// ASTRAL gate stays in sync.
  void unlockPro() {
    if (_isProUnlocked) return;
    _isProUnlocked = true;
    notifyListeners();
    _storage.saveProUnlocked(true).then((_) {}, onError: (Object _) {});
  }
}
