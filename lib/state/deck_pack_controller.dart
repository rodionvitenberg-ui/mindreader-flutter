import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/data/deck_packs_registry.dart';
import '../core/data/lenormand_packs_registry.dart';
import '../core/data/rune_packs_registry.dart';
import '../core/models/deck_pack.dart';
import '../core/models/divination_system.dart';
import '../core/models/lenormand_pack.dart';
import '../core/models/rune_pack.dart';
import '../core/models/store_models.dart';
import '../core/models/tarot_deck_pack.dart';
import '../core/services/deck_promo_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/pack_asset_store.dart';
import '../core/services/rune_stone_asset_cache.dart';

/// SSOT of ALL available packs (built-in + store-installed) and the active pack
/// for EVERY divination system (Digital Table, Almanac, Deck Picker) plus
/// backend-managed promo artwork URLs. Persists selections, installed pack
/// metadata, and cached promo URLs via [LocalStorageService]; restores & hydrates
/// them on startup so installed store decks work offline.
class DeckPackController extends ChangeNotifier {
  DeckPackController({
    LocalStorageService? storage,
    DeckPromoService? promoService,
    PackAssetStore? assetStore,
  })  : _storage = storage ?? LocalStorageService(),
        _promoService = promoService ?? DeckPromoService(),
        _assetStoreOverride = assetStore {
    initialLoad = _restore();
  }

  /// Completes once the initial startup pack restore finishes.
  late final Future<void> initialLoad;

  final LocalStorageService _storage;
  final DeckPromoService _promoService;
  final PackAssetStore? _assetStoreOverride;

  PackAssetStore get _store => _assetStoreOverride ?? PackAssetStore.instance;

  final Map<String, InstalledPackRecord> _installedRecords = {};
  final List<TarotDeckPack> _installedTarot = [];
  final List<LenormandPack> _installedLenormand = [];
  final List<RunePack> _installedRunes = [];

  TarotDeckPack _pack = deckPacksRegistry.first;
  TarotDeckPack get activePack => _pack;

  LenormandPack _lenormandPack = lenormandPacksRegistry.first;
  LenormandPack get activeLenormandPack => _lenormandPack;

  RunePack _runePack = runePacksRegistry.first;
  RunePack get activeRunePack => _runePack;

  List<TarotDeckPack> get tarotPacks => [...deckPacksRegistry, ..._installedTarot];

  List<LenormandPack> get lenormandPacks => [
        ...lenormandPacksRegistry,
        ..._installedLenormand,
      ];

  List<RunePack> get runePacks => [...runePacksRegistry, ..._installedRunes];

  /// All selectable packs for [system] (built-in first, then store-installed).
  List<DeckPack> packsFor(DivinationSystem system) => switch (system) {
        DivinationSystem.tarot => tarotPacks,
        DivinationSystem.lenormand => lenormandPacks,
        DivinationSystem.runes => runePacks,
      };

  DeckPack activeFor(DivinationSystem system) => switch (system) {
        DivinationSystem.tarot => activePack,
        DivinationSystem.lenormand => activeLenormandPack,
        DivinationSystem.runes => activeRunePack,
      };

  static String _recordKey(DivinationSystem system, String slug) =>
      '${system.name}:$slug';

  bool isInstalled(DivinationSystem system, String slug) =>
      _installedRecords.containsKey(_recordKey(system, slug));

  InstalledPackRecord? installedRecord(DivinationSystem system, String slug) =>
      _installedRecords[_recordKey(system, slug)];

  List<InstalledPackRecord> get installedRecords =>
      List.unmodifiable(_installedRecords.values);

