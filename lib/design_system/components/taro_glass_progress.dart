import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_tokens.dart';

/// Индикатор прогресса / загрузки Tarot Tree (Phase G4): загрузка и синтез
/// Оракула. Поддерживает линейную полосу (`linear: true`, determinate /
/// indeterminate) и компактный круговой индикатор (`linear: false`).
class TaroGlassProgress extends StatefulWidget {
  const TaroGlassProgress({
    this.value,
    this.label,
    this.linear = true,
    this.height = 6.0,
    this.size = 22.0,
    this.semanticLabel,
    super.key,
  });

  /// `0.0..1.0` для детерминированного прогресса; `null` → плавное свечение.
  final double? value;
  final String? label;
  final bool linear;
  final double height;
  final double size;
  final String? semanticLabel;

  @override
  State<TaroGlassProgress> createState() => _TaroGlassProgressState();
}

class _TaroGlassProgressState extends State<TaroGlassProgress>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  bool get _indeterminate => widget.value == null && widget.linear;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant TaroGlassProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    if (_indeterminate) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.value == null
        ? null
        : '${(widget.value!.clamp(0.0, 1.0) * 100).round()}%';

    if (!widget.linear) {
      return Semantics(
        label: widget.semanticLabel ?? widget.label ?? 'Loading',
        value: pct,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: widget.value?.clamp(0.0, 1.0),
                strokeWidth: 2,
                color: TaroColors.lavender,
                backgroundColor: TaroColors.mist.withValues(alpha: 0.16),
              ),
            ),
            if (widget.label != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label!,
                  style: AppTypography.body(
                    fontSize: 13,
                    color: TaroColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(TaroRadii.pill),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(TaroRadii.pill),
          border: Border.all(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
            width: 0.7,
          ),
        ),
        child: widget.value != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: widget.value!.clamp(0.0, 1.0),
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
              )
            : AnimatedBuilder(
                animation: _controller!,
                builder: (context, _) {
                  final alignX = -1.6 + 3.2 * _controller!.value;
                  return Align(
                    alignment: Alignment(alignX, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.42,
                      heightFactor: 1.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TaroRadii.pill),
                          gradient: LinearGradient(
                            colors: [
                              TaroColors.lavender.withValues(alpha: 0.0),
                              TaroColors.lavender,
                              TaroColors.dawn,
                              TaroColors.lavender.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.label ?? 'Progress',
      value: pct,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label!,
                    style: AppTypography.label(
                      fontSize: 9.5,
                      letterSpacing: 0.9,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ),
                if (pct != null)
                  Text(
                    pct,
                    style: AppTypography.label(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.lavender,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          bar,
        ],
      ),
    );
  }
}
