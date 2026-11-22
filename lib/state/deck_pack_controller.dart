import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/data/deck_packs_registry.dart';
import '../core/data/lenormand_packs_registry.dart';
import '../core/data/rune_packs_registry.dart';
import '../core/models/deck_pack.dart';
import '../core/models/divination_system.dart';
import '../core/models/lenormand_pack.dart';
import '../core/models/rune_pack.dart';
import '../core/models/tarot_deck_pack.dart';
import '../core/services/deck_promo_service.dart';
import '../core/services/local_storage_service.dart';

/// SSOT of the active pack for EVERY divination system (Digital Table,
/// Almanac, picker) plus backend-managed promo artwork URLs for both built-in
/// packs and future digital shop decks. Persists selections and cached promo
/// URLs via [LocalStorageService]; restores them on startup. Never throws —
/// unavailable storage or network falls back cleanly to local defaults.
class DeckPackController extends ChangeNotifier {
  DeckPackController({
    LocalStorageService? storage,
    DeckPromoService? promoService,
  }) : _storage = storage ?? LocalStorageService(),
       _promoService = promoService ?? DeckPromoService() {
    initialLoad = _restore();
  }

  /// Completes once the initial startup pack restore finishes.
  late final Future<void> initialLoad;

  final LocalStorageService _storage;
  final DeckPromoService _promoService;

  TarotDeckPack _pack = deckPacksRegistry.first;
  TarotDeckPack get activePack => _pack;

  LenormandPack _lenormandPack = lenormandPacksRegistry.first;
  LenormandPack get activeLenormandPack => _lenormandPack;

  RunePack _runePack = runePacksRegistry.first;
  RunePack get activeRunePack => _runePack;

  DeckPack activeFor(DivinationSystem system) => switch (system) {
    DivinationSystem.tarot => activePack,
    DivinationSystem.lenormand => activeLenormandPack,
    DivinationSystem.runes => activeRunePack,
  };

  final _promoUrls = <String, String>{};

  static String promoKey(DivinationSystem system, String packId) =>
      '${system.name}:$packId';

  /// Backend-managed promo banner URL for [pack], or null when none has been
  /// assigned on the backend yet.
  String? promoImageUrlFor(DivinationSystem system, DeckPack pack) =>
      _promoUrls[promoKey(system, pack.id)];

  /// Backend-managed promo banner URL by [system] and [packId] (works for both
  /// built-in packs and future digital shop decks).
  String? promoImageUrlForId(DivinationSystem system, String packId) =>
      _promoUrls[promoKey(system, packId)];

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
    try {
      final cached = await _storage.loadDeckPromoUrls();
      if (cached.isNotEmpty) {
        _promoUrls.addAll(cached);
      }
    } catch (_) {
      // Keep local fallback preview when cache is unavailable.
    }
    notifyListeners();
    if (_promoService.isConfigured) {
      unawaited(refreshPromos());
    }
  }

  /// Syncs backend-managed promo artwork URLs for all built-in decks, rune
  /// sets, and published digital shop decks, caching the result locally.
  Future<void> refreshPromos() async {
    final fetched = await _promoService.fetchPromoUrls();
    if (fetched == null) return;
    if (mapEquals(_promoUrls, fetched)) return;
    _promoUrls
      ..clear()
      ..addAll(fetched);
    notifyListeners();
    try {
      await _storage.saveDeckPromoUrls(fetched);
    } catch (_) {
      // In-memory promo URLs still apply for the current session.
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
