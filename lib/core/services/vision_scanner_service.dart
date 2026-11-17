import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../data/tarot_deck_data.dart';
import '../models/tarot_card_model.dart';

class DetectedCard {
  final TarotCard card;
  final bool isReversed;
  const DetectedCard(this.card, this.isReversed);
}

/// Image compression + spread detection with a dual AI pipeline:
///
/// 1. PRIMARY — local/tunneled RTX 3080 worker: OpenAI/Ollama-compatible
///    vision endpoint (`PRIMARY_WORKER_URL` dart-define), 3500 ms timeout.
/// 2. FALLBACK — Gemini Flash cloud endpoint (`VISION_API_URL` /
///    `VISION_API_KEY`), used when the worker is offline, times out or
///    errors (PC off, power outage, …).
/// 3. OFFLINE SAFETY NET — deterministic local mock so the scan flow never
///    crashes without any network/key.
class VisionScannerService {
  VisionScannerService({http.Client? client})
      : _client = client ?? http.Client();

  static const primaryWorkerUrl = String.fromEnvironment('PRIMARY_WORKER_URL');
  static const primaryWorkerKey = String.fromEnvironment('PRIMARY_WORKER_KEY');
  static const primaryWorkerModel = String.fromEnvironment(
    'PRIMARY_WORKER_VISION_MODEL',
    defaultValue: 'qwen2.5vl',
  );
  static const cloudUrl = String.fromEnvironment('VISION_API_URL');
  static const cloudKey = String.fromEnvironment('VISION_API_KEY');
  static const cloudModel = String.fromEnvironment(
    'VISION_API_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static const primaryTimeout = Duration(milliseconds: 3500);
  static const cloudTimeout = Duration(seconds: 20);

  final http.Client _client;

  bool get hasPrimary => primaryWorkerUrl.isNotEmpty;
  bool get hasCloud => cloudUrl.isNotEmpty && cloudKey.isNotEmpty;
  bool get isMock => !hasPrimary && !hasCloud;

  /// Decodes and re-encodes the capture as a ≤[maxDim] px JPEG (quality 80).
  Future<Uint8List> compressJpeg(Uint8List bytes, {int maxDim = 1024}) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unreadable image bytes');
    }
    final target = decoded.width > maxDim || decoded.height > maxDim
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxDim : null,
            height: decoded.height > decoded.width ? maxDim : null,
            interpolation: img.Interpolation.cubic,
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(target, quality: 80));
  }

  /// Detects [cardCount] cards (card + orientation) in a compressed JPEG.
  /// Worker → Gemini Flash → offline mock. Only throws on invalid args.
  Future<List<DetectedCard>> detectSpread({
    required Uint8List jpeg,
    required int cardCount,
  }) async {
    if (cardCount < 1 || cardCount > tarotDeck.length) {
      throw ArgumentError.value(cardCount, 'cardCount', 'must be 1..78');
    }
    // 1) Local RTX 3080 worker first.
    if (hasPrimary) {
      try {
        return await _detectOpenAi(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryWorkerModel,
          timeout: primaryTimeout,
          jpeg: jpeg,
          cardCount: cardCount,
        );
      } catch (e) {
        // PC off / power outage / timeout / bad response — fall through.
        debugPrint('vision: primary worker unreachable '
            '(${e.runtimeType}), falling back to cloud');
      }
    }
    // 2) Gemini Flash cloud fallback.
    if (hasCloud) {
      try {
        return await _detectOpenAi(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          jpeg: jpeg,
          cardCount: cardCount,
        );
      } catch (e) {
        debugPrint('vision: cloud endpoint failed '
            '(${e.runtimeType}), offline mode');
      }
    }
    // 3) Offline deterministic safety net.
    return _mockDetect(jpeg, cardCount);
  }

  /// Deterministic per image: the same photo always yields the same spread.
  List<DetectedCard> _mockDetect(Uint8List jpeg, int cardCount) {
    var seed = 17;
    for (var i = 0; i < jpeg.length; i += 97) {
      seed = (seed * 31 + jpeg[i]) & 0x7fffffff;
    }
    final rng = Random(seed);
    final ids = List<int>.generate(tarotDeck.length, (i) => i)..shuffle(rng);
    return [
      for (var i = 0; i < cardCount; i++)
        DetectedCard(tarotDeck[ids[i]], rng.nextBool()),
    ];
  }

  /// OpenAI/Ollama-compatible chat-completions vision request. Never logs
  /// keys or image payloads (Zero-Knowledge).
  Future<List<DetectedCard>> _detectOpenAi({
    required String url,
    required String key,
    required String model,
    required Duration timeout,
    required Uint8List jpeg,
    required int cardCount,
  }) async {
    final b64 = base64Encode(jpeg);
    final cardNames = tarotDeck.map((c) => c.name).join(', ');
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (key.isNotEmpty) 'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'stream': false,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text': 'Detect exactly $cardCount Rider-Waite tarot cards in '
                        'this photo. Reply ONLY with a JSON array: '
                        '[{"name": "<card name>", "reversed": false}] using '
                        'only these names: $cardNames.',
                  },
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                  },
                ],
              },
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('vision endpoint responded ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    final content = (choices.first as Map)['message']['content'] as String;
    final match = RegExp(r'\[[\s\S]*\]').firstMatch(content);
    if (match == null) {
      throw const FormatException('No JSON array in vision response');
    }
    final list = jsonDecode(match.group(0)!) as List;
    final byName = {for (final c in tarotDeck) c.name: c};
    return [
      for (final entry in list.cast<Map<String, dynamic>>())
        DetectedCard(
          byName[entry['name']] ?? tarotDeck[0],
          entry['reversed'] == true,
        ),
    ];
  }
}
