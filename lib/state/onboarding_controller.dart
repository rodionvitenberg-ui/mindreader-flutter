import 'package:flutter/foundation.dart';

import '../core/services/local_storage_service.dart';
import 'app_settings_controller.dart';

/// G3 — the one-time intro.
///
/// Deliberately tiny: it owns "has the reader seen the intro" plus the single
/// decision the intro is allowed to make (the starting detail level). Reading
/// aids stay opt-in — a beginner gets guidance switched on, an experienced
/// reader keeps the current switches untouched. Never blocks any feature.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.settings,
    LocalStorageService? storage,
  }) : _storage = storage ?? LocalStorageService() {
    initialLoad = _load();
  }

  final AppSettingsController settings;
  final LocalStorageService _storage;

  /// Completes once the persisted flag has been restored.
  late final Future<void> initialLoad;

  bool _completed = false;
  bool _loaded = false;
  bool _disposed = false;

  /// True once the reader finished or skipped the intro.
  bool get completed => _completed;

  /// False until [initialLoad] lands — the overlay must not flash meanwhile.
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      _completed = await _storage.loadOnboardingCompleted() ?? false;
    } catch (_) {
      // No preference store — treat this install as fresh.
    }
    _loaded = true;
    _notify();
  }

  /// Finishes the intro.
  ///
  /// [tarotFamiliar] is the answer to "have you worked with Tarot before?":
  /// * `false` — a beginner: thorough guidance, Guided Reading switched on;
  /// * `true`  — an experienced reader: concise hints, switches untouched;
  /// * `null`  — skipped: no reading setting is changed at all.
  Future<void> complete({bool? tarotFamiliar}) async {
    if (tarotFamiliar == false) {
      await settings.setGuideDetail(GuideDetail.thorough);
      await settings.setAid(ReadingAid.guide, true);
    } else if (tarotFamiliar == true) {
      await settings.setGuideDetail(GuideDetail.concise);
    }
    if (_completed) return;
    _completed = true;
    _notify();
    try {
      await _storage.saveOnboardingCompleted(true);
    } catch (_) {
      // The intro stays finished for this session only.
    }
  }

  /// "Replay the intro" from the settings — shows the flow again.
  Future<void> restart() async {
    if (!_completed) return;
    _completed = false;
    _notify();
    try {
      await _storage.saveOnboardingCompleted(false);
    } catch (_) {
      // Nothing persisted to clear.
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
