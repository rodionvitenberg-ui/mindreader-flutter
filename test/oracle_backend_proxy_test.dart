import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/voice/cloud_transcription_service.dart';

void main() {
  tearDown(() {
    OracleSynthesisService.registerBackendAuth(null);
    CloudTranscriptionService.registerBackendAuth(null);
  });

  group('OracleSynthesisService backend proxy', () {
    test('routes synthesis through Django /api/v1/oracle/complete/', () async {
      Uri? seenUri;
      String? seenAuth;
      Map<String, dynamic>? seenBody;

      final client = MockClient((req) async {
        seenUri = req.url;
        seenAuth = req.headers['Authorization'];
        seenBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'text': 'Server-proxied synthesis.', 'provider': 'env:gemini'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = OracleSynthesisService(
        client: client,
        backendAuthResolver: () async => ('https://api.example.test', 'tok-123'),
      );
      final slots = [
        DealtCardSlot(index: 0, role: 'Core')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck.first), false),
      ];

      final text = await service.synthesize(slots: slots, type: SpreadType.one);
      expect(text, 'Server-proxied synthesis.');
      expect(seenUri.toString(), 'https://api.example.test/api/v1/oracle/complete/');
      expect(seenAuth, 'Bearer tok-123');
      expect(seenBody?['kind'], 'synthesis');
    });

    test('propagates OracleQuotaExceededException on HTTP 429 quota_exceeded', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'code': 'quota_exceeded',
            'detail': 'Daily Oracle AI quota reached.',
            'limit': 15,
            'remaining': 0,
            'resetAt': '2026-11-27T00:00:00+00:00',
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = OracleSynthesisService(
        client: client,
        backendAuthResolver: () async => ('https://api.example.test', 'tok-123'),
      );
      final slots = [
        DealtCardSlot(index: 0, role: 'Core')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck.first), false),
      ];

      await expectLater(
        () => service.synthesize(slots: slots, type: SpreadType.one),
        throwsA(isA<OracleQuotaExceededException>()),
      );
    });
  });

  group('CloudTranscriptionService backend proxy', () {
    test('routes audio multipart to Django /api/v1/oracle/transcribe/', () async {
      Uri? seenUri;
      String? seenAuth;

      final client = MockClient((req) async {
        seenUri = req.url;
        seenAuth = req.headers['Authorization'];
        return http.Response(
          jsonEncode({'text': 'Что ждёт меня в новом проекте?'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = CloudTranscriptionService(
        client: client,
        backendAuthResolver: () async => ('https://api.example.test', 'tok-stt'),
        sttUrl: '',
        sttKey: '',
        cloudUrl: '',
        cloudKey: '',
      );

      expect(service.isConfigured, isTrue);
      final transcript = await service.transcribe(
        audioBytes: Uint8List.fromList([1, 2, 3, 4]),
        mimeType: 'audio/ogg',
        filename: 'note.ogg',
      );
      expect(transcript, 'Что ждёт меня в новом проекте?');
      expect(seenUri.toString(), 'https://api.example.test/api/v1/oracle/transcribe/');
      expect(seenAuth, 'Bearer tok-stt');
    });

    test('maps HTTP 429 to TranscriptionErrorKind.quotaExceeded', () async {
      final client = MockClient((_) async => http.Response('{"code":"quota_exceeded"}', 429));
      final service = CloudTranscriptionService(
        client: client,
        backendAuthResolver: () async => ('https://api.example.test', 'tok-stt'),
        sttUrl: '',
        sttKey: '',
        cloudUrl: '',
        cloudKey: '',
      );

      await expectLater(
        () => service.transcribe(
          audioBytes: Uint8List.fromList([1, 2, 3, 4]),
          mimeType: 'audio/mp4',
        ),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.kind,
            'kind',
            TranscriptionErrorKind.quotaExceeded,
          ),
        ),
      );
    });
  });
}
