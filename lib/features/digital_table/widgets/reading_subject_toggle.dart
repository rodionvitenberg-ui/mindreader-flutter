import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/user_profile_controller.dart';

/// "WHO IS THIS FOR?" — the subject toggle that decides whether the local
/// profile context is woven into Oracle prompts. For Myself injects
/// [UserProfileController.oracleContext]; For Someone Else never does and
/// offers an optional free-form note instead.
class ReadingSubjectToggle extends StatelessWidget {
  const ReadingSubjectToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _pill(
                label: 'FOR MYSELF (PROFILE)',
                icon: Icons.person_outline,
                active: profile.readingForSelf,
                onTap: () => profile.setReadingForSelf(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pill(
                label: 'FOR SOMEONE ELSE',
                icon: Icons.people_outline,
                active: !profile.readingForSelf,
                onTap: () => profile.setReadingForSelf(false),
              ),
            ),
          ],
        ),
        if (!profile.readingForSelf)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              onChanged: profile.setTargetPersonNote,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Who or what is this reading about? (optional)',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted.withValues(alpha: 0.75),
                ),
                filled: true,
                fillColor: AppColors.canvas.withValues(alpha: 0.6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
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
