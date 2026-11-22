import '../l10n/app_strings.dart';

/// One localized educational line for the Guided Reading mentor (G4).
///
/// The text lives in `l10n/*.tsv` under [key]; the `.en` / `.ru` getters are
/// kept for the legacy content tests and now resolve the same dictionary.
class GuideLine {
  const GuideLine(this.key);

  final String key;

  String get en => AppStrings.t(AppLanguage.en, key);

  String get ru => AppStrings.t(AppLanguage.ru, key);

  String forLanguage(AppLanguage lang) => AppStrings.t(lang, key);
}
