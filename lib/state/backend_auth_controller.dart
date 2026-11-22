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
  bool _busy = false;
  String? _error;

  BackendAuthSession? get session => _session;
  bool get isConfigured => _service.isConfigured;
  bool get isAuthenticated => _session != null && !_session!.isExpired;
  bool get isVerified => isAuthenticated && _session!.verified;
  String? get email => isVerified ? _session?.email : null;
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

  /// Step 1 of email sign-in / registration. Returns `devCode` in dev mode if enabled.
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

  Future<void> signOut() async {
    final prev = _session;
    await _setSession(null);
    if (prev != null && isConfigured) {
      unawaited(_service.logout(prev.token));
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
