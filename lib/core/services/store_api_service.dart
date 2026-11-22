import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/divination_system.dart';
import '../models/store_models.dart';
import 'backend_auth_service.dart';

/// HTTP client for Django `/api/v1/store/*`.
class StoreApiService {
  StoreApiService({String? baseUrl, this.client})
      : _baseUrl = (baseUrl ?? BackendAuthService.defaultBackendUrl).trim();

  final String _baseUrl;
  final http.Client? client;

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

  Map<String, String> _headers(String? token, {String? idempotencyKey}) => {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Idempotency-Key': ?idempotencyKey,
      };

  Never _throwFrom(http.Response res) {
    String detail = 'Store request failed (${res.statusCode})';
    String? code;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        if (decoded['detail'] is String) detail = decoded['detail'] as String;
        if (decoded['code'] is String) code = decoded['code'] as String;
      }
    } catch (_) {}
    throw BackendApiException(detail, code: code, statusCode: res.statusCode);
  }

  Future<List<StoreProduct>> fetchCatalog({
    String? token,
    DivinationSystem? system,
  }) async {
    if (!isConfigured) return const [];
    return _withClient((c) async {
      final out = <StoreProduct>[];
      var next = origin.resolve(
        system == null
            ? '/api/v1/store/decks/'
            : '/api/v1/store/decks/?system=${system.name}',
      );
      var pages = 0;
      while (pages < 10) {
        pages++;
        final res = await c
            .get(next, headers: _headers(token))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) _throwFrom(res);
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) break;
        final results = decoded['results'];
        if (results is List) {
          for (final item in results) {
            if (item is Map) {
              out.add(
                StoreProduct.fromJson(
                  Map<String, dynamic>.from(item),
                  origin: origin,
                ),
              );
            }
          }
        }
        final nextRaw = decoded['next'];
        if (nextRaw is String && nextRaw.isNotEmpty) {
          next = origin.resolve(nextRaw);
        } else {
          break;
        }
      }
      return out;
    });
  }

  Future<StoreProductDetail> fetchProductDetail(
    String slug, {
    String? token,
  }) async {
    return _withClient((c) async {
      final res = await c
          .get(
            origin.resolve('/api/v1/store/decks/${Uri.encodeComponent(slug)}/'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) _throwFrom(res);
      return StoreProductDetail.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        origin: origin,
      );
    });
  }

  Future<List<StoreProduct>> fetchLibrary(String token) async {
    if (!isConfigured) return const [];
    return _withClient((c) async {
      final out = <StoreProduct>[];
      var next = origin.resolve('/api/v1/store/library/');
      var pages = 0;
      while (pages < 10) {
        pages++;
        final res = await c
            .get(next, headers: _headers(token))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) _throwFrom(res);
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) break;
        final results = decoded['results'];
        if (results is List) {
          for (final item in results) {
            if (item is Map) {
              out.add(
                StoreProduct.fromJson(
                  Map<String, dynamic>.from(item),
                  origin: origin,
                ),
              );
            }
          }
        }
        final nextRaw = decoded['next'];
        if (nextRaw is String && nextRaw.isNotEmpty) {
          next = origin.resolve(nextRaw);
        } else {
          break;
        }
      }
      return out;
    });
  }

  Future<bool> acquireFree(String deckId, {required String token}) async {
    final key =
        'free-${deckId.substring(0, min(8, deckId.length))}-${DateTime.now().millisecondsSinceEpoch}';
    return _withClient((c) async {
      final res = await c
          .post(
            origin.resolve(
              '/api/v1/store/decks/${Uri.encodeComponent(deckId)}/acquire-free/',
            ),
            headers: _headers(token, idempotencyKey: key),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) _throwFrom(res);
      final decoded = jsonDecode(res.body);
      return decoded is Map && decoded['owned'] == true;
    });
  }

  Future<StoreDownloadInfo> resolveDownload(
    String deckId, {
    required String token,
    String appVersion = '0.1.0',
  }) async {
    return _withClient((c) async {
      final res = await c
          .get(
            origin.resolve(
              '/api/v1/store/decks/${Uri.encodeComponent(deckId)}/download/?appVersion=$appVersion',
            ),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) _throwFrom(res);
      return StoreDownloadInfo.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        origin: origin,
      );
    });
  }

  Future<Uint8List> downloadPackageBytes(
    StoreDownloadInfo info, {
    required String token,
    void Function(double progress)? onProgress,
  }) async {
    return _withClient((c) async {
      final req = http.Request('GET', Uri.parse(info.url))
        ..headers['Authorization'] = 'Bearer $token';
      final streamed = await c.send(req).timeout(const Duration(seconds: 60));
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw BackendApiException(
          body.isEmpty
              ? 'Package download failed (${streamed.statusCode})'
              : body,
          statusCode: streamed.statusCode,
        );
      }
      final total = streamed.contentLength ?? info.sizeBytes;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in streamed.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      onProgress?.call(1.0);
      return builder.takeBytes();
    });
  }
}
