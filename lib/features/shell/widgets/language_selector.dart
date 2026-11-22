import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

/// Six-language picker shared by the Profile page and the settings sheet.
///
/// A segmented control is too narrow for six labels on a phone, so the
/// languages wrap as glass chips. Every chip always shows the language's own
/// name — "РУССКИЙ" stays Russian even while the UI is in German.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.onChanged});

  final ValueChanged<AppLanguage>? onChanged;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final current = settings.language;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final language in AppLanguage.values)
          TaroGlassChip(
            key: ValueKey('language-${language.code}'),
            label: AppStrings.t(language, 'settings.lang.${language.code}'),
            selected: current == language,
            onTap: () {
              if (onChanged != null) {
                onChanged!(language);
              } else {
                settings.setLanguage(language);
              }
            },
          ),
      ],
    );
  }
}
