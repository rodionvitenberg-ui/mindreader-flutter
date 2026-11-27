import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image/image.dart' as img;

import '../data/tarot_deck_data.dart';
import '../models/tarot_card_model.dart';

class DetectedCard {
  final TarotCard card;
  final bool isReversed;
  final double confidence;
  final List<double>? centerNorm;
  final bool isLandscape;

  const DetectedCard(
    this.card,
    this.isReversed, {
    this.confidence = 1.0,
    this.centerNorm,
    this.isLandscape = false,
  });
}

/// The CPU-bound half of [VisionScannerService.compressJpeg], run off the UI
/// thread (via `compute`) so a budget device does not drop a frame while a
/// full-resolution capture is decoded, resized and re-encoded.
Uint8List _compressJpegIsolate((Uint8List, int) args) {
  final (bytes, maxDim) = args;
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
  return Uint8List.fromList(img.encodeJpg(target, quality: 84));
}

/// Image compression + spread detection pipeline:
///
/// 0. SERVER PIPELINE (preferred) — Django `/api/v1/vision/scan-spread/`, which
///    runs `enginetaro` OpenCV quad detection + reading-order sorting + padded
///    perspective crops -> Cloud VLM (DeepSeek Vision / Gemini / OpenAI).
///    Keeps API keys 100% off the client.
/// 1. PRIMARY WORKER — optional local/tunneled OpenAI-compatible vision worker
///    (`PRIMARY_WORKER_URL` dart-define), 3500 ms timeout.
/// 2. DIRECT CLOUD FALLBACK — optional OpenAI-compatible VLM endpoint
///    (`VISION_API_URL` / `VISION_API_KEY`, e.g. DeepSeek `deepseek-flash`).
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
    defaultValue: 'deepseek-flash',
  );

  static const serverTimeout = Duration(seconds: 28);
  static const primaryTimeout = Duration(milliseconds: 3500);
  static const cloudTimeout = Duration(seconds: 25);

  final http.Client _client;

  bool get hasPrimary => !kIsWeb && primaryWorkerUrl.isNotEmpty;
  bool get hasCloud => !kIsWeb && cloudUrl.isNotEmpty && cloudKey.isNotEmpty;
  bool get isMock => !hasPrimary && !hasCloud;

  /// Decodes and re-encodes the capture as a <=[maxDim] px JPEG (quality 84).
  Future<Uint8List> compressJpeg(Uint8List bytes, {int maxDim = 1280}) =>
      compute(_compressJpegIsolate, (bytes, maxDim));

  /// Detects cards (card + upright/reversed orientation) in reading order
  /// (top-to-bottom rows, left-to-right).
  ///
  /// [mode] is `'quick_scan'`, `'guided_single'`, or `'live_oracle'`.
  /// [cardCount] is OPTIONAL: when omitted the engine reports however many
  /// cards are actually visible in the photograph.
  Future<List<DetectedCard>> detectSpread({
    required Uint8List jpeg,
    int? cardCount,
    String mode = 'quick_scan',
    String? backendBaseUrl,
    String? bearerToken,
  }) async {
    if (cardCount != null && (cardCount < 1 || cardCount > tarotDeck.length)) {
      throw ArgumentError.value(cardCount, 'cardCount', 'must be 1..78');
    }

    // 0) Preferred: Django server pipeline (enginetaro crops -> Cloud VLM).
    final cleanBase = backendBaseUrl?.trim() ?? '';
    final cleanToken = bearerToken?.trim() ?? '';
    if (cleanBase.isNotEmpty && cleanToken.isNotEmpty) {
      try {
        final serverCards = await _detectViaBackend(
          baseUrl: cleanBase,
          bearerToken: cleanToken,
          jpeg: jpeg,
          mode: mode,
          expectedCount: cardCount,
        );
        if (serverCards.isNotEmpty) return serverCards;
      } catch (e) {
        debugPrint(
          'vision: backend scan-spread unavailable '
          '(${e.runtimeType}), trying fallback pipeline',
        );
      }
    }

    // 1) Local worker fallback.
    if (hasPrimary) {
      try {
        final cards = await _detectOpenAi(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryWorkerModel,
          timeout: primaryTimeout,
          jpeg: jpeg,
          cardCount: cardCount,
          mode: mode,
        );
        if (cards.isNotEmpty) return cards;
      } catch (e) {
        debugPrint(
          'vision: primary worker unreachable '
          '(${e.runtimeType}), falling back to cloud',
        );
      }
    }

    // 2) Direct OpenAI-compatible Cloud VLM fallback (e.g. DeepSeek / Gemini).
    if (hasCloud) {
      try {
        final cards = await _detectOpenAi(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          jpeg: jpeg,
          cardCount: cardCount,
          mode: mode,
        );
        if (cards.isNotEmpty) return cards;
      } catch (e) {
        debugPrint(
          'vision: cloud endpoint failed '
          '(${e.runtimeType}), offline mode',
        );
      }
    }

    // 3) Offline deterministic safety net.
    return _mockDetect(jpeg, cardCount);
  }

  Future<List<DetectedCard>> _detectViaBackend({
    required String baseUrl,
    required String bearerToken,
    required Uint8List jpeg,
    required String mode,
    int? expectedCount,
  }) async {
    final uri = Uri.parse(baseUrl).resolve('/api/v1/vision/scan-spread/');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $bearerToken'
      ..fields['mode'] = mode;
    if (expectedCount != null) {
      req.fields['expectedCount'] = '$expectedCount';
    }
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        jpeg,
        filename: 'spread.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );
    final streamed = await _client.send(req).timeout(serverTimeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('backend scan-spread responded ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawCards = data['cards'];
    if (rawCards is! List) return const [];

    final out = <DetectedCard>[];
    for (final entry in rawCards) {
      if (entry is! Map<String, dynamic>) continue;
      final deckIdx = (entry['deckIndex'] as num?)?.toInt();
      TarotCard? card;
      if (deckIdx != null && deckIdx >= 0 && deckIdx < tarotDeck.length) {
        card = tarotDeck[deckIdx];
      } else {
        card = matchTarotCard(
          cardId: entry['cardId'] as String?,
          name: entry['name'] as String?,
        );
      }
      if (card == null) continue;
      final centerRaw = entry['centerNorm'];
      final center = centerRaw is List && centerRaw.length == 2
          ? <double>[
              (centerRaw[0] as num).toDouble(),
              (centerRaw[1] as num).toDouble(),
            ]
          : null;
      out.add(
        DetectedCard(
          card,
          entry['reversed'] == true || entry['orientation'] == 'reversed',
          confidence: (entry['confidence'] as num?)?.toDouble() ?? 0.9,
          centerNorm: center,
          isLandscape: entry['isLandscape'] == true,
        ),
      );
    }
    return out;
  }

  /// Deterministic per image: the same photo always yields the same spread.
  List<DetectedCard> _mockDetect(Uint8List jpeg, int? cardCount) {
    var seed = 17;
    for (var i = 0; i < jpeg.length; i += 97) {
      seed = (seed * 31 + jpeg[i]) & 0x7fffffff;
    }
    final rng = Random(seed);
    final ids = List<int>.generate(tarotDeck.length, (i) => i)..shuffle(rng);
    final count = cardCount ?? (seed % 3) + 1;
    return [
      for (var i = 0; i < count; i++)
        DetectedCard(tarotDeck[ids[i]], rng.nextBool(), confidence: 0.88),
    ];
  }

  /// OpenAI-compatible chat-completions vision request (works with DeepSeek
  /// Vision `deepseek-flash`, Gemini OpenAI-compat, GPT-4o-mini, Qwen2.5-VL).
  Future<List<DetectedCard>> _detectOpenAi({
    required String url,
    required String key,
    required String model,
    required Duration timeout,
    required Uint8List jpeg,
    int? cardCount,
    String mode = 'quick_scan',
  }) async {
    final b64 = base64Encode(jpeg);
    final catalog = [
      for (var i = 0; i < tarotDeck.length; i++) 'tarot:$i=${tarotDeck[i].name}',
    ].join(', ');
    final scopeInstruction = (mode == 'guided_single' || mode == 'live_oracle')
        ? 'Identify the SINGLE primary face-up Tarot card in focus in the center/foreground.'
        : (cardCount == null
              ? 'Detect EVERY face-up Tarot card visible in this photo in strict reading order (top-to-bottom rows, left-to-right within each row).'
              : 'Detect the face-up Tarot cards visible in this photo (around $cardCount expected; report only actually visible cards) in strict reading order (top-to-bottom rows, left-to-right).');

    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (key.isNotEmpty) 'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.0,
            'stream': false,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text':
                        '$scopeInstruction '
                        'For each card report its reading-order index (1..N), canonical cardId, English name, and orientation ("upright" or "reversed" if upside-down). '
                        'Reply ONLY with a valid JSON array sorted by index: '
                        '[{"index": 1, "cardId": "tarot:0", "name": "The Fool", "orientation": "upright", "confidence": 0.95}]. '
                        'Canonical catalog: $catalog.',
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
    final list = (jsonDecode(match.group(0)!) as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    list.sort((a, b) {
      final ai = (a['index'] as num?)?.toInt() ?? 999;
      final bi = (b['index'] as num?)?.toInt() ?? 999;
      return ai.compareTo(bi);
    });

    final out = <DetectedCard>[];
    for (final entry in list) {
      final card = matchTarotCard(
        cardId: entry['cardId'] as String?,
        name: entry['name'] as String?,
      );
      if (card == null) continue;
      final orient = (entry['orientation'] as String? ?? '').toLowerCase();
      final reversed = orient == 'reversed' ||
          orient == 'inverted' ||
          entry['reversed'] == true;
      out.add(
        DetectedCard(
          card,
          reversed,
          confidence: (entry['confidence'] as num?)?.toDouble() ?? 0.88,
          isLandscape: entry['isLandscape'] == true,
        ),
      );
    }
    return out;
  }

  /// Resolves a VLM-provided canonical ID (`tarot:17`) or fuzzy English card
  /// name (including deck synonyms like `Coins` -> `Pentacles` and Roman
  /// numerals) without ever silently defaulting unknown text to The Fool.
  static TarotCard? matchTarotCard({String? cardId, String? name}) {
    if (cardId != null) {
      final cid = cardId.trim().toLowerCase();
      if (cid.startsWith('tarot:')) {
        final idx = int.tryParse(cid.substring(6));
        if (idx != null && idx >= 0 && idx < tarotDeck.length) {
          return tarotDeck[idx];
        }
      }
    }
    if (name == null || name.trim().isEmpty) return null;

    String norm(String s) {
      var clean = s
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.startsWith('the ')) clean = clean.substring(4).trim();
      return clean;
    }

    final byNorm = <String, TarotCard>{
      for (final c in tarotDeck) norm(c.name): c,
      'judgment': tarotDeck[20],
      'judgement': tarotDeck[20],
      'fortitude': tarotDeck[8],
      'wheel': tarotDeck[10],
      'universe': tarotDeck[21],
    };

    const aliases = <String, String>{
      'coins': 'pentacles',
      'coin': 'pentacles',
      'disks': 'pentacles',
      'disk': 'pentacles',
      'discs': 'pentacles',
      'rods': 'wands',
      'staves': 'wands',
      'chalices': 'cups',
      'goblets': 'cups',
      'blades': 'swords',
      'knave': 'page',
      'princess': 'page',
      'prince': 'knight',
      '1': 'ace',
      '2': 'two',
      '3': 'three',
      '4': 'four',
      '5': 'five',
      '6': 'six',
      '7': 'seven',
      '8': 'eight',
      '9': 'nine',
      '10': 'ten',
    };

    final raw = name.trim();
    final strippedNumeral = raw.replaceFirst(
      RegExp(r'^(?:0|[ivxlcdm]{1,6}|\d{1,2})\s*[-.:)]*\s+', caseSensitive: false),
      '',
    );
    for (final cand in [raw, strippedNumeral]) {
      final n = norm(cand);
      if (n.isEmpty) continue;
      final direct = byNorm[n];
      if (direct != null) return direct;
      final words = n.split(' ').map((w) => aliases[w] ?? w).toList();
      final rebuilt = words.join(' ');
      if (byNorm[rebuilt] != null) return byNorm[rebuilt];
      if (words.length == 2) {
        final swapped = '${words[1]} of ${words[0]}';
        if (byNorm[swapped] != null) return byNorm[swapped];
        final joined = '${words[0]} of ${words[1]}';
        if (byNorm[joined] != null) return byNorm[joined];
      }
    }
    return null;
  }
}
