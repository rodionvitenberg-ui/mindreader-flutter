import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// The system text-to-speech backend: a thin adapter over `flutter_tts`.
///
/// Every call is best-effort and swallows platform errors (a missing engine,
/// an unavailable voice, a web build without speech synthesis) so the
/// [OracleVoiceService] above it can degrade to text-only instead of throwing.
class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<bool> initialize() async {
    try {
      // Queue mode 0 = FLUSH: a new utterance replaces the one still playing.
      // This is the first of two layers that guarantee no two Oracle responses
      // ever overlap (the service guard is the second).
      await _tts.setQueueMode(0);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getLanguages() async {
    try {
      final langs = await _tts.getLanguages;
      return (langs as List? ?? const []).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      final voices = await _tts.getVoices;
      return (voices as List? ?? const []).map((v) {
        final map = Map<String, dynamic>.from(v as Map);
        return TtsVoice(
          name: (map['name'] ?? '').toString(),
          locale: (map['locale'] ?? '').toString(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    try {
      final result = await _tts.isLanguageAvailable(locale);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setLanguage(String locale) async {
    try {
      final result = await _tts.setLanguage(locale);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {
      // Rate is cosmetic — ignore platform rejection.
    }
  }

  @override
  Future<bool> speak(String text) async {
    try {
      final result = await _tts.speak(text);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      final result = await _tts.stop();
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> pause() async {
    try {
      final result = await _tts.pause();
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  void setCompletionHandler(void Function() handler) {
    _tts.setCompletionHandler(handler);
  }

  @override
  void setErrorHandler(void Function(String message) handler) {
    _tts.setErrorHandler((dynamic message) => handler(message.toString()));
  }

  @override
  void setCancelHandler(void Function() handler) {
    _tts.setCancelHandler(handler);
  }

  @override
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Already silent.
    }
  }
}
