import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import 'shuffle_physics.dart';

/// Where a selected spread should launch the reader next.
///
/// * [digitalTable] — the default: enters the Active Digital Table (Step 2);
/// * [guidedSpread] — starts a Guided Physical Spread session in the Camera.
enum SpreadLaunchContext { digitalTable, guidedSpread }

/// Adaptive column count for the spread picker grid:
/// 3 tiles per row by default; 2 tiles per row on narrow screens (< 360 dp)
/// or with large system fonts (>= 1.25x).
int spreadGridColumnCount({
  required double maxWidth,
  required double textScale,
}) {
  if (maxWidth < 360.0 || textScale >= 1.25) return 2;
  return 3;
}

/// Shows the card/stone count only where it helps communicate the scale of
/// the spread (multi-card named spreads of 4+ cards whose title does not
/// already spell out the count or 3×3 grid).
bool shouldShowSpreadCardCount({
  required int cardCount,
  required String title,
}) {
  if (cardCount <= 3) return false;
  if (title.contains('$cardCount') || title.contains('3×3')) return false;
  return true;
}

/// One system-agnostic spread blueprint entry in the selection grid.
class _SpreadTileItem {
  const _SpreadTileItem({
    required this.keyId,
    required this.title,
    required this.cardCount,
    required this.isRune,
    required this.active,
    required this.geometry,
    required this.onTap,
  });

  final String keyId;
  final String title;
  final int cardCount;
  final bool isRune;
  final bool active;
  final SpreadBoardGeometry geometry;
  final VoidCallback onTap;
}

/// Step 1 — compact adaptive grid of preset spread schemas (3 tiles per row
/// by default; 2 on narrow screens or with large system fonts).
///
/// Every preset schema across Tarot, Lenormand and Runes is open without
/// subscription (no locks, no paywall). Tapping any preset tile immediately
/// selects it and enters the Active Digital Table (or routes through
/// [onSpreadSelected] in [SpreadLaunchContext.guidedSpread]).
class SpreadBlueprintGrid extends StatelessWidget {
  const SpreadBlueprintGrid({
    super.key,
    this.launchContext = SpreadLaunchContext.digitalTable,
    this.onSpreadSelected,
  });

  /// Where a selection launches the reader. [SpreadLaunchContext.digitalTable]
  /// activates the table immediately; [guidedSpread] routes through
  /// [onSpreadSelected] instead.
  final SpreadLaunchContext launchContext;

  /// Called with the selected spread's card count when [launchContext] is
  /// [SpreadLaunchContext.guidedSpread].
  final void Function(int cardCount)? onSpreadSelected;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final lang = context.watch<AppSettingsController>().language;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    void handleTap({
      required VoidCallback select,
      required int cardCount,
    }) {
      HapticFeedback.selectionClick();
      select();
      if (launchContext == SpreadLaunchContext.guidedSpread) {
        onSpreadSelected?.call(cardCount);
      } else {
        context.read<SpreadController>().activateSpread();
      }
    }

    final items = <_SpreadTileItem>[
      ...switch (ctrl.system) {
        DivinationSystem.tarot => [
            for (final t in SpreadType.values)
              _SpreadTileItem(
                keyId: 'tarot-${t.name}',
                title: AppStrings.t(lang, 'spread.tarot.${t.name}'),
                cardCount: t.cardCount,
                isRune: false,
                active: !ctrl.isCustomSpread && t == ctrl.spreadType,
                geometry: spreadBoardGeometryForTarot(t),
                onTap: () => handleTap(
                  cardCount: t.cardCount,
                  select: () =>
                      context.read<SpreadController>().setSpreadType(t),
                ),
              ),
          ],
        DivinationSystem.lenormand => [
            for (final s in LenormandSpread.values)
              _SpreadTileItem(
                keyId: 'lenormand-${s.name}',
                title: AppStrings.t(lang, 'spread.lenormand.${s.name}'),
                cardCount: s.cardCount,
                isRune: false,
                active: !ctrl.isCustomSpread && s == ctrl.lenormandSpread,
                geometry: spreadBoardGeometryForLenormand(s),
                onTap: () => handleTap(
                  cardCount: s.cardCount,
                  select: () => context
                      .read<SpreadController>()
                      .setLenormandSpread(s),
                ),
              ),
          ],
        DivinationSystem.runes => [
            for (final c in RuneCast.values)
              _SpreadTileItem(
                keyId: 'runes-${c.name}',
                title: AppStrings.t(lang, 'spread.runes.${c.name}'),
                cardCount: c.cardCount,
                isRune: true,
                active: !ctrl.isCustomSpread && c == ctrl.runeCast,
                geometry: spreadBoardGeometryForRune(c),
                onTap: () => handleTap(
                  cardCount: c.cardCount,
                  select: () => context.read<SpreadController>().setRuneCast(c),
                ),
              ),
          ],
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = spreadGridColumnCount(
          maxWidth: constraints.maxWidth,
          textScale: textScale,
        );
        final titleSize = columns == 2 ? 16.5 : 15.0;
        final clampedScale = textScale.clamp(1.0, 2.0);
        final miniatureHeight = columns == 2 ? 68.0 : 58.0;
        final textBlockHeight =
            (2 * titleSize * 1.18 + 16.0) * clampedScale;
        final tileHeight = miniatureHeight + 8.0 + textBlockHeight + 20.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GridView.builder(
            key: const ValueKey('spread-blueprint-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: tileHeight,
            ),
            itemBuilder: (context, i) => _SpreadGridTile(
              item: items[i],
              lang: lang,
              titleFontSize: titleSize,
            ),
          ),
        );
      },
    );
  }
}

