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

/// Стеклянный нижний док — зеркало `_GlassNavBar` (4 раздела).
///
/// Принимает `items` + активный `index` + `onTap`, чтобы переиспользовать
/// существующую семантику навигации, не привязываясь к i18n.
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
    return TaroGlassSurface(
      radius: TaroRadii.dock,
      fillColor: TaroColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _DockItem(
                  item: items[i],
                  active: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
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
