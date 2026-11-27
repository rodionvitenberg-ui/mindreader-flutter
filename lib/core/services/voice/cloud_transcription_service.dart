import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../oracle_synthesis_service.dart';

/// Failure modes for cloud speech-to-text transcription.
enum TranscriptionErrorKind {
  notConfigured,
  network,
  unauthorized,
  quotaExceeded,
  empty,
  failed,
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.kind, [this.message = '']);

  final TranscriptionErrorKind kind;
  final String message;

  @override
  String toString() => 'TranscriptionException($kind: $message)';
}

/// Abstract audio transcription seam so tests never make real HTTP requests.
abstract class AudioTranscriber {
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String mimeType,
    String filename = 'voice_note.m4a',
  });
}

/// Multilingual, locale-independent cloud speech transcription with accurate
/// punctuation and filler cleanup.
///
/// Routing priority (100% independent of device OS locale and app UI locale):
/// 1. Explicit Whisper / STT endpoint (`STT_API_URL`, e.g. Whisper Large-v3).
/// 2. Native Gemini Flash multimodal audio (`generateContent` with `inline_data`)
///    using the existing `GEMINI_API_KEY` / `VISION_API_KEY` & `ORACLE_API_MODEL`.
/// 3. Generic OpenAI-compatible multimodal `chat/completions` (`input_audio`)
///    when `ORACLE_API_URL` points to a custom OpenAI-compatible gateway.
class CloudTranscriptionService implements AudioTranscriber {
  CloudTranscriptionService({
    http.Client? client,
    BackendAuthResolver? backendAuthResolver,
    String? sttUrl,
    String? sttKey,
    String? sttModel,
    String? cloudUrl,
    String? cloudKey,
    String? cloudModel,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       backendAuthResolverOverride = backendAuthResolver,
       _sttUrl = sttUrl ?? defaultSttUrl,
       _sttKey = sttKey ?? defaultSttKey,
       _sttModel = sttModel ?? defaultSttModel,
       _cloudUrl = cloudUrl ?? OracleSynthesisService.cloudUrl,
       _cloudKey = cloudKey ?? OracleSynthesisService.cloudKey,
       _cloudModel = cloudModel ?? OracleSynthesisService.cloudModel,
       _timeout = timeout ?? const Duration(seconds: 25);

  static BackendAuthResolver? _globalBackendAuthResolver;

  /// Registers the app-wide Django auth resolver so voice notes transcribe
  /// through `/api/v1/oracle/transcribe/` without exposing STT keys in PWA.
  static void registerBackendAuth(BackendAuthResolver? resolver) {
    _globalBackendAuthResolver = resolver;
  }

  static const defaultSttUrl = String.fromEnvironment('STT_API_URL');
  static const defaultSttKey = String.fromEnvironment('STT_API_KEY');
  static const defaultSttModel = String.fromEnvironment(
    'STT_API_MODEL',
    defaultValue: 'whisper-large-v3',
  );

  /// Prompt instructing the cloud model to auto-detect spoken language(s),
  /// preserve authentic wording (never translating or transliterating), clean
  /// meaningless fillers, and emit crisp punctuation with zero commentary.
  static const String transcriptionPrompt =
      'Transcribe the spoken audio accurately with automatic language detection. '
      'The speaker may speak Russian, English, another language, or switch between '
      'languages mid-sentence. Always write each phrase in its original spoken '
      'language and native script (never translate and never transliterate Cyrillic '
      'into Latin). Add natural capitalization, commas, periods, dashes, and '
      'question marks. Gently remove meaningless hesitation fillers (such as "um", '
      '"uh", "эээ", "эм") while preserving the speaker’s exact meaning and authentic '
      'phrasing. Output ONLY the clean transcribed text with no quotes, labels, or '
      'commentary. If the audio contains only silence or background noise with no '
      'intelligible speech, return an empty string.';

  final http.Client _client;
  final BackendAuthResolver? backendAuthResolverOverride;
  final String _sttUrl;
  final String _sttKey;
  final String _sttModel;
  final String _cloudUrl;
  final String _cloudKey;
  final String _cloudModel;
  final Duration _timeout;

  BackendAuthResolver? get _effectiveBackendAuth =>
      backendAuthResolverOverride ?? _globalBackendAuthResolver;

  bool get hasBackendProxy => _effectiveBackendAuth != null;
  bool get hasDedicatedStt => !kIsWeb && _sttUrl.isNotEmpty;
  bool get hasCloudLlm => !kIsWeb && _cloudUrl.isNotEmpty && _cloudKey.isNotEmpty;
  bool get isConfigured => hasBackendProxy || hasDedicatedStt || hasCloudLlm;

  static bool _isGoogleGeminiEndpoint(String url) =>
      url.contains('generativelanguage.googleapis.com');

  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String mimeType,
    String filename = 'voice_note.m4a',
  }) async {
    if (audioBytes.isEmpty) {
      throw const TranscriptionException(
        TranscriptionErrorKind.empty,
        'Audio payload is empty.',
      );
    }
    if (!isConfigured) {
      throw const TranscriptionException(
        TranscriptionErrorKind.notConfigured,
        'No cloud transcription API key or STT endpoint configured.',
      );
    }

    try {
      String? raw;
      if (hasBackendProxy) {
        raw = await _transcribeViaBackend(
          audioBytes: audioBytes,
          mimeType: mimeType,
          filename: filename,
        );
      }
      if (raw == null) {
        if (!hasDedicatedStt && !hasCloudLlm) {
          throw const TranscriptionException(
            TranscriptionErrorKind.notConfigured,
            'Cloud speech transcription is not configured.',
          );
        }
        raw = hasDedicatedStt
            ? await _transcribeViaWhisperMultipart(
                audioBytes: audioBytes,
                filename: filename,
              )
            : _isGoogleGeminiEndpoint(_cloudUrl)
            ? await _transcribeViaGeminiNative(
                audioBytes: audioBytes,
                mimeType: mimeType,
              )
            : await _transcribeViaOpenAiAudioChat(
                audioBytes: audioBytes,
                mimeType: mimeType,
              );
      }
      final cleaned = sanitizeTranscript(raw);
      if (cleaned.isEmpty) {
        throw const TranscriptionException(
          TranscriptionErrorKind.empty,
          'No intelligible speech detected.',
        );
      }
      return cleaned;
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException(
        TranscriptionErrorKind.network,
        e.runtimeType.toString(),
      );
    }
  }

