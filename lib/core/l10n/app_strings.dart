import 'app_language.dart';
import 'strings/strings_de.dart';
import 'strings/strings_en.dart';
import 'strings/strings_es.dart';
import 'strings/strings_fr.dart';
import 'strings/strings_pt.dart';
import 'strings/strings_ru.dart';

export 'app_language.dart';

/// Key → localized string lookup for the whole app.
///
/// Every user-visible string lives in `l10n/<code>.tsv` and is generated into
/// the `strings_<code>.dart` maps next to this file. Nothing in `lib/` should
/// contain display copy: UI code calls `context.l10n('key')`, pure-Dart code
/// calls [AppStrings.g].
///
/// A missing key falls back to English, then to the key itself — a label is
/// never blank and the fallback is visible in the UI.
class AppStrings {
  const AppStrings._();

  /// The language the app is currently rendering. Widget code never reads
  /// this directly: it goes through `context.l10n`, which guarantees a rebuild
  /// when `AppSettingsController.setLanguage` changes it.
  static AppLanguage _current = AppLanguage.en;

  static AppLanguage get current => _current;

  /// Called by [AppSettingsController] on startup and on every language
  /// switch. Pure-Dart lookups (`card.name`, generated horoscopes, …) resolve
  /// against this value.
  static void setCurrent(AppLanguage language) => _current = language;

  static const Map<AppLanguage, Map<String, String>> _dictionaries = {
    AppLanguage.en: stringsEn,
    AppLanguage.ru: stringsRu,
    AppLanguage.es: stringsEs,
    AppLanguage.pt: stringsPt,
    AppLanguage.de: stringsDe,
    AppLanguage.fr: stringsFr,
  };

  /// Translates [key] into [lang]. [params] replaces `{name}` placeholders.
  ///
  /// The lookup order is: requested language → English → key itself.
  static String t(
    AppLanguage lang,
    String key, [
    Map<String, Object?>? params,
  ]) {
    final dictionary = _dictionaries[lang] ?? stringsEn;
    var value = dictionary[key] ?? stringsEn[key] ?? key;
    if (params != null && params.isNotEmpty) {
      for (final entry in params.entries) {
        value = value.replaceAll('{${entry.key}}', '${entry.value}');
      }
    }
    return value;
  }

  /// Translates [key] into the language the app is currently rendering.
  static String g(String key, [Map<String, Object?>? params]) =>
      t(_current, key, params);

  /// True when [key] has an entry in [lang]'s dictionary (used by coverage
  /// tests and by content that must know whether a translation exists).
  static bool has(AppLanguage lang, String key) =>
      _dictionaries[lang]?.containsKey(key) ?? false;

  /// Every key of the English dictionary, in authoring order.
  static Iterable<String> get keys => stringsEn.keys;

  /// The plural category of [count] for [lang]. Only Russian distinguishes
  /// `few`/`many`; the other five languages use `one`/`other`.
  static String pluralCategory(AppLanguage lang, int count) {
    final n = count.abs();
    if (lang == AppLanguage.ru) {
      final mod100 = n % 100;
      final mod10 = n % 10;
      if (mod100 >= 11 && mod100 <= 14) return 'many';
      if (mod10 == 1) return 'one';
      if (mod10 >= 2 && mod10 <= 4) return 'few';
      return 'many';
    }
    return n == 1 ? 'one' : 'other';
  }

  /// Localized card/stone count caption used on spread tiles and action
  /// labels (e.g. "5 cards" / "5 карт" / "7 stones" / "7 рун").
  static String cardCount(AppLanguage lang, int count, {bool isRune = false}) {
    final category = pluralCategory(lang, count);
    final base = isRune ? 'common.stones' : 'common.cards';
    return t(lang, '$base.$category', {'count': count});
  }
}
