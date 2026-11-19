import 'package:flutter/foundation.dart';

import '../models/voice_language.dart';
import '../models/voice_state.dart';
import 'tts/flutter_tts_engine.dart';
import 'tts/tts_engine.dart';

/// The single voice orchestrator of the Live Oracle.
///
/// Owns the text-to-speech half (reading Oracle answers aloud) and exposes the
/// half-duplex contract the speech-to-text half obeys: while [isSpeaking] is
/// true the microphone must stay ducked so the Oracle never transcribes its
/// own voice.
///
/// Guarantees, in order of importance:
///  1. NO two responses ever play at once — [speak] interrupts the current
///     utterance before starting a new one (plus the engine's FLUSH queue).
///  2. TTS is OPTIONAL — when the engine is missing/unavailable the text Oracle
///     keeps working; [speak] becomes a silent no-op and [state] reads
///     [VoiceState.unavailable].
///  3. The TTS backend is swappable — [OracleVoiceService] depends only on the
///     [TtsEngine] seam, so a neural voice can replace the system TTS later
///     without touching this class or its callers.
class OracleVoiceService extends ChangeNotifier {
  OracleVoiceService({TtsEngine? engine})
      : _engine = engine ?? FlutterTtsEngine();

  final TtsEngine _engine;

  VoiceState _state = VoiceState.idle;
  bool _available = false;
  bool _muted = false;
  String _locale = VoiceLanguage.en.locale;
  List<String> _languages = const [];

  VoiceState get state => _state;

  /// True while the Oracle is audibly talking (or paused mid-sentence). The
  /// STT side watches this to duck the microphone.
  bool get isSpeaking =>
      _state == VoiceState.speaking || _state == VoiceState.paused;

  /// True once [initialize] found a working TTS engine with at least one voice.
  bool get isAvailable => _available;

  bool get isMuted => _muted;

  /// The currently selected TTS locale (defaults to `en-US`).
  String get locale => _locale;

  /// The six target languages, mapped to their locale tags.
  List<VoiceLanguage> get supportedLanguages => VoiceLanguage.values;

  /// Locale tags the device's engine reported during [initialize].
  List<String> get availableLanguages => _languages;

  /// Assigned by the STT half to duck the mic the instant speaking starts and
  /// release it when the utterance ends. Never called when TTS is unavailable.
  VoidCallback? onSpeakingStarted;
  VoidCallback? onSpeakingStopped;

  /// One-time setup: wire the engine handlers, then probe availability. Safe
  /// to call more than once — it is idempotent.
  Future<void> initialize() async {
    _engine
      ..setCompletionHandler(_onFinished)
      ..setCancelHandler(_onFinished)
      ..setErrorHandler(_onError);

    final ok = await _engine.initialize();
    if (!ok) {
      _available = false;
      _setState(VoiceState.unavailable);
      return;
    }
    _languages = await _engine.getLanguages();
    _available = _languages.isNotEmpty;
    _setState(_available ? VoiceState.idle : VoiceState.unavailable);
  }

  /// Whether the engine has a voice for [locale] (one of the six supported
  /// tags, e.g. `ru-RU`).
  Future<bool> isLanguageAvailable(String locale) =>
      _engine.isLanguageAvailable(locale);

  /// Selects the spoken locale. Unknown/absent locales fall back to the engine
  /// default without throwing — the text Oracle is unaffected either way.
  Future<void> setLanguage(String locale) async {
    _locale = locale;
    if (_available) {
      await _engine.setLanguage(locale);
    }
  }

  /// Speaks [text]. Interrupts any utterance already playing. No-op (silently)
  /// when muted or when TTS is unavailable — the reading continues as text.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (_muted || !_available) return;

    // Guarantee 1: never overlap — flush the current utterance first.
    if (isSpeaking) {
      await _engine.stop();
    }

    final ok = await _engine.speak(text);
    if (!ok) {
      _setState(VoiceState.error);
      return;
    }
    _setState(VoiceState.speaking);
    onSpeakingStarted?.call();
  }

  /// Interrupts the current utterance and returns to silence.
  Future<void> stop() async {
    if (_state == VoiceState.idle ||
        _state == VoiceState.muted ||
        _state == VoiceState.unavailable) {
      return;
    }
    await _engine.stop();
    _setState(VoiceState.idle);
    onSpeakingStopped?.call();
  }

  /// Best-effort pause (Android needs SDK 26+; a `false` from the engine is
  /// reported honestly by leaving the state untouched).
  Future<void> pause() async {
    if (_state != VoiceState.speaking) return;
    final ok = await _engine.pause();
    if (ok) _setState(VoiceState.paused);
  }

  /// Mutes/unmutes the Oracle voice. Muting interrupts any playback; unmuting
  /// returns to the resting state. Idempotent.
  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    if (value) {
      await _engine.stop();
      _setState(VoiceState.muted);
    } else {
      _setState(_available ? VoiceState.idle : VoiceState.unavailable);
    }
  }

  void _onFinished() {
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      _setState(VoiceState.idle);
      onSpeakingStopped?.call();
    }
  }

  void _onError(String message) {
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      _setState(VoiceState.error);
      onSpeakingStopped?.call();
    }
  }

  void _setState(VoiceState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
