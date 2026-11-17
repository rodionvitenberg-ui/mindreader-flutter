import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Sleek translucent obsidian prompt card right above the deck: slot
/// intention question + zero-friction context chips (one horizontally
/// scrollable row) + compact expandable text/voice input bar. After the
/// synthesis it becomes the endless-clarifier follow-up bar. Kept compact
/// so the hero deck below always stays reachable.
class IntentionPromptBar extends StatelessWidget {
  const IntentionPromptBar({
    super.key,
    required this.eyebrow,
    required this.question,
    required this.chips,
    required this.selectedChip,
    required this.onChipTap,
    required this.controller,
    required this.onMicTap,
    required this.micListening,
    this.actionLabel,
    this.onAction,
    this.inlineAction = false,
    this.extraActions = const [],
  });

  final String eyebrow;
  final String question;
  final List<String> chips;
  final String? selectedChip;
  final ValueChanged<String> onChipTap;
  final TextEditingController controller;
  final VoidCallback onMicTap;
  final bool micListening;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact pill inside the input row instead of a full-width row.
  final bool inlineAction;

  /// Camera-sync clarifier pair, rendered side by side.
  final List<IntentionBarAction> extraActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1.4,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    _IntentChip(
                      label: chips[i],
                      active: chips[i] == selectedChip,
                      onTap: () => onChipTap(chips[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.canvas.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      hintText: 'Type or speak your thought...',
                      hintStyle: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              _MicButton(listening: micListening, onTap: onMicTap),
              if (inlineAction && actionLabel != null && onAction != null) ...[
                const SizedBox(width: 5),
                _InlineAction(label: actionLabel!, onTap: onAction!),
              ],
            ],
          ),
          if (!inlineAction && actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),
            _BarAction(label: actionLabel!, onTap: onAction!),
          ],
          if (extraActions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < extraActions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: _BarAction(
                      label: extraActions[i].label,
                      onTap: extraActions[i].onTap,
                      icon: extraActions[i].icon,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A camera-sync clarifier action with its own icon.
class IntentionBarAction {
  const IntentionBarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.2)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening
              ? AppColors.conflictRose.withValues(alpha: 0.25)
              : AppColors.surface.withValues(alpha: 0.8),
          border: Border.all(
            color: listening ? AppColors.conflictRose : AppColors.border,
          ),
        ),
        child: Icon(
          listening ? Icons.graphic_eq : Icons.mic_none,
          size: 15,
          color: listening ? AppColors.conflictRose : AppColors.lavender,
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lavender.withValues(alpha: 0.2),
              AppColors.indigo.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.lavender),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lavender,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

