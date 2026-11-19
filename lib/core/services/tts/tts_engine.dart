/// A single TTS voice reported by the engine (name + locale). Kept as a plain
/// value object so a future neural-voice backend can report richer metadata
/// (id, quality, gender) without breaking consumers.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;
  final String locale;
}

/// The narrow text-to-speech seam behind [OracleVoiceService].
///
/// The Live Oracle depends on THIS abstraction, never on a concrete engine, so
/// the system TTS can later be swapped for a neural voice (or a mock in tests)
/// without touching the session/UI layers. Every method is best-effort and
/// must never throw into the caller — [OracleVoiceService] guards availability.
abstract class TtsEngine {
  /// One-time setup. Returns false when TTS is unavailable on this device.
  Future<bool> initialize();

  /// Locale tags the engine can speak (e.g. `en-US`), possibly empty.
  Future<List<String>> getLanguages();

  /// Voices the engine exposes (name + locale), possibly empty.
  Future<List<TtsVoice>> getVoices();

  /// Whether the engine has a voice for [locale] installed/available.
  Future<bool> isLanguageAvailable(String locale);

  /// Selects the voice locale for subsequent [speak] calls.
  Future<bool> setLanguage(String locale);

  Future<void> setSpeechRate(double rate);

  /// Speaks [text] aloud. Replaces any utterance already playing.
  Future<bool> speak(String text);

  /// Interrupts the current utterance immediately (returns to silence).
  Future<bool> stop();

  /// Pauses the current utterance. Best-effort: Android needs SDK 26+ and iOS
  /// may not fully pause; the service must treat a `false` honestly.
  Future<bool> pause();

  /// Fires when an utterance finishes naturally.
  void setCompletionHandler(void Function() handler);

  /// Fires when the engine reports an error (message is engine-specific).
  void setErrorHandler(void Function(String message) handler);

  /// Fires when an utterance is cancelled/interrupted.
  void setCancelHandler(void Function() handler);

  /// Releases engine resources.
  Future<void> dispose();
}
