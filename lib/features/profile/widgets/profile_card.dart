import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Shared Tarot Tree glass card used by every ProfileScreen section (Phase G5).
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TaroGlassPanel(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.label(
                      fontSize: 10,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: TaroColors.lavender,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Small uppercase label above a field.
class ProfileFieldLabel extends StatelessWidget {
  const ProfileFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 0.9,
          color: TaroColors.textSecondary,
        ),
      ),
    );
  }
}

/// On-device note rendered under a local-only field.
class ProfilePrivacyNote extends StatelessWidget {
  const ProfilePrivacyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.4,
          color: TaroColors.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Compact Tarot Tree pill used for status badges and toggles.
class ProfilePill extends StatelessWidget {
  const ProfilePill({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return TaroGlassPill(
        label: label,
        icon: icon,
        accent: active,
      );
    }
    return TaroGlassChip(
      label: label,
      icon: icon,
      selected: active,
      compact: true,
      onTap: onTap,
    );
  }
}