  TarotDeckPack? _findTarot(String id) {
    for (final p in tarotPacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  LenormandPack? _findLenormand(String id) {
    for (final p in lenormandPacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  RunePack? _findRune(String id) {
    for (final p in runePacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  final _promoUrls = <String, String>{};

  static String promoKey(DivinationSystem system, String packId) =>
      '${system.name}:$packId';

  String? promoImageUrlFor(DivinationSystem system, DeckPack pack) =>
      _promoUrls[promoKey(system, pack.id)];

  String? promoImageUrlForId(DivinationSystem system, String packId) =>
      _promoUrls[promoKey(system, packId)];

  Future<void> _restore() async {
    // 1. Restore installed store packs first so a previously selected store pack
    //    resolves immediately during startup.
    try {
      final rawList = await _storage.loadInstalledStorePacks();
      for (final raw in rawList) {
        final rec = InstalledPackRecord.fromJson(raw);
        if (rec == null) continue;
        await _store.hydratePack(rec.storeKey);
        _insertRecordInMemory(rec);
      }
    } catch (_) {
      // Storage unavailable — continue with built-in packs.
    }

    try {
      final id = await _storage.loadDeckId();
      final restored = id == null ? null : _findTarot(id);
      if (restored != null) _pack = restored;
    } catch (_) {}
    try {
      final id = await _storage.loadLenormandPackId();
      final restored = id == null ? null : _findLenormand(id);
      if (restored != null) _lenormandPack = restored;
    } catch (_) {}
    try {
      final id = await _storage.loadRunePackId();
      final restored = id == null ? null : _findRune(id);
      if (restored != null) _runePack = restored;
    } catch (_) {}
    try {
      final cached = await _storage.loadDeckPromoUrls();
      if (cached.isNotEmpty) {
        _promoUrls.addAll(cached);
      }
    } catch (_) {}

    notifyListeners();
    unawaited(RuneStoneAssetCache.instance.warmPack(_runePack));
    if (_promoService.isConfigured) {
      unawaited(refreshPromos());
    }
  }

  void _insertRecordInMemory(InstalledPackRecord record) {
    final key = _recordKey(record.system, record.slug);
    _installedRecords[key] = record;
    final pack = record.toDeckPack();
    switch (record.system) {
      case DivinationSystem.tarot:
        _installedTarot.removeWhere((p) => p.id == record.slug);
        _installedTarot.add(pack as TarotDeckPack);
        if (_pack.id == record.slug) _pack = pack;
      case DivinationSystem.lenormand:
        _installedLenormand.removeWhere((p) => p.id == record.slug);
        _installedLenormand.add(pack as LenormandPack);
        if (_lenormandPack.id == record.slug) _lenormandPack = pack;
      case DivinationSystem.runes:
        _installedRunes.removeWhere((p) => p.id == record.slug);
        _installedRunes.add(pack as RunePack);
        if (_runePack.id == record.slug) {
          _runePack = pack;
          unawaited(RuneStoneAssetCache.instance.warmPack(pack));
        }
    }
  }

  /// Registers a newly installed store pack in memory and persists the manifest.
  Future<void> registerInstalledPack(InstalledPackRecord record) async {
    await _store.hydratePack(record.storeKey);
    _insertRecordInMemory(record);
    notifyListeners();
    await _persistInstalled();
  }

  /// Removes a locally downloaded store pack (falls back to built-in default
  /// if it was active). Does not revoke server ownership.
  Future<void> unregisterInstalledPack(
    DivinationSystem system,
    String slug,
  ) async {
    final removed = _installedRecords.remove(_recordKey(system, slug));
    if (removed == null) return;
    switch (system) {
      case DivinationSystem.tarot:
        _installedTarot.removeWhere((p) => p.id == slug);
        if (_pack.id == slug) {
          _pack = deckPacksRegistry.first;
          unawaited(_storage.saveDeckId(_pack.id).catchError((Object _) {}));
        }
      case DivinationSystem.lenormand:
        _installedLenormand.removeWhere((p) => p.id == slug);
        if (_lenormandPack.id == slug) {
          _lenormandPack = lenormandPacksRegistry.first;
          unawaited(
            _storage.saveLenormandPackId(_lenormandPack.id).catchError((Object _) {}),
          );
        }
      case DivinationSystem.runes:
        _installedRunes.removeWhere((p) => p.id == slug);
        if (_runePack.id == slug) {
          _runePack = runePacksRegistry.first;
          unawaited(RuneStoneAssetCache.instance.warmPack(_runePack));
          unawaited(_storage.saveRunePackId(_runePack.id).catchError((Object _) {}));
        }
    }
    notifyListeners();
    await _persistInstalled();
  }

  Future<void> _persistInstalled() async {
    try {
      await _storage.saveInstalledStorePacks([
        for (final rec in _installedRecords.values) rec.toJson(),
      ]);
    } catch (_) {}
  }

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
    } catch (_) {}
  }

  Future<void> setActiveFor(DivinationSystem system, String id) =>
      switch (system) {
        DivinationSystem.tarot => setActivePack(id),
        DivinationSystem.lenormand => setActiveLenormandPack(id),
        DivinationSystem.runes => setActiveRunePack(id),
      };

  Future<void> setActivePack(String id) async {
    final pack = _findTarot(id);
    if (pack == null || pack.id == _pack.id) return;
    _pack = pack;
    notifyListeners();
    try {
      await _storage.saveDeckId(id);
    } catch (_) {}
  }

  Future<void> setActiveLenormandPack(String id) async {
    final pack = _findLenormand(id);
    if (pack == null || pack.id == _lenormandPack.id) return;
    _lenormandPack = pack;
    notifyListeners();
    try {
      await _storage.saveLenormandPackId(id);
    } catch (_) {}
  }

  Future<void> setActiveRunePack(String id) async {
    final pack = _findRune(id);
    if (pack == null || pack.id == _runePack.id) return;
    _runePack = pack;
    notifyListeners();
    unawaited(RuneStoneAssetCache.instance.warmPack(pack));
    try {
      await _storage.saveRunePackId(id);
    } catch (_) {}
  }
}
