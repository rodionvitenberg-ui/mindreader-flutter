import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';

/// Acceptance guard for the six-language dictionaries.
///
/// Every key must exist in every language, every value must be non-empty and
/// keep the same `{placeholders}` as English. Moving content into `l10n/*.tsv`
/// is only safe if a forgotten translation fails here instead of rendering an
/// empty label on a device.
void main() {
  const languages = AppLanguage.values;

  test('every key exists and is non-empty in all six languages', () {
    final missing = <String>[];
    for (final key in AppStrings.keys) {
      for (final language in languages) {
        if (!AppStrings.has(language, key)) {
          missing.add('${language.code}: $key');
          continue;
        }
        if (AppStrings.t(language, key).trim().isEmpty) {
          missing.add('${language.code}: $key is empty');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(20).join('\n'));
  });

  test('placeholders survive translation', () {
    final placeholder = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    final broken = <String>[];
    for (final key in AppStrings.keys) {
      final english = placeholder
          .allMatches(AppStrings.t(AppLanguage.en, key))
          .map((m) => m.group(1))
          .toSet();
      if (english.isEmpty) continue;
      for (final language in languages) {
        final localized = placeholder
            .allMatches(AppStrings.t(language, key))
            .map((m) => m.group(1))
            .toSet();
        if (!localized.containsAll(english) ||
            !english.containsAll(localized)) {
          broken.add('${language.code}: $key ($english vs $localized)');
        }
      }
    }
    expect(broken, isEmpty, reason: broken.take(20).join('\n'));
  });

  test('unknown keys fall back to the key instead of crashing', () {
    expect(AppStrings.t(AppLanguage.de, 'no.such.key'), 'no.such.key');
  });

  test('params replace named placeholders', () {
    expect(
      AppStrings.t(AppLanguage.en, 'common.cards.other', {'count': 7}),
      '7 cards',
    );
  });

  test('cardCount follows English and Russian plural rules', () {
    expect(AppStrings.cardCount(AppLanguage.en, 1), '1 card');
    expect(AppStrings.cardCount(AppLanguage.en, 5), '5 cards');
    expect(AppStrings.cardCount(AppLanguage.ru, 1), '1 карта');
    expect(AppStrings.cardCount(AppLanguage.ru, 3), '3 карты');
    expect(AppStrings.cardCount(AppLanguage.ru, 11), '11 карт');
    expect(AppStrings.cardCount(AppLanguage.ru, 21), '21 карта');
    expect(
      AppStrings.cardCount(AppLanguage.ru, 5, isRune: true),
      '5 рун',
    );
  });

  test('every language exposes its own native label', () {
    const native = {
      'en': 'ENGLISH',
      'ru': 'РУССКИЙ',
      'es': 'ESPAÑOL',
      'pt': 'PORTUGUÊS',
      'de': 'DEUTSCH',
      'fr': 'FRANÇAIS',
    };
    for (final language in languages) {
      expect(
        AppStrings.t(language, 'settings.lang.${language.code}'),
        native[language.code],
      );
    }
  });
}
