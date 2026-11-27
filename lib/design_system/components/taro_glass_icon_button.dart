import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../taro_glass.dart';
import '../taro_tokens.dart';
import 'taro_glass_button.dart';

/// Стеклянная кнопка-иконка (Phase G3): mic / `+` / send / back / close.
///
/// Гарантирует touch-target ≥ 44×44 px, [Semantics] с `tooltip`, состояние
/// `active` и тактильный отклик.
class TaroGlassIconButton extends StatefulWidget {
  const TaroGlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.variant = TaroGlassButtonVariant.secondary,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.tint,
    this.fillColor,
    this.borderColor,
    this.active = false,
    super.key,
  });

  final IconData icon;

  /// null → disabled.
  final VoidCallback? onPressed;

  /// Используется для [Tooltip] и `Semantics(label)`.
  final String tooltip;
  final TaroGlassButtonVariant variant;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? tint;
  final Color? fillColor;
  final Color? borderColor;
  final bool active;

  @override
  State<TaroGlassIconButton> createState() => _TaroGlassIconButtonState();
}

class _TaroGlassIconButtonState extends State<TaroGlassIconButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null;

  void _onTap() {
    if (_disabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TaroPalette.of(context);
    final disabled = _disabled;
    final dimension = math.max(widget.size, 44.0);
    final isPrimary =
        widget.active || widget.variant == TaroGlassButtonVariant.primary;

    final tint = widget.tint ??
        (isPrimary
            ? (palette.isMoonlit
                ? TaroColors.lanternAmber.withValues(alpha: 0.22)
                : TaroColors.lavender.withValues(alpha: 0.24))
            : switch (widget.variant) {
                TaroGlassButtonVariant.primary =>
                  TaroColors.lavender.withValues(alpha: 0.22),
                TaroGlassButtonVariant.secondary => palette.isMoonlit
                    ? palette.glassTint
                    : TaroColors.mist.withValues(alpha: 0.12),
                TaroGlassButtonVariant.ghost => null,
              });

    final resolvedIconColor = disabled
        ? TaroColors.textSecondary.withValues(alpha: 0.5)
        : widget.iconColor ??
            (isPrimary
                ? (palette.isMoonlit
                    ? TaroColors.lanternAmberBright
                    : TaroColors.lavender)
                : TaroColors.textPrimary);

    return Semantics(
      button: true,
      enabled: !disabled,
      toggled: widget.active ? true : null,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
          onTapCancel: disabled ? null : () => setState(() => _pressed = false),
          onTap: _onTap,
          child: AnimatedScale(
            duration: TaroMotion.fast,
            scale: _pressed ? 0.94 : 1.0,
            child: SizedBox(
              width: dimension,
              height: dimension,
              child: TaroGlassSurface(
                radius: TaroRadii.pill,
                tint: tint,
                visibility: disabled ? 0.45 : (_pressed ? 0.85 : 1.0),
                fillColor: widget.fillColor ??
                    (widget.variant == TaroGlassButtonVariant.ghost &&
                            !widget.active
                        ? Colors.transparent
                        : palette.surface),
                borderColor: widget.borderColor ??
                    (isPrimary ? palette.activeOutline : palette.borderHairline),
                glow: widget.active
                    ? TaroGlow.soft(
                        palette.lanternGlow,
                        alpha: palette.isMoonlit ? 0.28 : 0.35,
                        blur: 16,
                      )
                    : null,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: resolvedIconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
