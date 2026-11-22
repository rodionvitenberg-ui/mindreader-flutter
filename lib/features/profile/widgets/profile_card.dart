import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

/// Shared Tarot Tree glass card used by every ProfileScreen section (Phase G5).
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.section,
    required this.title,
    required this.child,
    this.trailing,
  });

  final SettingsSection section;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final expanded = context.select<AppSettingsController, bool>(
      (settings) => settings.sectionExpanded(section),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TaroGlassPanel(
        radius: 20,
        padding: EdgeInsets.fromLTRB(16, 0, 16, expanded ? 16 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                key: ValueKey(section),
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<AppSettingsController>().setSectionExpanded(
                    section,
                    !expanded,
                  );
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
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
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: TaroColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) child,
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
      return TaroGlassPill(label: label, icon: icon, accent: active);
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
