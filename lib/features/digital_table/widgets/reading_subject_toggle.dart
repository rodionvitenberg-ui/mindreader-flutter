import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import 'reading_context_field.dart';
import '../../../state/user_profile_controller.dart';

/// "WHO IS THIS FOR?" — the subject toggle that decides whether the local
/// profile context is woven into Oracle prompts. For Myself injects
/// the owner's biography. Both subjects share the optional reading draft.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _pill(
                label: AppStrings.t(lang, 'table.myself'),
                icon: Icons.person_outline,
                active: forSelf,
                onTap: () => select(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pill(
                label: AppStrings.t(lang, 'table.someone'),
                icon: Icons.people_outline,
                active: !forSelf,
                onTap: () => select(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ReadingContextField(
          key: ValueKey(spread.readingRevision),
          value: spread.readingQuestion,
          onChanged: spread.setReadingQuestion,
          language: lang,
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? AppColors.lavender : AppColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active
                ? AppColors.lavender.withValues(alpha: 0.55)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    letterSpacing: 1.1,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
