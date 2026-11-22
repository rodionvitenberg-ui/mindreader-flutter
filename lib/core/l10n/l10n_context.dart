import 'package:flutter/widgets.dart';

import 'app_strings.dart';

export 'app_language.dart';

/// `context.l10n('key')` — the only way widget code reads display copy.
///
/// The language itself lives in [AppStrings.current] because pure-Dart models
/// (cards, spreads, lessons) resolve their own labels. The app rebuilds the
/// whole tree when the language changes, so every lookup is re-evaluated.
extension AppL10nContext on BuildContext {
  String l10n(String key, [Map<String, Object?>? params]) =>
      AppStrings.g(key, params);

  AppLanguage get appLanguage => AppStrings.current;
}
