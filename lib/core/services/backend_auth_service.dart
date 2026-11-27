import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/store_models.dart';

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client for Django `/api/v1/auth/*` and `/api/v1/account/*`.
class BackendAuthService {
  BackendAuthService({String? baseUrl, this.client})
      : _baseUrl = (baseUrl ?? defaultBackendUrl).trim();

  static const defaultBackendUrl = String.fromEnvironment(
    'TAROT_BACKEND_URL',
    defaultValue: 'https://soshallitbe.cyou',
  );

  final String _baseUrl;
  final http.Client? client;

  String get baseUrl => _baseUrl;

  bool get isConfigured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Uri get origin => Uri.parse(_baseUrl);

  Future<T> _withClient<T>(Future<T> Function(http.Client c) fn) async {
    final own = client == null;
    final c = client ?? http.Client();
    try {
      return await fn(c);
    } finally {
      if (own) c.close();
    }
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    if (res.body.isEmpty) return const {};
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  Never _throwFrom(http.Response res) {
    final data = _decodeJson(res);
    throw BackendApiException(
      data['detail'] as String? ?? 'Request failed (${res.statusCode})',
      code: data['code'] as String?,
      statusCode: res.statusCode,
    );
  }

  Future<BackendPublicConfig> fetchPublicConfig() async {
    if (!isConfigured) return const BackendPublicConfig();
    return _withClient((c) async {
      final res = await c
          .get(
            origin.resolve('/api/v1/config/public/'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) _throwFrom(res);
      return BackendPublicConfig.fromJson(_decodeJson(res));
    });
  }

  Future<BackendAuthSession> createGuestSession() async {
    return _withClient((c) async {
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/guest/'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 201 && res.statusCode != 200) _throwFrom(res);
      final session = BackendAuthSession.fromJson(_decodeJson(res));
      if (session == null) {
        throw const BackendApiException('Invalid guest session response.');
      }
      return session;
    });
  }

  /// Registers a new account with name, email and password without requiring
  /// upfront email confirmation. Migrates guest free gifts if [guestToken] is supplied.
  Future<BackendAuthSession> register({
    required String name,
    required String email,
    required String password,
    String? receiptNumber,
    String? guestToken,
  }) async {
    return _withClient((c) async {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (guestToken != null && guestToken.isNotEmpty)
          'Authorization': 'Bearer $guestToken',
      };
      final cleanReceipt = receiptNumber?.trim();
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/register/'),
            headers: headers,
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim(),
              'password': password,
              if (cleanReceipt != null && cleanReceipt.isNotEmpty)
                'receiptNumber': cleanReceipt,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 201 && res.statusCode != 200) _throwFrom(res);
      final session = BackendAuthSession.fromJson(_decodeJson(res));
      if (session == null) {
        throw const BackendApiException('Invalid registration response.');
      }
      return session;
    });
  }

  /// Signs into an existing email+password account.
  Future<BackendAuthSession> loginWithPassword({
    required String email,
    required String password,
    String? guestToken,
  }) async {
    return _withClient((c) async {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (guestToken != null && guestToken.isNotEmpty)
          'Authorization': 'Bearer $guestToken',
      };
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/login/'),
            headers: headers,
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) _throwFrom(res);
      final session = BackendAuthSession.fromJson(_decodeJson(res));
      if (session == null) {
        throw const BackendApiException('Invalid login response.');
      }
      return session;
    });
  }

  /// Sends a one-time email verification code. Returns `devCode` in local dev
  /// mode when `AUTH_DEV_SHOW_CODE=true`, or `null` otherwise.
  Future<String?> startEmailVerification(String email) async {
    return _withClient((c) async {
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/email/start/'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 202 && res.statusCode != 200) _throwFrom(res);
      final data = _decodeJson(res);
      return data['devCode'] is String ? data['devCode'] as String : null;
    });
  }

  /// Verifies the one-time email code and returns a verified account session.
  /// Passing [guestToken] allows the server to migrate free gifts claimed as a guest.
  Future<BackendAuthSession> verifyEmailCode(
    String code, {
    String? guestToken,
  }) async {
    return _withClient((c) async {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (guestToken != null && guestToken.isNotEmpty)
          'Authorization': 'Bearer $guestToken',
      };
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/email/verify/'),
            headers: headers,
            body: jsonEncode({'token': code.trim()}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) _throwFrom(res);
      final session = BackendAuthSession.fromJson(_decodeJson(res));
      if (session == null) {
        throw const BackendApiException('Invalid verification response.');
      }
      return session;
    });
  }

  /// Creates a short-lived single-use handoff code so the user opens the promo
  /// website shop already signed into their verified account.
  Future<String> createHandoffCode(String bearerToken) async {
    return _withClient((c) async {
      final res = await c
          .post(
            origin.resolve('/api/v1/auth/handoff/'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 201 && res.statusCode != 200) _throwFrom(res);
      final code = _decodeJson(res)['code'];
      if (code is! String || code.isEmpty) {
        throw const BackendApiException('Invalid handoff response.');
      }
      return code;
    });
  }

  /// Fetches fresh account identity & live PRO subscription state from
  /// `GET /api/v1/account/me/`.
  Future<BackendAuthSession> fetchAccountMe(BackendAuthSession current) async {
    return _withClient((c) async {
      final res = await c
          .get(
            origin.resolve('/api/v1/account/me/'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${current.token}',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) _throwFrom(res);
      final data = _decodeJson(res);
      final proExpRaw = data['proExpiresAt'];
      return current.copyWithIdentity(
        verified: data['verified'] == true,
        email: data['email'] is String ? data['email'] as String : current.email,
        name: data['name'] is String ? data['name'] as String : current.name,
        emailConfirmed: data.containsKey('emailConfirmed')
            ? data['emailConfirmed'] == true
            : current.emailConfirmed,
        isPro: data['isPro'] == true,
        proPlan: data['proPlan'] is String ? data['proPlan'] as String : null,
        proExpiresAt: proExpRaw is String ? DateTime.tryParse(proExpRaw) : null,
        earlySupporterSlot: (data['earlySupporterSlot'] as num?)?.toInt(),
      );
    });
  }

  Future<void> logout(String bearerToken) async {
    try {
      await _withClient((c) async {
        await c
            .post(
              origin.resolve('/api/v1/auth/logout/'),
              headers: {'Authorization': 'Bearer $bearerToken'},
            )
            .timeout(const Duration(seconds: 5));
      });
    } catch (_) {
      // Best-effort revocation.
    }
  }

  /// Permanently deactivates the authenticated account and scrubs personal
  /// identifiers on the server (`DELETE /api/v1/account/me/`).
  Future<void> deleteAccount(String bearerToken) async {
    await _withClient((c) async {
      final res = await c
          .delete(
            origin.resolve('/api/v1/account/me/'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 204 && res.statusCode != 200) _throwFrom(res);
    });
  }
}
