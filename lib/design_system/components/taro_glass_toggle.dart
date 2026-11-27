import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_tokens.dart';

/// Стеклянный переключатель (Phase G3): настройки, тихий режим, уведомления.
///
/// Гарантирует touch-target ≥ 44 px, настоящую семантику (`toggled`, `enabled`)
/// и GPU-композитную анимацию бегунка через [AnimatedAlign].
class TaroGlassToggle extends StatelessWidget {
  const TaroGlassToggle({
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.semanticLabel,
    super.key,
  });

  final bool value;

  /// null → disabled.
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final String? semanticLabel;

  bool get _disabled => onChanged == null;

  void _toggle() {
    if (_disabled) return;
    HapticFeedback.selectionClick();
    onChanged!(!value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = TaroPalette.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TaroMotion.fast;
    final track = AnimatedContainer(
      duration: duration,
      width: 54,
      height: 32,
      decoration: BoxDecoration(
        color: value
            ? Color.alphaBlend(
                (palette.isMoonlit
                        ? TaroColors.lanternAmber
                        : TaroColors.lavender)
                    .withValues(alpha: palette.isMoonlit ? 0.32 : 0.38),
                palette.surface,
              )
            : (palette.isMoonlit
                  ? const Color(0xFF141722)
                  : const Color(0xFF3B3B43)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? (palette.isMoonlit
                    ? palette.activeOutline
                    : TaroColors.lavender.withValues(alpha: .65))
              : (palette.isMoonlit
                    ? palette.borderHairline
                    : TaroColors.mist.withValues(alpha: .34)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox.square(
            dimension: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _disabled ? TaroColors.mist : TaroColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );

    final control = label == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 54, minHeight: 44),
            child: Center(child: track),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label!,
                        style: AppTypography.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _disabled
                              ? TaroColors.textSecondary.withValues(alpha: 0.5)
                              : TaroColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.body(
                            fontSize: 12,
                            color: TaroColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                track,
              ],
            ),
          );

    return Semantics(
      toggled: value,
      enabled: !_disabled,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _disabled ? null : _toggle,
        child: control,
      ),
    );
  }
}
