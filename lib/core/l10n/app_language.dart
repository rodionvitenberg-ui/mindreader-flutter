/// The six UI languages of the app. The enum name is the persisted code, so
/// adding a value never invalidates an existing preference: unknown saved
/// codes fall back to English in `AppSettingsController.load()`.
enum AppLanguage {
  en('en'),
  ru('ru'),
  es('es'),
  pt('pt'),
  de('de'),
  fr('fr');

  const AppLanguage(this.code);

  /// Two-letter BCP-47 code used by TTS, date formatting and persistence.
  final String code;

  /// Resolves a persisted/BCP-47 code (`ru`, `ru-RU`) to an [AppLanguage].
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.en;
    final normalized = code.toLowerCase();
    for (final language in values) {
      if (language.code == normalized || language.name == normalized) {
        return language;
      }
      if (normalized.startsWith('${language.code}-')) return language;
    }
    return AppLanguage.en;
  }
}
