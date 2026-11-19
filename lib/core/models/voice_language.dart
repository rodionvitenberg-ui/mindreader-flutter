/// The six spoken languages the Live Oracle must be able to read aloud, each
/// mapped to a concrete TTS locale tag. The mapping lives in ONE place so the
/// Oracle and the settings UI never hand-roll locale strings.
enum VoiceLanguage {
  en('en-US'),
  ru('ru-RU'),
  es('es-ES'),
  pt('pt-BR'),
  de('de-DE'),
  fr('fr-FR');

  const VoiceLanguage(this.locale);

  /// The BCP-47 locale tag passed to the TTS engine (e.g. `en-US`).
  final String locale;

  /// Resolves a TTS locale tag back to a [VoiceLanguage], or null when the
  /// engine reports a locale outside the six supported ones.
  static VoiceLanguage? fromLocale(String locale) {
    final normalized = locale.toLowerCase();
    for (final lang in values) {
      if (lang.locale.toLowerCase() == normalized) return lang;
    }
    return null;
  }
}
