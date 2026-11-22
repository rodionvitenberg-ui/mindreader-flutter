import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/divination_system.dart';
import '../core/models/store_models.dart';
import '../core/services/deck_package_installer.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/store_api_service.dart';
import 'backend_auth_controller.dart';
import 'deck_pack_controller.dart';

/// Orchestrates the in-app Digital Store:
/// - Fetches backend-published products ONLY (built-in decks are never shown).
/// - Keeps owned items in the catalog with `isOwned(product) == true`.
/// - Free gifts (`priceMinor == 0`): 1-tap `acquireFreeAndInstall`.
/// - Paid items (`priceMinor > 0`): generates a one-time handoff code and opens
///   `/shop/` on the promo website (`PROMO_SHOP_URL`), then auto-detects newly
///   purchased items when the user returns and downloads/installs them.
class StoreController extends ChangeNotifier {
  StoreController({
    required this.auth,
    required this.deckPacks,
    StoreApiService? api,
    DeckPackageInstaller? installer,
    LocalStorageService? storage,
    String? promoShopBaseUrl,
  })  : _api = api ?? StoreApiService(),
        _installer = installer ?? DeckPackageInstaller(),
        _storage = storage ?? LocalStorageService(),
        _promoShopBaseUrl = (promoShopBaseUrl ?? defaultPromoShopUrl).trim() {
    initialLoad = _restoreLocal();
  }

  static const defaultPromoShopUrl = String.fromEnvironment(
    'PROMO_SHOP_URL',
    defaultValue: 'https://soshallitbe.cyou',
  );

  late final Future<void> initialLoad;

  final BackendAuthController auth;
  final DeckPackController deckPacks;
  BackendAuthController get _auth => auth;
  DeckPackController get _deckPacks => deckPacks;
  final StoreApiService _api;
  final DeckPackageInstaller _installer;
  final LocalStorageService _storage;
  final String _promoShopBaseUrl;

  List<StoreProduct> _products = const [];
  final Set<String> _ownedIds = {};
  final Map<String, StoreInstallState> _installStates = {};
  final Set<String> _awaitingCheckoutIds = {};

  bool _loading = false;
  String? _error;
  DivinationSystem? _systemFilter;
  bool _ownedOnly = false;

  bool get isConfigured => _api.isConfigured;
  bool get loading => _loading;
  String? get error => _error;
  DivinationSystem? get systemFilter => _systemFilter;
  bool get ownedOnly => _ownedOnly;
  List<StoreProduct> get allProducts => _products;

  List<StoreProduct> get visibleProducts {
    return [
      for (final p in _products)
        if ((_systemFilter == null || p.system == _systemFilter) &&
            (!_ownedOnly || isOwned(p)))
          p,
    ];
  }

  StoreProduct? get featuredProduct {
    if (_systemFilter != null || _ownedOnly) return null;
    for (final p in _products) {
      if (p.featured) return p;
    }
    return null;
  }

  bool isOwned(StoreProduct product) =>
      product.owned ||
      _ownedIds.contains(product.id) ||
      _deckPacks.isInstalled(product.system, product.slug);

  bool isInstalled(StoreProduct product) =>
      _deckPacks.isInstalled(product.system, product.slug);

  bool isActive(StoreProduct product) =>
      _deckPacks.activeFor(product.system).id == product.slug;

  StoreInstallState installStateFor(String deckId) =>
      _installStates[deckId] ?? const StoreInstallState();

  bool get hasPendingWebCheckout => _awaitingCheckoutIds.isNotEmpty;

  void setSystemFilter(DivinationSystem? system) {
    if (_systemFilter == system) return;
    _systemFilter = system;
    notifyListeners();
  }

  void setOwnedOnly(bool value) {
    if (_ownedOnly == value) return;
    _ownedOnly = value;
    notifyListeners();
  }

  Future<void> _restoreLocal() async {
    try {
      final cachedOwned = await _storage.loadStoreOwnedIds();
      _ownedIds.addAll(cachedOwned);
    } catch (_) {}
    notifyListeners();
  }

