import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/dealt_card_slot.dart';
import '../models/oracle_payload.dart';
import '../models/oracle_personality.dart';
import 'oracle_synthesis_service.dart';

class OracleBackendException implements Exception {
  const OracleBackendException(this.code);

  final String code;
}

class OracleBackendService {
  OracleBackendService({String? baseUrl, http.Client? client})
    : _origin = Uri.tryParse((baseUrl ?? _configuredUrl).trim()),
      _http = client ?? http.Client();

  static const _configuredUrl = String.fromEnvironment('TAROT_BACKEND_URL');
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  final Uri? _origin;
  final http.Client _http;
  Future<String>? _credentialRequest;
  final _uncertainTurns = <(String, String, Object?), String>{};

  bool get isConfigured {
    final uri = _origin;
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    return uri.scheme == 'https' ||
        (uri.scheme == 'http' &&
            const {
              'localhost',
              '127.0.0.1',
              '::1',
              '10.0.2.2',
            }.contains(uri.host));
  }

  static String newOperationKey() {
    final random = Random.secure();
    return base64Url.encode(List.generate(18, (_) => random.nextInt(256)));
  }

  void dispose() => _http.close();

  String get _credentialKey => 'oracle_guest:${_origin!.origin}';

  Future<String> _token({required bool allowNewGuest}) async {
    if (!isConfigured) {
      throw const OracleBackendException('backend_unconfigured');
    }
    final saved = await _storage.read(key: _credentialKey);
    if (saved != null) {
      final credential = jsonDecode(saved) as Map<String, dynamic>;
      final expires = DateTime.tryParse(
        credential['expiresAt'] as String? ?? '',
      );
      if (expires != null && expires.isAfter(DateTime.now())) {
        return credential['token'] as String;
      }
    }
    // Issuing a new guest cannot recover an existing reading's ownership.
    if (!allowNewGuest) throw const OracleBackendException('guest_expired');
    return _credentialRequest ??= _issueGuest().whenComplete(() {
      _credentialRequest = null;
    });
  }

  Future<String> _issueGuest() async {
    final response = await _send('POST', 'auth/guest/');
    final credential = response as Map<String, dynamic>;
    final token = credential['token'] as String;
    await _storage.write(
      key: _credentialKey,
      value: jsonEncode({'token': token, 'expiresAt': credential['expiresAt']}),
    );
    return token;
  }

