import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
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
    final track = SizedBox(
      width: 54,
      height: 32,
      child: TaroGlassSurface(
        radius: TaroRadii.pill,
        visibility: _disabled ? 0.45 : 1.0,
        tint: value
            ? TaroColors.lavender.withValues(alpha: 0.34)
            : TaroColors.mist.withValues(alpha: 0.10),
        fillColor: value
            ? TaroColors.lavender.withValues(alpha: 0.35)
            : TaroColors.surface,
        borderColor: value
            ? TaroColors.lavender.withValues(alpha: TaroOpacity.borderStrong)
            : TaroColors.mist.withValues(alpha: TaroOpacity.border),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedAlign(
            duration: TaroMotion.fast,
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? TaroColors.textPrimary : TaroColors.mist,
                boxShadow: value
                    ? TaroGlow.soft(TaroColors.lavender, alpha: 0.45, blur: 10)
                    : null,
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
        onTap: _toggle,
        child: control,
      ),
    );
  }
}