  /// Route 0 (preferred): Django `/api/v1/oracle/transcribe/` proxy.
  Future<String?> _transcribeViaBackend({
    required Uint8List audioBytes,
    required String mimeType,
    required String filename,
  }) async {
    final resolver = _effectiveBackendAuth;
    if (resolver == null) return null;
    final (baseUrl, token) = await resolver();
    final cleanBase = baseUrl?.trim() ?? '';
    final cleanToken = token?.trim() ?? '';
    if (cleanBase.isEmpty || cleanToken.isEmpty) return null;

    final uri = Uri.parse(cleanBase).resolve('/api/v1/oracle/transcribe/');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $cleanToken'
      ..fields['mimeType'] = mimeType;
    MediaType? contentType;
    try {
      contentType = MediaType.parse(mimeType);
    } catch (_) {
      contentType = MediaType('audio', 'mp4');
    }
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
        contentType: contentType,
      ),
    );
    final streamed = await _client.send(req).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 429) {
      throw const TranscriptionException(
        TranscriptionErrorKind.quotaExceeded,
        'Daily voice transcription quota reached.',
      );
    }
    if (response.statusCode == 503) {
      if (hasDedicatedStt || hasCloudLlm) return null;
      throw const TranscriptionException(
        TranscriptionErrorKind.notConfigured,
        'Server STT provider is not configured.',
      );
    }
    _checkHttpStatus(response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded['text'] is String) {
      return decoded['text'] as String;
    }
    throw const TranscriptionException(
      TranscriptionErrorKind.failed,
      'Unexpected backend STT JSON shape.',
    );
  }

  /// Route 1: OpenAI / Groq / self-hosted Whisper `/audio/transcriptions`
  /// (multipart upload, NO hardcoded `language` field → true Auto Language Detection).
  Future<String> _transcribeViaWhisperMultipart({
    required Uint8List audioBytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_sttUrl));
    final key = _sttKey.isNotEmpty ? _sttKey : _cloudKey;
    if (key.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $key';
    }
    request.fields['model'] = _sttModel;
    request.fields['response_format'] = 'json';
    request.fields['temperature'] = '0';
    request.fields['prompt'] =
        'Punctuate naturally with periods, commas, dashes, and question marks.';
    request.files.add(
      http.MultipartFile.fromBytes('file', audioBytes, filename: filename),
    );

    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    _checkHttpStatus(response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded['text'] is String) {
      return decoded['text'] as String;
    }
    throw const TranscriptionException(
      TranscriptionErrorKind.failed,
      'Unexpected STT JSON shape.',
    );
  }

  /// Route 2: Native Google Gemini Flash multimodal `generateContent` with
  /// `inline_data` (`audio/mp4` / `audio/ogg`).
  Future<String> _transcribeViaGeminiNative({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final model = _cloudModel.startsWith('models/')
        ? _cloudModel.substring('models/'.length)
        : _cloudModel;
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _cloudKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': base64Encode(audioBytes),
                    },
                  },
                  {'text': transcriptionPrompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.0,
              'maxOutputTokens': 1024,
            },
          }),
        )
        .timeout(_timeout);
    _checkHttpStatus(response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map && part['text'] is String) {
              buffer.write(part['text'] as String);
            }
          }
          return buffer.toString();
        }
      }
    }
    throw const TranscriptionException(
      TranscriptionErrorKind.failed,
      'Unexpected Gemini transcription response.',
    );
  }

  /// Route 3: OpenAI-compatible multimodal `chat/completions` (`input_audio`).
  Future<String> _transcribeViaOpenAiAudioChat({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final format = mimeType.contains('ogg') || mimeType.contains('opus')
        ? 'ogg'
        : mimeType.contains('wav')
        ? 'wav'
        : 'mp4';
    final response = await _client
        .post(
          Uri.parse(_cloudUrl),
          headers: {
            'Content-Type': 'application/json',
            if (_cloudKey.isNotEmpty) 'Authorization': 'Bearer $_cloudKey',
          },
          body: jsonEncode({
            'model': _cloudModel,
            'temperature': 0.0,
            'max_tokens': 1024,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': transcriptionPrompt},
                  {
                    'type': 'input_audio',
                    'input_audio': {
                      'data': base64Encode(audioBytes),
                      'format': format,
                    },
                  },
                ],
              },
            ],
          }),
        )
        .timeout(_timeout);
    _checkHttpStatus(response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final content = choices.first['message']?['content'];
        if (content is String) return content;
      }
    }
    throw const TranscriptionException(
      TranscriptionErrorKind.failed,
      'Unexpected OpenAI-compatible transcription response.',
    );
  }

  static void _checkHttpStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      throw TranscriptionException(
        TranscriptionErrorKind.unauthorized,
        'HTTP $statusCode',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw TranscriptionException(
        TranscriptionErrorKind.failed,
        'HTTP $statusCode',
      );
    }
  }

  /// Strips accidental wrapping quotes/code fences and collapses whitespace.
  static String sanitizeTranscript(String raw) {
    var text = raw.trim();
    if (text.startsWith('```') && text.endsWith('```') && text.length >= 6) {
      text = text.substring(3, text.length - 3).trim();
    }
    if (text.length >= 2 &&
        ((text.startsWith('"') && text.endsWith('"')) ||
            (text.startsWith('«') && text.endsWith('»')))) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
