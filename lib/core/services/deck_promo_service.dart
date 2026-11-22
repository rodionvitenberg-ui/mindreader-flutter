import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches backend-managed promo artwork URLs for built-in decks, rune sets,
/// and digital shop decks (`GET /api/v1/store/promos/`).
///
/// Keys in the returned map are `<system>:<packId>` (for example
/// `tarot:rider_waite` or `runes:nordic_bone`). Values are absolute image URLs
/// resolved against the configured backend origin.
class DeckPromoService {
  DeckPromoService({String? baseUrl, this.client})
    : _baseUrl = (baseUrl ?? _defaultBackendUrl).trim();

  static const _defaultBackendUrl = String.fromEnvironment('TAROT_BACKEND_URL');

  final String _baseUrl;
  final http.Client? client;

  bool get isConfigured {
    final uri = Uri.tryParse(_baseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Resolves all published promo artwork URLs from the backend. Returns `null`
  /// when the backend URL is unconfigured or unreachable so callers keep any
  /// previously cached URLs untouched.
  Future<Map<String, String>?> fetchPromoUrls({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isConfigured) return null;
    final origin = Uri.parse(_baseUrl);
    final ownClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final result = <String, String>{};
      Uri? next = origin.resolve('/api/v1/store/promos/');
      var pages = 0;
      while (next != null && pages < 10) {
        pages++;
        final response = await httpClient
            .get(next, headers: const {'Accept': 'application/json'})
            .timeout(timeout);
        if (response.statusCode != 200) return null;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return null;
        final items = decoded['results'];
        if (items is List) {
          for (final item in items) {
            if (item is! Map) continue;
            final system = item['system'];
            final packId = item['packId'];
            final rawUrl = item['url'];
            if (system is String &&
                packId is String &&
                rawUrl is String &&
                rawUrl.isNotEmpty) {
              result['$system:$packId'] = origin.resolve(rawUrl).toString();
            }
          }
        }
        final nextRaw = decoded['next'];
        next = nextRaw is String && nextRaw.isNotEmpty
            ? origin.resolve(nextRaw)
            : null;
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      if (ownClient) httpClient.close();
    }
  }
}
