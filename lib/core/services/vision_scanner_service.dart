import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../data/tarot_deck_data.dart';
import '../models/tarot_card_model.dart';

class DetectedCard {
  final TarotCard card;
  final bool isReversed;
  const DetectedCard(this.card, this.isReversed);
}

/// Image compression + spread detection.
///
/// Set `--dart-define=VISION_API_URL=... --dart-define=VISION_API_KEY=...`
/// to enable the OpenAI-compatible vision endpoint. Without them the service
/// runs a fast, deterministic offline mock — the full scan flow is testable
/// before any API keys exist.
class VisionScannerService {
  VisionScannerService({http.Client? client}) : _client = client ?? http.Client();

  static const apiUrl = String.fromEnvironment('VISION_API_URL');
  static const apiKey = String.fromEnvironment('VISION_API_KEY');

  final http.Client _client;

  bool get isMock => apiUrl.isEmpty || apiKey.isEmpty;

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
  Future<List<DetectedCard>> detectSpread({
    required Uint8List jpeg,
    required int cardCount,
  }) async {
    if (cardCount < 1 || cardCount > tarotDeck.length) {
      throw ArgumentError.value(cardCount, 'cardCount', 'must be 1..78');
    }
    if (isMock) return _mockDetect(jpeg, cardCount);
    return _remoteDetect(jpeg, cardCount);
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

  Future<List<DetectedCard>> _remoteDetect(
    Uint8List jpeg,
    int cardCount,
  ) async {
    final b64 = base64Encode(jpeg);
    final cardNames = tarotDeck.map((c) => c.name).join(', ');
    final response = await _client
        .post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
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
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Vision API responded ${response.statusCode}');
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
