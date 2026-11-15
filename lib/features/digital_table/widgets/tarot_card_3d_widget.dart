import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/theme/app_colors.dart';

/// Procedural dark-lavender geometric card back — no image assets required.
class CardBackPainter extends CustomPainter {
  const CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(r, Paint()..color = AppColors.surface);

    // Hairline inner frame.
    canvas.drawRRect(
      r.deflate(size.width * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );

    // Diagonal lattice.
    final step = size.width * 0.22;
    final lattice = Paint()
      ..strokeWidth = 0.6
      ..color = AppColors.border;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), lattice);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), lattice);
    }

    // Center sigil: glowing ring + indigo diamond.
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.26;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.indigo.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.lavender.withValues(alpha: 0.75),
    );
    final d = radius * 0.55;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - d)
      ..lineTo(center.dx + d, center.dy)
      ..lineTo(center.dx, center.dy + d)
      ..lineTo(center.dx - d, center.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()..color = AppColors.indigo.withValues(alpha: 0.85),
    );
    final dot = radius * 0.2;
    canvas.drawCircle(
      center,
      dot,
      Paint()..color = AppColors.lavender.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CardBackPainter oldDelegate) => false;
}

/// RepaintBoundary-wrapped procedural card back.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.06),
        child: CustomPaint(
          size: Size(width, height),
          painter: const CardBackPainter(),
        ),
      ),
    );
  }
}

/// A single 3D tarot card: 2.5D perspective, isometric tilt, 600ms
/// `rotateY(π)` flip with a haptic at the 90° midpoint.
class TarotCard3DWidget extends StatefulWidget {
  const TarotCard3DWidget({
    super.key,
    required this.card,
    required this.isReversed,
    required this.state,
    required this.width,
    required this.height,
    this.tilt = true,
    this.interactive = true,
    this.onFlip,
    this.onTapFaceUp,
  });

  final TarotCard card;
  final bool isReversed;
  final SlotState state;
  final double width;
  final double height;
  final bool tilt; // isometric board tilt; false for flat previews
  final bool interactive; // false = pass taps through (e.g. almanac tiles)
  final VoidCallback? onFlip; // fired when the flip animation completes
  final VoidCallback? onTapFaceUp;

  @override
  State<TarotCard3DWidget> createState() => _TarotCard3DWidgetState();
}

class _TarotCard3DWidgetState extends State<TarotCard3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..addListener(_onFlipTick);

  bool _flipping = false;
  double _lastValue = 0;

  void _onFlipTick() {
    // Haptic exactly at the 90° midpoint of the flip.
    if (_lastValue < 0.5 && _flip.value >= 0.5) {
      HapticFeedback.mediumImpact();
    }
    _lastValue = _flip.value;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_flipping) return;
    if (widget.state == SlotState.faceDown) {
      setState(() => _flipping = true);
      _flip.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _flipping = false;
        widget.onFlip?.call(); // controller reveals the card
        _flip.value = 0; // face now rests at rotateY(0)
      });
    } else if (widget.state == SlotState.faceUp) {
      widget.onTapFaceUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final v = _flip.value;
          final showFace =
              widget.state == SlotState.faceUp || (_flipping && v >= 0.5);
          var angle = 0.0;
          if (_flipping) {
            angle = v < 0.5 ? math.pi * v : math.pi * v - math.pi;
          }
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, perspectiveEntry)
            ..rotateX(widget.tilt ? slotTiltRadians : 0)
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: showFace
                ? _CardFace(
                    card: widget.card,
                    isReversed: widget.isReversed,
                    width: widget.width,
                    height: widget.height,
                  )
                : CardBack(width: widget.width, height: widget.height),
          );
        },
      ),
    );
    if (!widget.interactive) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: content,
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.isReversed,
    required this.width,
    required this.height,
  });

  final TarotCard card;
  final bool isReversed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final face = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.055),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A24), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(width * 0.06),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.positionLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: width * 0.07,
                  letterSpacing: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${card.element.glyph} ${card.element.label.toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: width * 0.055,
                  letterSpacing: 1.2,
                  color: card.element.accent,
                ),
              ),
            ],
          ),
          Expanded(
            child: Image.asset(
              'assets/cards/${card.id}.png',
              fit: BoxFit.cover,
              // Drop artwork into assets/cards/<id>.png to replace the
              // built-in typographic face.
              errorBuilder: (_, _, _) =>
                  _TypographicFace(card: card, width: width),
            ),
          ),
          Text(
            card.arcana == Arcana.major
                ? 'MAJOR ARCANA'
                : '${card.suit!.label.toUpperCase()} · ${card.element.label.toUpperCase()}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: width * 0.05,
              letterSpacing: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
    return isReversed ? Transform.rotate(angle: math.pi, child: face) : face;
  }
}

class _TypographicFace extends StatelessWidget {
  const _TypographicFace({required this.card, required this.width});

  final TarotCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.element.glyph,
            style: TextStyle(fontSize: width * 0.16, color: card.element.accent),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: width * 0.09,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.keywords.map((k) => k.toLowerCase()).join(' · '),
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: width * 0.05,
              letterSpacing: 0.8,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

