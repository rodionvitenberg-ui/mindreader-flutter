import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import '../core/config/app_flags.dart';
import '../core/l10n/app_strings.dart';
import '../core/services/local_storage_service.dart';

enum ReadingAid { positions, guide, relationships }

/// How much teaching the Guided Reading mentor attaches to a hint.
///
/// * [concise] — only the next actionable step.
/// * [thorough] — the step plus the conceptual lesson for the moment (read
///   once per spread type; see `GuidedReadingController`).
enum GuideDetail { concise, thorough }

enum SettingsSection {
  account,
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
    AppStrings.setCurrent(_language);
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

  GuideDetail _guideDetail = GuideDetail.concise;
  bool _editedGuideDetail = false;
  GuideDetail get guideDetail => _guideDetail;

  Future<void> setGuideDetail(GuideDetail detail) async {
    if (_guideDetail == detail) return;
    _editedGuideDetail = true;
    _guideDetail = detail;
    notifyListeners();
    try {
      await _storage.saveGuideDetail(detail.name);
    } catch (_) { /* Keep the in-session choice when storage is unavailable. */ }
  }

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
          orElse: () => AppLanguage.fromCode(code),
        );
      }
    } catch (_) {
      // Storage unavailable — keep the default language.
    }
    // Always publish the resolved language, including the no-preference case,
    // so pure-Dart lookups never keep a language from an earlier test/session.
    AppStrings.setCurrent(_language);
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
      final detail = await _storage.loadGuideDetail();
      if (!_editedGuideDetail && detail != null) {
        _guideDetail = GuideDetail.values.firstWhere(
          (d) => d.name == detail,
          orElse: () => GuideDetail.concise,
        );
      }
    } catch (_) {
      // Keep the concise default when local preferences are unavailable.
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
    AppStrings.setCurrent(language);
    notifyListeners();
    _storage
        .saveAppLanguage(language.name)
        .then((_) {}, onError: (Object _) {});
    // Pure-Dart content (card names, generated horoscopes) resolves through
    // `AppStrings.current`, so a language switch must rebuild the whole tree.
    // `reassembleApplication` does that without losing Navigator state — the
    // user stays exactly where they toggled the language. Defer it until the
    // tap has fully settled (reassembling inside a pointer event trips the
    // gesture arena's `locked` assertion) and skip it under `flutter test`,
    // where each `pumpWidget` already builds a fresh tree.
    if (kIsWeb || Platform.environment['FLUTTER_TEST'] != 'true') {
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        try {
          WidgetsBinding.instance.reassembleApplication();
        } catch (_) {
          // A detached binding is harmless: the next navigation rebuilds.
        }
      });
    }
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
