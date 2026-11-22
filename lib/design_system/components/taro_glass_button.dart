import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Варианты стеклянной кнопки.
enum TaroGlassButtonVariant { primary, secondary, ghost }

/// Интерактивная стеклянная кнопка.
///
/// Реальные состояния normal / pressed / disabled / loading и настоящая
/// семантика (`Semantics(button)`, `GestureDetector`, `HapticFeedback`), а не
/// неинтерактивный [Container].
class TaroGlassButton extends StatefulWidget {
  const TaroGlassButton({
    required this.label,
    required this.onPressed,
    this.variant = TaroGlassButtonVariant.primary,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;

  /// null → disabled.
  final VoidCallback? onPressed;
  final TaroGlassButtonVariant variant;
  final bool loading;
  final IconData? icon;

  @override
  State<TaroGlassButton> createState() => _TaroGlassButtonState();
}

class _TaroGlassButtonState extends State<TaroGlassButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null;

  void _down(TapDownDetails _) => setState(() => _pressed = true);
  void _up(TapUpDetails _) => setState(() => _pressed = false);
  void _cancel() => setState(() => _pressed = false);

  void _onTap() {
    if (_disabled || widget.loading) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _disabled;
    final tint = switch (widget.variant) {
      TaroGlassButtonVariant.primary => TaroColors.lavender.withValues(
        alpha: 0.18,
      ),
      TaroGlassButtonVariant.secondary => TaroColors.mist.withValues(
        alpha: 0.12,
      ),
      TaroGlassButtonVariant.ghost => null,
    };
    final labelColor = disabled
        ? TaroColors.textSecondary.withValues(alpha: 0.5)
        : TaroColors.textPrimary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: labelColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              maxLines: 1,
              style: AppTypography.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: labelColor,
              ),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _cancel,
        onTap: _onTap,
        child: TaroGlassSurface(
          radius: TaroRadii.button,
          tint: tint,
          // Keep enabled visibility at 1.0 on press so ConsolidatedFakeGlassLayer
          // never tears the button out into a separate SeededBackdropPassLayer
          // (which darkens buttons on Impeller OpenGLES during tap/drag).
          visibility: disabled ? 0.5 : 1.0,
          fillColor: widget.variant == TaroGlassButtonVariant.ghost
              ? Colors.transparent
              : TaroColors.surface,
          borderColor: widget.variant == TaroGlassButtonVariant.primary
              ? TaroColors.lavender.withValues(
                  alpha: TaroOpacity.borderStrong,
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 13,
            ),
            child: AnimatedScale(
              duration: TaroMotion.fast,
              curve: Curves.easeOutCubic,
              scale: !disabled && _pressed ? 0.97 : 1.0,
              child: AnimatedOpacity(
                duration: TaroMotion.fast,
                opacity: disabled ? 0.55 : (_pressed ? 0.82 : 1.0),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
