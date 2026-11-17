import 'package:flutter/foundation.dart';

import '../core/data/deck_packs_registry.dart';
import '../core/models/tarot_deck_pack.dart';
import '../core/services/local_storage_service.dart';

/// SSOT of the active deck pack for the whole app (Digital Table, Almanac,
/// picker). Persists the selection via [LocalStorageService]; restores it
/// on startup. Never throws — an unavailable storage falls back to the
/// default pack.
class DeckPackController extends ChangeNotifier {
  DeckPackController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService() {
    _restore();
  }

  final LocalStorageService _storage;

  TarotDeckPack _pack = deckPacksRegistry.first;
  TarotDeckPack get activePack => _pack;

  Future<void> _restore() async {
    try {
      final id = await _storage.loadDeckId();
      final restored = id == null ? null : deckPackById(id);
      if (restored != null) {
        _pack = restored;
        notifyListeners();
      }
    } catch (_) {
      // Storage unavailable (tests, fresh install) — keep the default.
    }
  }

  Future<void> setActivePack(String id) async {
    final pack = deckPackById(id);
    if (pack == null || pack.id == _pack.id) return;
    _pack = pack;
    notifyListeners();
    try {
      await _storage.saveDeckId(id);
    } catch (_) {
      // Persistence is best-effort; the session selection still applies.
    }
  }
}