  Future<Object?> _send(
    String method,
    String path, {
    String? token,
    String? key,
    Map<String, Object?>? data,
  }) async {
    if (!isConfigured) {
      throw const OracleBackendException('backend_unconfigured');
    }
    final url = _origin!.resolve('/api/v1/$path');
    final encoded = data == null ? null : jsonEncode(data);
    for (var attempt = 0; ; attempt++) {
      final request = http.Request(method, url)..followRedirects = false;
      request.headers.addAll({
        'Accept': 'application/json',
        if (encoded != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'Idempotency-Key': ?key,
      });
      if (encoded != null) request.body = encoded;
      late final http.Response response;
      try {
        response = await _http
            .send(request)
            .then(http.Response.fromStream)
            .timeout(
              Duration(seconds: method == 'GET' || key == null ? 6 : 40),
            );
      } on TimeoutException {
        if (attempt == 0 && (key != null || method == 'GET')) continue;
        throw const OracleBackendException('connection_failed');
      } on http.ClientException {
        if (attempt == 0 && (key != null || method == 'GET')) continue;
        throw const OracleBackendException('connection_failed');
      }

      Object? payload;
      try {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (response.statusCode < 400) {
          throw const OracleBackendException('invalid_response');
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload;
      }
      final code = payload is Map ? payload['code'] : null;
      throw OracleBackendException(
        response.statusCode == 401
            ? 'guest_expired'
            : code is String
            ? code
            : 'backend_error',
      );
    }
  }

  Future<List<OraclePersonality>> personalities() async {
    final token = await _token(allowNewGuest: true);
    final items =
        await _send('GET', 'oracle/personalities/', token: token) as List;
    return items
        .cast<Map<String, dynamic>>()
        .map(OraclePersonality.fromJson)
        .toList();
  }

  Future<RemoteOracleReading> createReading({
    required OraclePersonality personality,
    required String clientSessionId,
    required Map<String, Object?> reading,
  }) async {
    final token = await _token(allowNewGuest: true);
    final result = await _send(
      'POST',
      'oracle/sessions/',
      token: token,
      key: 'reading:$clientSessionId',
      data: {
        ...reading,
        'clientSessionId': clientSessionId,
        'personality': personality.id,
      },
    ) as Map<String, dynamic>;
    if (result['personality'] != personality.id) {
      throw const OracleBackendException('personality_mismatch');
    }
    return RemoteOracleReading(
      sessionId: result['sessionId'] as String,
      personalityId: personality.id,
      personalityName: personality.name,
    );
  }

  Future<void> syncCards(
    RemoteOracleReading reading,
    List<DealtCardSlot> slots, {
    required int baseCount,
  }) async {
    final token = await _token(allowNewGuest: false);
    final id = reading.sessionId;
    final data = await _send(
      'GET',
      'oracle/sessions/$id/',
      token: token,
    ) as Map<String, dynamic>;
    if (data['personality'] != reading.personalityId) {
      throw const OracleBackendException('personality_mismatch');
    }
    final positions = (data['positions'] as List).cast<Map<String, dynamic>>();
    final confirmed = {
      for (final position in positions)
        if (position['card'] is Map)
          position['position'] as int: position['card'] as Map,
    };

    for (final slot in slots) {
      final card = slot.card;
      if (card == null || slot.state != SlotState.faceUp) {
        // Additional positions must arrive in order. Base positions already exist.
        if (slot.index >= baseCount) break;
        continue;
      }
      final cardId = canonicalCardId(card.system, card.id);
      final orientation = slot.isReversed ? 'reversed' : 'upright';
      final existing = confirmed[slot.index];
      if (existing != null) {
        if (existing['cardId'] != cardId ||
            existing['orientation'] != orientation) {
          throw const OracleBackendException('position_changed');
        }
        continue;
      }
      await _send(
        'POST',
        slot.fromPhysicalCard
            ? 'vision/confirm/'
            : 'oracle/sessions/$id/cards/',
        token: token,
        key: 'card:$id:${slot.index}',
        data: {
          if (slot.fromPhysicalCard) ...{'sessionId': id, 'action': 'manual'},
          'position': slot.index,
          'role': limitText(slot.role, 500),
          'cardId': cardId,
          'orientation': orientation,
          'clarifier': slot.index >= baseCount,
          if (slot.userContext case final note?) 'note': limitText(note, 2000),
        },
      );
    }
  }

  Future<StructuredSynthesis> synthesize(RemoteOracleReading reading) async {
    final data = await _turn(reading, 'synthesize');
    return StructuredSynthesis(
      narrative: data['narrative'] as String,
      elementalAlchemy: data['elementalAlchemy'] as String,
      verdict: data['verdict'] as String,
      followUp: data['followUp'] as String,
    );
  }

  Future<String> answer(
    RemoteOracleReading reading,
    String question, {
    int? position,
  }) async {
    final data = await _turn(
      reading,
      position == null ? 'messages' : 'clarifiers/$position',
      {'text': question},
    );
    return data['text'] as String;
  }

  Future<Map<String, dynamic>> _turn(
    RemoteOracleReading reading,
    String path, [
    Map<String, Object?>? data,
  ]) async {
    final token = await _token(allowNewGuest: false);
    final operation = (reading.sessionId, path, data?['text']);
    final key = _uncertainTurns.putIfAbsent(operation, newOperationKey);
    try {
      final response = await _send(
        'POST',
        'oracle/sessions/${reading.sessionId}/$path/',
        token: token,
        key: key,
        data: data,
      ) as Map<String, dynamic>;
      _uncertainTurns.remove(operation);
      return response;
    } on OracleBackendException catch (error) {
      if (!const {
        'connection_failed',
        'reading_busy',
        'operation_in_progress',
      }.contains(error.code)) {
        _uncertainTurns.remove(operation);
      }
      rethrow;
    }
  }

  static String limitText(String text, int characters) =>
      String.fromCharCodes(text.runes.take(characters));
}
