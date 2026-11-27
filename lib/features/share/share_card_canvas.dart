import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/element_colors.dart';
import '../../design_system/taro.dart';
import '../../state/deck_pack_controller.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import 'share_card_payload.dart';

/// Fixed 9:16 logical canvas (`360 x 640`). Exported at `pixelRatio: 3.0`,
/// this yields a crisp `1080 x 1920` editorial PNG ready for Instagram /
/// Telegram Stories in Tarot Tree's obsidian-forest aesthetic.
class ShareCardCanvas extends StatelessWidget {
  const ShareCardCanvas({
    super.key,
    required this.payload,
    required this.phraseIndex,
    required this.atmosphere,
    required this.language,
  });

  static const double logicalWidth = 360;
  static const double logicalHeight = 640;

  final ShareCardPayload payload;
  final int phraseIndex;
  final ShareCardAtmosphere atmosphere;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final lead = payload.leadCard;
    final accent = lead != null ? lead.card.element.accent : TaroColors.lavender;
    final phrase = payload.phraseOptions.isEmpty
        ? ''
        : payload.phraseOptions[phraseIndex % payload.phraseOptions.length];
    final heroCards = payload.heroCards;

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Atmospheric obsidian-forest / oak / dusk backdrop
            _AtmosphereBackdrop(atmosphere: atmosphere, accent: accent),
            // 2. Editorial hairline frame, orbital arc & starlight dust
            CustomPaint(
              painter: _EditorialCelestialPainter(accent: accent),
            ),
            // 3. Foreground composition
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
              child: Column(
                children: [
                  // Top date + moon glyph
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        payload.moonGlyph,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        payload.dateLabel.toUpperCase(),
                        style: AppTypography.label(
                          fontSize: 9.5,
                          letterSpacing: 1.8,
                          color: TaroColors.textSecondary.withValues(
                            alpha: 0.88,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Spread / Ritual title
                  Text(
                    payload.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.label(
                      fontSize: 11.5,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.lavender,
                    ),
                  ),
                  if (payload.subtitle != null &&
                      payload.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      payload.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: TaroColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  // Hero card stage (1 card portrait OR editorial 2-3 card fan)
                  _HeroCardStage(
                    cards: heroCards,
                    overflowCount: payload.overflowCount,
                    accent: accent,
                    language: language,
                  ),
                  const Spacer(flex: 2),
                  // One strong editorial phrase
                  _EditorialQuoteBlock(phrase: phrase, accent: accent),
                  const Spacer(flex: 2),
                  // Branded watermark footer
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/loader/logo.png',
                          width: 18,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TAROT TREE  ·  SOSHALLITBE.CYOU',
                          style: AppTypography.label(
                            fontSize: 8.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                            color: TaroColors.textSecondary.withValues(
                              alpha: 0.78,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmosphereBackdrop extends StatelessWidget {
  const _AtmosphereBackdrop({required this.atmosphere, required this.accent});

  final ShareCardAtmosphere atmosphere;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final asset = switch (atmosphere) {
      ShareCardAtmosphere.forest => TaroBackgroundAssets.forest,
      ShareCardAtmosphere.oak => TaroBackgroundAssets.oak,
      ShareCardAtmosphere.obsidian => null,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0D16),
                TaroColors.background,
                TaroColors.duskMid,
                Color(0xFF0C101B),
              ],
              stops: [0.0, 0.30, 0.68, 1.0],
            ),
          ),
        ),
        if (asset != null)
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Deep obsidian-forest editorial vignette so typography pops effortlessly
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.24, 0.56, 0.82, 1.0],
              colors: [
                const Color(0xFF0A0D16).withValues(alpha: asset != null ? 0.78 : 0.35),
                const Color(0xFF0C101B).withValues(alpha: asset != null ? 0.52 : 0.15),
                const Color(0xFF151725).withValues(alpha: asset != null ? 0.44 : 0.12),
                const Color(0xFF0C101B).withValues(alpha: asset != null ? 0.80 : 0.45),
                const Color(0xFF090B12).withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        // Soft elemental halo behind the hero card center
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.14),
              radius: 0.62,
              colors: [
                accent.withValues(alpha: 0.22),
                TaroColors.lavender.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCardStage extends StatelessWidget {
  const _HeroCardStage({
    required this.cards,
    required this.overflowCount,
    required this.accent,
    required this.language,
  });

  final List<ShareCardItem> cards;
  final int overflowCount;
  final Color accent;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SeerEyeIcon(size: 54, color: TaroColors.lavender);
    }

    if (cards.length == 1) {
      final item = cards.single;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FramedArtCard(item: item, width: 158, height: 258, accent: accent),
          const SizedBox(height: 16),
          Text(
            item.card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElementIcon(item.card.element, size: 13),
              const SizedBox(width: 6),
              Text(
                item.isReversed
                    ? '${AppStrings.t(language, 'almanac.${item.card.element.name}').toUpperCase()}  ·  ${AppStrings.t(language, 'common.reversed').toUpperCase()}'
                    : AppStrings.t(language, 'almanac.${item.card.element.name}').toUpperCase(),
                style: AppTypography.label(
                  fontSize: 9.5,
                  letterSpacing: 1.4,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Editorial triptych / pair fan (Stack guarantees center card on top & zero overflow)
    final isTwo = cards.length == 2;
    final cardW = isTwo ? 116.0 : 96.0;
    final cardH = cardW * 360 / 220;
    final stageW = 300.0;
    final stageH = cardH + 26;
    final centerX = (stageW - cardW) / 2;

    Widget positionedCard(int i, double dx, double dy, double angle, bool elevated) {
      return Positioned(
        left: centerX + dx,
        top: 12 + dy,
        child: Transform.rotate(
          angle: angle,
          child: _FramedArtCard(
            item: cards[i],
            width: cardW,
            height: cardH,
            accent: accent,
            elevated: elevated,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stageW,
          height: stageH,
          child: Stack(
            clipBehavior: Clip.none,
            children: isTwo
                ? [
                    positionedCard(0, -56, 4, -0.075, false),
                    positionedCard(1, 56, 4, 0.075, true),
                  ]
                : [
                    positionedCard(0, -86, 12, -0.095, false),
                    positionedCard(2, 86, 12, 0.095, false),
                    positionedCard(1, 0, -6, 0.0, true),
                  ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          [
            for (final c in cards)
              c.isReversed ? '${c.card.name} ↺' : c.card.name,
          ].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.display(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: TaroColors.textPrimary,
          ),
        ),
        if (overflowCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            AppStrings.t(language, 'share.moreCards', {'count': overflowCount})
                .toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 1.4,
              color: TaroColors.lavender.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}

class _FramedArtCard extends StatelessWidget {
  const _FramedArtCard({
    required this.item,
    required this.width,
    required this.height,
    required this.accent,
    this.elevated = true,
  });

  final ShareCardItem item;
  final double width;
  final double height;
  final Color accent;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final widgetArt = switch (item.card.system) {
      DivinationSystem.tarot => TarotCard3DWidget(
        card: (item.card as TarotDivinationCard).card,
        isReversed: item.isReversed,
        state: SlotState.faceUp,
        width: width,
        height: height,
        tilt: false,
        interactive: false,
      ),
      DivinationSystem.lenormand => LenormandCard3DWidget(
        card: (item.card as LenormandDivinationCard).card,
        isReversed: false,
        state: SlotState.faceUp,
        width: width,
        height: height,
        tilt: false,
        interactive: false,
      ),
      DivinationSystem.runes => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: SizedBox(
            width: width * 0.88,
            height: width * 1.02,
            child: RuneStoneView(
              stone: (item.card as RuneDivinationCard).stone,
              pack: context.watch<DeckPackController>().activeRunePack,
              faceUp: true,
              merkstave: item.isReversed,
              ignite: 1.0,
              seed: item.card.id + 11,
            ),
          ),
        ),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.62),
            blurRadius: elevated ? 26 : 16,
            offset: const Offset(0, 12),
          ),
          if (elevated)
            BoxShadow(
              color: accent.withValues(alpha: 0.24),
              blurRadius: 24,
              spreadRadius: -2,
            ),
        ],
      ),
      child: widgetArt,
    );
  }
}

class _EditorialQuoteBlock extends StatelessWidget {
  const _EditorialQuoteBlock({required this.phrase, required this.accent});

  final String phrase;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101B).withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TaroColors.lavender.withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 1.5,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '“$phrase”',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              fontSize: 17.5,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.32,
              color: TaroColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialCelestialPainter extends CustomPainter {
  const _EditorialCelestialPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final inner = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);

    final borderPaint = Paint()
      ..color = TaroColors.lavender.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final hairlinePaint = Paint()
      ..color = TaroColors.mist.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(18)),
      borderPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(15)),
      hairlinePaint,
    );

    // Subtle astronomical orbit arc framing the card zone
    final arcPaint = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.43),
      size.width * 0.41,
      arcPaint,
    );

    // Subtle starlight dust specks (deterministic positions)
    final starPaint = Paint()..style = PaintingStyle.fill;
    const coords = [
      (0.14, 0.14, 1.3, 0.45),
      (0.86, 0.16, 1.1, 0.35),
      (0.10, 0.34, 0.9, 0.28),
      (0.91, 0.38, 1.2, 0.40),
      (0.16, 0.64, 1.0, 0.30),
      (0.84, 0.62, 1.4, 0.42),
      (0.22, 0.88, 0.9, 0.25),
      (0.79, 0.89, 1.1, 0.32),
    ];
    for (final (nx, ny, r, a) in coords) {
      starPaint.color = TaroColors.textPrimary.withValues(alpha: a);
      canvas.drawCircle(
        Offset(size.width * nx, size.height * ny),
        r,
        starPaint,
      );
    }

    // Small 4-point accent star at top of the orbital arc
    final starCenter = Offset(size.width * 0.5, size.height * 0.43 - size.width * 0.41);
    final starPath = Path();
    const sr = 4.2;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final tip = starCenter + Offset(math.cos(angle) * sr, math.sin(angle) * sr);
      if (i == 0) {
        starPath.moveTo(tip.dx, tip.dy);
      } else {
        starPath.quadraticBezierTo(starCenter.dx, starCenter.dy, tip.dx, tip.dy);
      }
    }
    starPath.quadraticBezierTo(
      starCenter.dx,
      starCenter.dy,
      starCenter.dx + sr,
      starCenter.dy,
    );
    canvas.drawPath(
      starPath,
      Paint()..color = TaroColors.lavender.withValues(alpha: 0.52),
    );
  }

  @override
  bool shouldRepaint(_EditorialCelestialPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
