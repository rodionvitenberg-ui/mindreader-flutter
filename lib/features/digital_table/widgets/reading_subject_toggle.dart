import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import '../../../state/user_profile_controller.dart';
import 'reading_context_field.dart';

/// "WHO IS THIS FOR?" — the subject toggle that decides whether the local
/// profile context is woven into Oracle prompts (Phase G4: migrated to
/// [TaroGlassSegmentedControl]). For Myself injects the owner's biography.
/// Both subjects share the optional reading draft.
class ReadingSubjectToggle extends StatelessWidget {
  const ReadingSubjectToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    final spread = context.watch<SpreadController>();
    final lang = context.watch<AppSettingsController>().language;
    final forSelf = spread.readingForSelf ?? profile.readingForSelf;
    void select(bool value) {
      spread.setReadingForSelf(value);
      profile.setReadingForSelf(value);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TaroGlassSegmentedControl<bool>(
            segments: [
              TaroGlassSegment<bool>(
                value: true,
                label: AppStrings.t(lang, 'table.myself'),
                icon: Icons.person_outline,
              ),
              TaroGlassSegment<bool>(
                value: false,
                label: AppStrings.t(lang, 'table.someone'),
                icon: Icons.people_outline,
              ),
            ],
            value: forSelf,
            onChanged: select,
          ),
          const SizedBox(height: 6),
          ReadingContextField(
            key: ValueKey(spread.readingRevision),
            value: spread.readingQuestion,
            onChanged: spread.setReadingQuestion,
            language: lang,
          ),
        ],
      ),
    );
  }
}
