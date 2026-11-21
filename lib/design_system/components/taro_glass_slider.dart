import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Стеклянный ползунок в стиле iOS 27 (Phase G3): настройки скорости/громкости.
///
/// Touch-target высотой ≥ 44 px, полная `Semantics(slider: true)` с шагами
/// увеличения/уменьшения, GPU-композитное масштабирование бегунка при нажатии.
class TaroGlassSlider extends StatefulWidget {
  const TaroGlassSlider({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.valueLabel,
    this.semanticLabel,
    super.key,
  }) : assert(max > min, 'max must be greater than min');

  final double value;

  /// null → disabled.
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String? valueLabel;
  final String? semanticLabel;

  @override
  State<TaroGlassSlider> createState() => _TaroGlassSliderState();
}

class _TaroGlassSliderState extends State<TaroGlassSlider> {
  bool _dragging = false;
  int? _lastDivision;

  bool get _disabled => widget.onChanged == null;

  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _snap(double rawFraction) {
    final clamped = rawFraction.clamp(0.0, 1.0);
    final divisions = widget.divisions;
    if (divisions == null || divisions <= 0) {
      return widget.min + clamped * (widget.max - widget.min);
    }
    final step = (clamped * divisions).round();
    if (step != _lastDivision) {
      _lastDivision = step;
      HapticFeedback.selectionClick();
    }
    return widget.min + (step / divisions) * (widget.max - widget.min);
  }

  void _updateFromLocalX(double dx, double width) {
    if (_disabled || width <= 0) return;
    final next = _snap(dx / width);
    if ((next - widget.value).abs() > 1e-9) {
      widget.onChanged!(next);
    }
  }

  double get _semanticStep {
    final divisions = widget.divisions;
    if (divisions != null && divisions > 0) {
      return (widget.max - widget.min) / divisions;
    }
    return (widget.max - widget.min) * 0.1;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _fraction;
    final displayValue = widget.valueLabel ?? '${(fraction * 100).round()}%';
    final incValue = (widget.value + _semanticStep).clamp(widget.min, widget.max);
    final decValue = (widget.value - _semanticStep).clamp(widget.min, widget.max);
    final incFraction =
        ((incValue - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final decFraction =
        ((decValue - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final alignX = -1.0 + 2.0 * fraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null || widget.valueLabel != null) ...[
          Row(
            children: [
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!.toUpperCase(),
                    style: AppTypography.label(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                displayValue,
                style: AppTypography.label(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _disabled ? TaroColors.textSecondary : TaroColors.lavender,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Semantics(
          slider: true,
          enabled: !_disabled,
          label: widget.semanticLabel ?? widget.label,
          value: displayValue,
          increasedValue: _disabled ? null : '${(incFraction * 100).round()}%',
          decreasedValue: _disabled ? null : '${(decFraction * 100).round()}%',
          onIncrease: _disabled ? null : () => widget.onChanged!(incValue),
          onDecrease: _disabled ? null : () => widget.onChanged!(decValue),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _disabled
                    ? null
                    : (details) {
                        HapticFeedback.selectionClick();
                        _updateFromLocalX(details.localPosition.dx, width);
                        widget.onChangeEnd?.call(
                          _snap(details.localPosition.dx / width),
                        );
                      },
                onHorizontalDragStart: _disabled
                    ? null
                    : (details) {
                        setState(() => _dragging = true);
                        _updateFromLocalX(details.localPosition.dx, width);
                      },
                onHorizontalDragUpdate: _disabled
                    ? null
                    : (details) =>
                        _updateFromLocalX(details.localPosition.dx, width),
                onHorizontalDragEnd: _disabled
                    ? null
                    : (_) {
                        setState(() => _dragging = false);
                        _lastDivision = null;
                        widget.onChangeEnd?.call(widget.value);
                      },
                onHorizontalDragCancel: () {
                  setState(() => _dragging = false);
                  _lastDivision = null;
                },
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 10,
                        width: double.infinity,
                        child: TaroGlassSurface(
                          radius: TaroRadii.pill,
                          visibility: _disabled ? 0.45 : 1.0,
                          fillColor: TaroColors.surface,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(TaroRadii.pill),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: fraction,
                                heightFactor: 1.0,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        TaroColors.indigo,
                                        TaroColors.lavender,
                                        TaroColors.dawn,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(alignX, 0),
                        child: AnimatedScale(
                          duration: TaroMotion.fast,
                          scale: _dragging ? 1.15 : 1.0,
                          child: Opacity(
                            opacity: _disabled ? 0.45 : 1.0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: TaroColors.textPrimary,
                                border: Border.all(
                                  color: TaroColors.lavender.withValues(
                                    alpha: TaroOpacity.borderStrong,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: TaroGlow.soft(
                                  TaroColors.lavender,
                                  alpha: _dragging ? 0.55 : 0.35,
                                  blur: _dragging ? 16 : 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
