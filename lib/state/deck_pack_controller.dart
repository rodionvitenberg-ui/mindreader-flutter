import 'package:flutter/foundation.dart';

import '../core/data/deck_packs_registry.dart';
import '../core/data/lenormand_packs_registry.dart';
import '../core/data/rune_packs_registry.dart';
import '../core/models/lenormand_pack.dart';
import '../core/models/rune_pack.dart';
import '../core/models/tarot_deck_pack.dart';
import '../core/services/local_storage_service.dart';

/// SSOT of the active pack for EVERY divination system (Digital Table,
/// Almanac, picker). Persists each selection via [LocalStorageService];
/// restores them on startup. Never throws — an unavailable storage falls
/// back to the default pack.
class DeckPackController extends ChangeNotifier {
  DeckPackController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService() {
    _restore();
  }

  final LocalStorageService _storage;

  TarotDeckPack _pack = deckPacksRegistry.first;
  TarotDeckPack get activePack => _pack;

  LenormandPack _lenormandPack = lenormandPacksRegistry.first;
  LenormandPack get activeLenormandPack => _lenormandPack;

  RunePack _runePack = runePacksRegistry.first;
  RunePack get activeRunePack => _runePack;

  Future<void> _restore() async {
    try {
      final id = await _storage.loadDeckId();
      final restored = id == null ? null : deckPackById(id);
      if (restored != null) _pack = restored;
    } catch (_) {
      // Storage unavailable (tests, fresh install) — keep the default.
    }
    try {
      final id = await _storage.loadLenormandPackId();
      final restored = id == null ? null : lenormandPackById(id);
      if (restored != null) _lenormandPack = restored;
    } catch (_) {
      // Same: best-effort restore.
    }
    try {
      final id = await _storage.loadRunePackId();
      final restored = id == null ? null : runePackById(id);
      if (restored != null) _runePack = restored;
    } catch (_) {
      // Same: best-effort restore.
    }
    notifyListeners();
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

  Future<void> setActiveLenormandPack(String id) async {
    final pack = lenormandPackById(id);
    if (pack == null || pack.id == _lenormandPack.id) return;
    _lenormandPack = pack;
    notifyListeners();
    try {
      await _storage.saveLenormandPackId(id);
    } catch (_) {
      // Persistence is best-effort; the session selection still applies.
    }
  }

  Future<void> setActiveRunePack(String id) async {
    final pack = runePackById(id);
    if (pack == null || pack.id == _runePack.id) return;
    _runePack = pack;
    notifyListeners();
    try {
      await _storage.saveRunePackId(id);
    } catch (_) {
      // Persistence is best-effort; the session selection still applies.
    }
  }
}

