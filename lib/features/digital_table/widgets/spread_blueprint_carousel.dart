import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/divination_system.dart';
import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import '../../shell/widgets/pro_subscription_sheet.dart';

/// One system-agnostic spread blueprint entry in the carousel.
class _SpreadBlueprint {
  const _SpreadBlueprint({
    required this.label,
    required this.cardCount,
    required this.isPro,
    required this.isRune,
    required this.active,
    required this.miniSlots,
    required this.onTap,
  });

  final String label;
  final int cardCount;
  final bool isPro;
  final bool isRune;
  final bool active;
  final List<Offset> miniSlots;
  final VoidCallback onTap;
}

/// Compact horizontal swipeable carousel (`height: 92`) of spread blueprints,
/// placed below the system/pack header rows and directly above the deck.
/// Free spreads switch the table geometry immediately; locked PRO spreads
/// open [ProSubscriptionSheet].
class SpreadBlueprintCarousel extends StatelessWidget {
  const SpreadBlueprintCarousel({super.key});

  static const double height = 92.0;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final proUnlocked = context.watch<AppSettingsController>().isProUnlocked;

    void handleTap({required bool isPro, required VoidCallback select}) {
      HapticFeedback.selectionClick();
      if (isPro && !proUnlocked) {
        ProSubscriptionSheet.show(context);
        return;
      }
      select();
    }

    final blueprints = <_SpreadBlueprint>[
      ...switch (ctrl.system) {
        DivinationSystem.tarot => [
            for (final t in SpreadType.values)
              _SpreadBlueprint(
                label: t.label,
                cardCount: t.cardCount,
                isPro: t.isPro,
                isRune: false,
                active: t == ctrl.spreadType,
                miniSlots: t.miniSlots,
                onTap: () => handleTap(
                  isPro: t.isPro,
                  select: () =>
                      context.read<SpreadController>().setSpreadType(t),
                ),
              ),
          ],
        DivinationSystem.lenormand => [
            for (final s in LenormandSpread.values)
              _SpreadBlueprint(
                label: s.label,
                cardCount: s.cardCount,
                isPro: s.isPro,
                isRune: false,
                active: s == ctrl.lenormandSpread,
                miniSlots: s.miniSlots,
                onTap: () => handleTap(
                  isPro: s.isPro,
                  select: () => context
                      .read<SpreadController>()
                      .setLenormandSpread(s),
                ),
              ),
          ],
        DivinationSystem.runes => [
            for (final c in RuneCast.values)
              _SpreadBlueprint(
                label: c.label,
                cardCount: c.cardCount,
                isPro: c.isPro,
                isRune: true,
                active: c == ctrl.runeCast,
                miniSlots: c.miniSlots,
                onTap: () => handleTap(
                  isPro: c.isPro,
                  select: () => context.read<SpreadController>().setRuneCast(c),
                ),
              ),
          ],
      },
    ];

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: blueprints.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = blueprints[i];
          return _BlueprintCard(blueprint: b, locked: b.isPro && !proUnlocked);
        },
      ),
    );
  }
}

class _BlueprintCard extends StatelessWidget {
  const _BlueprintCard({required this.blueprint, required this.locked});

  final _SpreadBlueprint blueprint;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final borderColor = blueprint.active
        ? AppColors.lavender
        : (locked
            ? AppColors.border
            : AppColors.lavender.withValues(alpha: 0.32));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: blueprint.onTap,
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: CustomPaint(
                  painter: _BlueprintWireframePainter(
                    slots: blueprint.miniSlots,
                    isRune: blueprint.isRune,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              blueprint.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.1,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: blueprint.active
                    ? AppColors.lavender
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${blueprint.cardCount} CARD'
                    '${blueprint.cardCount == 1 ? '' : 'S'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 7,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                if (blueprint.isPro) ...[
                  const SizedBox(width: 4),
                  Text(
                    locked ? '🔒 PRO' : 'PRO',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 7.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: locked ? AppColors.textMuted : AppColors.lavender,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny glowing wireframe: card rectangles (Tarot/Lenormand) or rune pebbles,
/// laid out by their normalized [slots] coordinates.
class _BlueprintWireframePainter extends CustomPainter {
  const _BlueprintWireframePainter({required this.slots, required this.isRune});

  final List<Offset> slots;
  final bool isRune;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.lavender.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fill = Paint()..color = AppColors.lavender.withValues(alpha: 0.14);

    for (final s in slots) {
      final center = Offset(s.dx * size.width, s.dy * size.height);
      if (isRune) {
        canvas.drawCircle(center, 6.5, fill);
        canvas.drawCircle(center, 6.5, stroke);
      } else {
        final rect = Rect.fromCenter(
          center: center,
          width: 20,
          height: 28,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintWireframePainter oldDelegate) =>
      oldDelegate.slots != slots || oldDelegate.isRune != isRune;
}
