import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/store_models.dart';
import '../core/services/backend_auth_service.dart';
import '../core/services/local_storage_service.dart';

/// Manages the user's Django backend identity: silent guest session for free
/// gifts/downloads, seamless 2-step email sign-in/registration, and one-time
/// handoff codes for web checkout on the promo website.
class BackendAuthController extends ChangeNotifier {
  BackendAuthController({
    BackendAuthService? service,
    LocalStorageService? storage,
  })  : _service = service ?? BackendAuthService(),
        _storage = storage ?? LocalStorageService() {
    initialLoad = _restore();
  }

  late final Future<void> initialLoad;

  final BackendAuthService _service;
  final LocalStorageService _storage;

  BackendAuthSession? _session;
  ProOfferConfig _proOffer = const ProOfferConfig();
  bool _busy = false;
  String? _error;

  BackendAuthSession? get session => _session;
  ProOfferConfig get proOffer => _proOffer;
  bool get isConfigured => _service.isConfigured;
  bool get isAuthenticated => _session != null && !_session!.isExpired;
  bool get isVerified => isAuthenticated && _session!.verified;
  bool get isEmailConfirmed =>
      isAuthenticated && (_session?.emailConfirmed ?? false);
  bool get isPro => isAuthenticated && (_session?.isPro ?? false);
  String? get proPlan => isPro ? _session?.proPlan : null;
  DateTime? get proExpiresAt => isPro ? _session?.proExpiresAt : null;
  int? get earlySupporterSlot => _session?.earlySupporterSlot;
  String? get email => isVerified ? _session?.email : null;
  String? get displayName => isVerified ? _session?.name : null;
  String? get token => isAuthenticated ? _session!.token : null;
  bool get isBusy => _busy;
  String? get error => _error;

  Future<void> _restore() async {
    try {
      final raw = await _storage.loadBackendAuthSession();
      if (raw != null) {
        final parsed = BackendAuthSession.fromJson(raw);
        if (parsed != null && !parsed.isExpired) {
          _session = parsed;
        }
      }
    } catch (_) {
      // Ignore storage errors in tests / fresh installs.
    }
    notifyListeners();
  }

  /// Ensures we have at least a guest bearer token when the backend is configured.
  Future<String?> ensureToken() async {
    if (!isConfigured) return null;
    if (isAuthenticated) return _session!.token;
    try {
      final guest = await _service.createGuestSession();
      await _setSession(guest);
      return guest.token;
    } catch (_) {
      return null;
    }
  }

  /// Full email+password registration (no mandatory verification email).
  Future<BackendAuthSession> registerWithPassword({
    required String name,
    required String email,
    required String password,
    String? receiptNumber,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final guestToken =
          (_session != null && !_session!.verified && !_session!.isExpired)
              ? _session!.token
              : null;
      final created = await _service.register(
        name: name,
        email: email,
        password: password,
        receiptNumber: receiptNumber,
        guestToken: guestToken,
      );
      await _setSession(created);
      return created;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Signs in with email + password.
  Future<BackendAuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final guestToken =
          (_session != null && !_session!.verified && !_session!.isExpired)
              ? _session!.token
              : null;
      final signedIn = await _service.loginWithPassword(
        email: email,
        password: password,
        guestToken: guestToken,
      );
      await _setSession(signedIn);
      return signedIn;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Step 1 of email sign-in / optional email confirmation. Returns `devCode` in dev mode if enabled.
  Future<String?> startEmailSignIn(String email) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await _service.startEmailVerification(email);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Step 2 of email sign-in / registration. Migrates guest free gifts if present.
  Future<BackendAuthSession> verifyEmailCode(String code) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final guestToken =
          (_session != null && !_session!.verified && !_session!.isExpired)
              ? _session!.token
              : null;
      final verified = await _service.verifyEmailCode(
        code,
        guestToken: guestToken,
      );
      await _setSession(verified);
      return verified;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Issues a short-lived one-time code to open `/shop/` on the promo website
  /// already authenticated as the current verified account.
  Future<String?> createHandoffCode() async {
    if (!isVerified || !isConfigured) return null;
    return _service.createHandoffCode(_session!.token);
  }

  /// Refreshes the public Early Supporter offer (remaining slots out of 100).
  Future<ProOfferConfig> refreshProOffer() async {
    if (!isConfigured) return _proOffer;
    try {
      final cfg = await _service.fetchPublicConfig();
      _proOffer = cfg.proOffer;
      notifyListeners();
    } catch (_) {
      // Keep default/cached offer when offline.
    }
    return _proOffer;
  }

  /// Queries `GET /api/v1/account/me/` to refresh the account's live `isPro`
  /// entitlement after completing checkout on the promo website.
  Future<bool> refreshProStatus() async {
    if (!isVerified || !isConfigured || _session == null) return isPro;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _service.fetchAccountMe(_session!);
      await _setSession(updated);
      return updated.isPro;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final prev = _session;
    await _setSession(null);
    if (prev != null && isConfigured) {
      unawaited(_service.logout(prev.token));
    }
  }

  /// Permanently deletes/deactivates the user's cloud account and clears the
  /// local session token.
  Future<void> deleteAccount() async {
    final prev = _session;
    if (prev == null || !isConfigured) {
      await _setSession(null);
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _service.deleteAccount(prev.token);
      await _setSession(null);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _setSession(BackendAuthSession? next) async {
    _session = next;
    _error = null;
    notifyListeners();
    try {
      await _storage.saveBackendAuthSession(next?.toJson());
    } catch (_) {
      // Keep in-memory session even if storage fails.
    }
  }
}
