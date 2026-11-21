import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Один сегмент сегментированного контрола.
class TaroGlassSegment<T> {
  const TaroGlassSegment({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });
  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

/// Сегментированный контрол со плавным скольжением активного индикатора.
///
/// Трек — стеклянная поверхность; индикатор — анимированная заливка
/// (`AnimatedAlign`, GPU-композиция без анимации layout-свойств), что даёт
/// «плавный переход активного сегмента» без вложенного стекла.
class TaroGlassSegmentedControl<T> extends StatelessWidget {
  const TaroGlassSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<TaroGlassSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = segments.length;
    final rawIndex = segments.indexWhere((s) => s.value == value);
    final activeIndex = rawIndex < 0 ? 0 : rawIndex;

    return TaroGlassSurface(
      radius: TaroRadii.segment,
      fillColor: TaroColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const pad = 3.0;
          const gap = 3.0;
          final segWidth =
              (constraints.maxWidth - pad * 2 - gap * (n - 1)) / n;
          final alignX =
              n <= 1 ? 0.0 : -1.0 + 2.0 * activeIndex / (n - 1);

          return Padding(
            padding: const EdgeInsets.all(pad),
            child: SizedBox(
              height: 38,
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: TaroMotion.normal,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(alignX, 0),
                    child: Container(
                      width: segWidth,
                      height: 38,
                      decoration: BoxDecoration(
                        color: TaroColors.lavender.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(
                          TaroRadii.segment - 3,
                        ),
                        border: Border.all(
                          color: TaroColors.lavender.withValues(
                            alpha: TaroOpacity.borderStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _SegmentTap(
                            key: segments[i].key,
                            segment: segments[i],
                            active: i == activeIndex,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onChanged(segments[i].value);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SegmentTap<T> extends StatelessWidget {
  const _SegmentTap({
    super.key,
    required this.segment,
    required this.active,
    required this.onTap,
  });

  final TaroGlassSegment<T> segment;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? TaroColors.textPrimary : TaroColors.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: segment.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null) ...[
                  Icon(segment.icon, size: 14, color: color),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      style: AppTypography.label(
                        fontSize: 10.5,
                        letterSpacing: 0.7,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
