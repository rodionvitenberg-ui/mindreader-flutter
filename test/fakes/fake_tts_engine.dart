import 'package:mindreader/core/services/tts/tts_engine.dart';

/// A scriptable in-memory [TtsEngine] for tests. Configure [languages],
/// [initResult], [speakResult], etc., then drive the engine's async lifecycle
/// events with [fireCompletion] / [fireCancel] / [fireError] to exercise the
/// [OracleVoiceService] state machine deterministically.
class FakeTtsEngine implements TtsEngine {
  List<String> languages = const [
    'en-US',
    'ru-RU',
    'es-ES',
    'pt-BR',
    'de-DE',
    'fr-FR',
  ];
  List<TtsVoice> voices = const [TtsVoice(name: 'Fake Voice', locale: 'en-US')];

  bool initResult = true;
  bool speakResult = true;
  bool stopResult = true;
  bool pauseResult = true;
  bool setLanguageResult = true;

  int speakCalls = 0;
  int stopCalls = 0;
  int pauseCalls = 0;
  String? lastSpokenText;
  String? lastSetLanguage;

  void Function()? _onComplete;
  void Function()? _onCancel;
  void Function(String)? _onError;

  /// Simulates the platform calling back when an utterance finishes.
  void fireCompletion() => _onComplete?.call();

  /// Simulates an interrupt/cancel callback.
  void fireCancel() => _onCancel?.call();

  /// Simulates a platform error callback.
  void fireError(String message) => _onError?.call(message);

  @override
  Future<bool> initialize() async => initResult;

  @override
  Future<List<String>> getLanguages() async => languages;

  @override
  Future<List<TtsVoice>> getVoices() async => voices;

  @override
  Future<bool> isLanguageAvailable(String locale) async =>
      languages.contains(locale);

  @override
  Future<bool> setLanguage(String locale) async {
    lastSetLanguage = locale;
    return setLanguageResult;
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<bool> speak(String text) async {
    speakCalls++;
    lastSpokenText = text;
    return speakResult;
  }

  @override
  Future<bool> stop() async {
    stopCalls++;
    return stopResult;
  }

  @override
  Future<bool> pause() async {
    pauseCalls++;
    return pauseResult;
  }

  @override
  void setCompletionHandler(void Function() handler) {
    _onComplete = handler;
  }

  @override
  void setErrorHandler(void Function(String message) handler) {
    _onError = handler;
  }

  @override
  void setCancelHandler(void Function() handler) {
    _onCancel = handler;
  }

  @override
  Future<void> dispose() async {}
}
