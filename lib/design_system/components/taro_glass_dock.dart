import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Элемент нижнего дока (иконка + подпись).
class TaroDockItem {
  const TaroDockItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Стеклянный нижний док (Phase G3) — замена `_GlassNavBar` (4 раздела).
///
/// Принимает `items` + активный `index` + `onTap`, чтобы переиспользовать
/// существующую семантику навигации, не привязываясь к i18n.
/// Активный индикатор анимируется через [AnimatedAlign] (GPU-композиция),
/// высота слота ≥ 48 px (touch-target ≥ 44 px).
class TaroGlassDock extends StatelessWidget {
  const TaroGlassDock({
    required this.items,
    required this.index,
    required this.onTap,
    super.key,
  });

  final List<TaroDockItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final activeIndex = n == 0 ? 0 : index.clamp(0, n - 1);

    return TaroGlassSurface(
      radius: TaroRadii.dock,
      fillColor: TaroColors.surface,
      glow: TaroGlow.soft(
        TaroColors.lavender,
        alpha: 0.20,
        blur: 22,
        offset: const Offset(0, 6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const pad = 3.0;
          final innerWidth = (constraints.maxWidth - pad * 2).clamp(0.0, double.infinity);
          final itemWidth = n > 0 ? innerWidth / n : 0.0;
          final alignX = n <= 1 ? 0.0 : -1.0 + 2.0 * activeIndex / (n - 1);

          return Padding(
            padding: const EdgeInsets.all(pad),
            child: SizedBox(
              height: 48,
              child: Stack(
                children: [
                  if (n > 0)
                    AnimatedAlign(
                      duration: TaroMotion.normal,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(alignX, 0),
                      child: Container(
                        width: itemWidth,
                        height: 48,
                        decoration: BoxDecoration(
                          color: TaroColors.lavender.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            TaroRadii.dock - pad,
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
                          child: _DockItem(
                            item: items[i],
                            active: i == activeIndex,
                            onTap: () => onTap(i),
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

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final TaroDockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? TaroColors.lavender : TaroColors.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 0.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