  /// Fetches catalog + user library from Django.
  Future<void> refresh({bool autoInstallNewlyOwned = false}) async {
    if (!_api.isConfigured) {
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _auth.ensureToken();
      final catalog = await _api.fetchCatalog(token: token);
      final ownedNow = <String>{};
      for (final item in catalog) {
        if (item.owned) ownedNow.add(item.id);
      }
      if (token != null) {
        try {
          final lib = await _api.fetchLibrary(token);
          for (final item in lib) {
            ownedNow.add(item.id);
          }
        } catch (_) {
          // Keep catalog ownership if library request fails.
        }
      }
      _ownedIds
        ..clear()
        ..addAll(ownedNow);
      _products = [
        for (final item in catalog)
          item.copyWith(owned: ownedNow.contains(item.id)),
      ];
      unawaited(_storage.saveStoreOwnedIds(ownedNow).catchError((Object _) {}));

      // Auto-install any product the user just finished buying on the promo site!
      if (autoInstallNewlyOwned && _awaitingCheckoutIds.isNotEmpty) {
        final ready = <StoreProduct>[];
        for (final p in _products) {
          if (_awaitingCheckoutIds.contains(p.id) && isOwned(p)) {
            _awaitingCheckoutIds.remove(p.id);
            if (!isInstalled(p)) ready.add(p);
          }
        }
        notifyListeners();
        for (final p in ready) {
          unawaited(downloadAndInstall(p));
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<StoreProductDetail> fetchDetail(String slug) async {
    final token = _auth.token;
    return _api.fetchProductDetail(slug, token: token);
  }

  /// Claims a free gift product on Django, then downloads & installs it locally.
  Future<bool> claimFreeGift(StoreProduct product) async {
    if (!product.free) return false;
    _setInstallState(
      product.id,
      const StoreInstallState(stage: StoreInstallStage.claiming),
    );
    try {
      final token = await _auth.ensureToken();
      if (token == null) {
        throw Exception('Backend session unavailable.');
      }
      await _api.acquireFree(product.id, token: token);
      _ownedIds.add(product.id);
      _products = [
        for (final p in _products)
          p.id == product.id ? p.copyWith(owned: true) : p,
      ];
      unawaited(_storage.saveStoreOwnedIds(_ownedIds).catchError((Object _) {}));
      notifyListeners();
      return await downloadAndInstall(product.copyWith(owned: true));
    } catch (e) {
      _setInstallState(
        product.id,
        StoreInstallState(
          stage: StoreInstallStage.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  /// Downloads, verifies SHA-256, extracts into [PackAssetStore], and registers
  /// [product] in [DeckPackController] so it's immediately usable offline.
  Future<bool> downloadAndInstall(StoreProduct product) async {
    _setInstallState(
      product.id,
      const StoreInstallState(stage: StoreInstallStage.downloading, progress: 0),
    );
    try {
      final token = await _auth.ensureToken();
      if (token == null) {
        throw Exception('Authentication required to download.');
      }
      final downloadInfo = await _api.resolveDownload(
        product.id,
        token: token,
      );
      final bytes = await _api.downloadPackageBytes(
        downloadInfo,
        token: token,
        onProgress: (p) {
          _setInstallState(
            product.id,
            StoreInstallState(
              stage: StoreInstallStage.downloading,
              progress: p,
            ),
          );
        },
      );
      _setInstallState(
        product.id,
        const StoreInstallState(
          stage: StoreInstallStage.verifying,
          progress: 1.0,
        ),
      );
      final record = await _installer.verifyAndInstall(
        product: product,
        download: downloadInfo,
        zipBytes: bytes,
      );
      _setInstallState(
        product.id,
        const StoreInstallState(
          stage: StoreInstallStage.installing,
          progress: 1.0,
        ),
      );
      await _deckPacks.registerInstalledPack(record);
      _setInstallState(
        product.id,
        const StoreInstallState(
          stage: StoreInstallStage.installed,
          progress: 1.0,
        ),
      );
      return true;
    } catch (e) {
      _setInstallState(
        product.id,
        StoreInstallState(
          stage: StoreInstallStage.error,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  /// Builds the promo-website `/shop/` URL with a single-use handoff code so
  /// the user completes paid checkout on the website already signed in.
  Future<Uri> buildWebCheckoutUri(
    StoreProduct product, {
    String? returnUrl,
  }) async {
    final base = Uri.parse(
      _promoShopBaseUrl.isEmpty ? 'https://soshallitbe.cyou' : _promoShopBaseUrl,
    );
    final handoff = await _auth.createHandoffCode();
    final params = <String, String>{
      'deck': product.slug,
      if (handoff != null && handoff.isNotEmpty) 'handoff': handoff,
      if (returnUrl != null && returnUrl.isNotEmpty) 'return': returnUrl,
    };
    _awaitingCheckoutIds.add(product.id);
    _setInstallState(
      product.id,
      const StoreInstallState(stage: StoreInstallStage.awaitingWebCheckout),
    );
    return base.resolve('/shop/').replace(queryParameters: params);
  }

  Future<void> equip(StoreProduct product) async {
    if (!isInstalled(product)) return;
    await _deckPacks.setActiveFor(product.system, product.slug);
    notifyListeners();
  }

  Future<void> uninstallLocal(StoreProduct product) async {
    final record = _deckPacks.installedRecord(product.system, product.slug);
    if (record != null) {
      await _installer.uninstall(record);
    }
    await _deckPacks.unregisterInstalledPack(product.system, product.slug);
    _installStates.remove(product.id);
    notifyListeners();
  }

  void _setInstallState(String deckId, StoreInstallState state) {
    _installStates[deckId] = state;
    notifyListeners();
  }
}