class _SpreadGridTile extends StatelessWidget {
  const _SpreadGridTile({
    required this.item,
    required this.lang,
    required this.titleFontSize,
  });

  final _SpreadTileItem item;
  final AppLanguage lang;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final showCount = shouldShowSpreadCardCount(
      cardCount: item.cardCount,
      title: item.title,
    );
    final borderColor = item.active
        ? TaroColors.lavender
        : TaroColors.mist.withValues(alpha: TaroOpacity.borderStrong);
    final backgroundColor = item.active
        ? TaroColors.lavender.withValues(alpha: 0.16)
        : TaroColors.surface.withValues(alpha: 0.72);

    return GestureDetector(
      key: ValueKey('spread-tile-${item.keyId}'),
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: item.active ? 1.2 : 1.0,
          ),
          boxShadow: item.active
              ? TaroGlow.soft(TaroColors.lavender, alpha: 0.18, blur: 16)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: CustomPaint(
                  painter: SpreadMiniaturePainter(
                    geometry: item.geometry,
                    isRune: item.isRune,
                    active: item.active,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.display(
                fontSize: titleFontSize,
                height: 1.12,
                fontWeight: FontWeight.w700,
                color: item.active ? TaroColors.lavender : TaroColors.textPrimary,
              ),
            ),
            if (showCount) ...[
              const SizedBox(height: 3),
              Text(
                AppStrings.cardCount(
                  lang,
                  item.cardCount,
                  isRune: item.isRune,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Miniature preview painted directly from a spread's real [SpreadBoardGeometry]
/// rectangles, uniformly scaled and centered inside the available canvas.
class SpreadMiniaturePainter extends CustomPainter {
  const SpreadMiniaturePainter({
    required this.geometry,
    required this.isRune,
    this.active = false,
  });

  final SpreadBoardGeometry geometry;
  final bool isRune;
  final bool active;

  /// Projects the real design-space slot rectangles into [size], preserving
  /// relative positions and card aspect ratio. Exposed as a pure helper so
  /// unit tests can verify miniature fidelity against board geometry.
  static List<Rect> projectSlotRects(
    SpreadBoardGeometry geometry,
    Size size, {
    double padding = 3.0,
  }) {
    if (geometry.slotRects.isEmpty || size.isEmpty) return const [];
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final r in geometry.slotRects) {
      if (r.left < minX) minX = r.left;
      if (r.top < minY) minY = r.top;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
    }
    final boundsW = math.max(1.0, maxX - minX);
    final boundsH = math.max(1.0, maxY - minY);
    final availW = math.max(1.0, size.width - padding * 2);
    final availH = math.max(1.0, size.height - padding * 2);

    // Cap single-card height so 1-card and 3-card spreads read proportionally
    // alongside denser layouts without appearing oversized.
    final maxCardH = availH * 0.68;
    final fitScale = math.min(availW / boundsW, availH / boundsH);
    final cardCapScale = maxCardH / deckHeight;
    final scale = math.min(fitScale, cardCapScale);

    final drawnW = boundsW * scale;
    final drawnH = boundsH * scale;
    final ox = (size.width - drawnW) / 2;
    final oy = (size.height - drawnH) / 2;

    return [
      for (final r in geometry.slotRects)
        Rect.fromLTWH(
          ox + (r.left - minX) * scale,
          oy + (r.top - minY) * scale,
          r.width * scale,
          r.height * scale,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final projected = projectSlotRects(geometry, size);
    if (projected.isEmpty) return;

    final backing = Paint()..color = TaroColors.background.withValues(alpha: 0.92);
    final fill = Paint()
      ..color = TaroColors.lavender.withValues(alpha: active ? 0.26 : 0.14);
    final stroke = Paint()
      ..color = TaroColors.lavender.withValues(alpha: active ? 0.95 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = projected.length >= 9 ? 0.9 : 1.05;

    for (var i = 0; i < projected.length; i++) {
      final rect = projected[i];
      if (isRune) {
        final pebble = Rect.fromCenter(
          center: rect.center,
          width: math.min(rect.width, rect.height) * 0.86,
          height: math.min(rect.width, rect.height) * 0.98,
        );
        canvas.drawOval(pebble, backing);
        canvas.drawOval(pebble, fill);
        canvas.drawOval(pebble, stroke);
      } else {
        final radius = Radius.circular(
          (math.min(rect.width, rect.height) * 0.18).clamp(1.2, 3.2),
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);
        canvas.drawRRect(rrect, backing);
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpreadMiniaturePainter oldDelegate) =>
      oldDelegate.geometry.canvasSize != geometry.canvasSize ||
      oldDelegate.geometry.slotRects.length != geometry.slotRects.length ||
      oldDelegate.geometry.crossingSlotIndex != geometry.crossingSlotIndex ||
      oldDelegate.isRune != isRune ||
      oldDelegate.active != active;
}
