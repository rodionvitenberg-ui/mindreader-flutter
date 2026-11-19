/// The voice pipeline's observable state — one vocabulary shared by the
/// speech-to-text (listening) half and the text-to-speech (speaking) half of
/// the Live Oracle, so the UI and the half-duplex coordinator speak one
/// language.
///
/// STT states: [listening], [transcribing], [thinking] (Oracle composing).
/// TTS states: [speaking], [paused], [muted].
/// Fallback states: [unavailable] (TTS engine missing/disabled), [error].
/// [idle] is the resting state with no mic and no playback.
enum VoiceState {
  idle,
  listening,
  transcribing,
  thinking,
  speaking,
  paused,
  muted,
  unavailable,
  error,
}

/// Whether this state belongs to the speech-to-text (input) half.
extension VoiceStateX on VoiceState {
  bool get isListeningHalf =>
      this == VoiceState.listening ||
      this == VoiceState.transcribing ||
      this == VoiceState.thinking;

  /// True while the Oracle is audibly talking — the STT side must be ducked.
  bool get isSpeaking =>
      this == VoiceState.speaking || this == VoiceState.paused;
}
