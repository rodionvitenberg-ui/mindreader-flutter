import 'dart:convert';

import 'package:http/http.dart' as http;

import '../backend_auth_service.dart';
import 'store_iap_service.dart';

/// Payload contract for `POST /api/v1/payments/verify-store-receipt/`.
class StoreReceiptVerificationRequest {
  const StoreReceiptVerificationRequest({
    required this.provider,
    required this.productId,
    required this.receiptData,
    this.purchaseToken,
  });

  final StoreIapProvider provider;
  final String productId;
  final String receiptData;
  final String? purchaseToken;

  Map<String, dynamic> toJson() => {
    'provider': provider.wireName,
    'productId': productId,
    'receiptData': receiptData,
    if (purchaseToken != null && purchaseToken!.isNotEmpty)
      'purchaseToken': purchaseToken,
  };
}

/// Response model from `POST /api/v1/payments/verify-store-receipt/`.
class StoreReceiptVerificationResult {
  const StoreReceiptVerificationResult({
    required this.verified,
    required this.isPro,
    this.proPlan,
    this.proExpiresAt,
    this.detail,
  });

  final bool verified;
  final bool isPro;
  final String? proPlan;
  final DateTime? proExpiresAt;
  final String? detail;
}

/// Backend entitlement & store-receipt verification service.
///
/// Provides the client hook for `POST /api/v1/payments/verify-store-receipt/`
/// supporting `provider: 'samsung_iap' | 'huawei_iap'`.
class EntitlementsService {
  EntitlementsService({String? baseUrl, this.client})
    : _baseUrl = (baseUrl ?? BackendAuthService.defaultBackendUrl).trim();

  static const verifyStoreReceiptPath = '/api/v1/payments/verify-store-receipt/';

  final String _baseUrl;
  final http.Client? client;

  bool get isConfigured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Submits a native store purchase receipt to the Django backend for
  /// server-side verification and PRO entitlement activation.
  Future<StoreReceiptVerificationResult> verifyStoreReceipt({
    required StoreReceiptVerificationRequest request,
    required String bearerToken,
  }) async {
    if (!isConfigured || bearerToken.trim().isEmpty) {
      return const StoreReceiptVerificationResult(
        verified: false,
        isPro: false,
        detail: 'Backend entitlement verification is not configured.',
      );
    }

    final own = client == null;
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            Uri.parse(_baseUrl).resolve(verifyStoreReceiptPath),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 && res.statusCode != 201) {
        return StoreReceiptVerificationResult(
          verified: false,
          isPro: false,
          detail:
              data['detail'] as String? ??
              'Receipt verification failed (${res.statusCode})',
        );
      }
      final expRaw = data['proExpiresAt'];
      return StoreReceiptVerificationResult(
        verified: data['verified'] == true,
        isPro: data['isPro'] == true,
        proPlan: data['proPlan'] is String ? data['proPlan'] as String : null,
        proExpiresAt: expRaw is String ? DateTime.tryParse(expRaw) : null,
        detail: data['detail'] is String ? data['detail'] as String : null,
      );
    } catch (e) {
      return StoreReceiptVerificationResult(
        verified: false,
        isPro: false,
        detail: e.toString(),
      );
    } finally {
      if (own) c.close();
    }
  }

  static Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}
