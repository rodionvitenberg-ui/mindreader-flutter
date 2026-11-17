import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// The `✦ SYNTHESIZE IN CHAT →` call to action — PERMANENTLY anchored at
/// the bottom of the Digital Table (Pane 0), right above the bottom
/// navigation dock.
///
/// Two states:
/// * **Dormant** (base spread not fully dealt & flipped face-up): dim
///   (`opacity 0.42`), muted slate border, no glow; the label shows the
///   flip progress (`FLIP ALL CARDS` / `N OF M FACE-UP`); tapping fires
///   only a gentle haptic hint.
/// * **Ignited** (all base cards face-up): an ignition burst plays once
///   (`scale 0.95 → 1.04 → 1.0` + bright flash) and a continuous
///   starlight/sparkle border + pulsing lavender/cyan aura orbits the
///   button. Tapping runs the synthesis and slides to the Oracle Chat.
class SynthesizeChatCta extends StatefulWidget {
  const SynthesizeChatCta({
    super.key,
    required this.ignited,
    required this.synthesized,
    required this.generating,
    required this.faceUp,
    required this.total,
    required this.onTap,
  });

  /// True the moment every base spread card is dealt AND flipped face-up.
  final bool ignited;

  /// True once a synthesis already exists — the label becomes
  /// `✦ OPEN ORACLE CHAT →`.
  final bool synthesized;

  /// True while the synthesis is being woven (label: WEAVING · · ·).
  final bool generating;

  /// Face-up count within the base spread (progress hint while dormant).
  final int faceUp;

  /// Total cards of the base spread.
  final int total;

  final VoidCallback onTap;

  @override
  State<SynthesizeChatCta> createState() => _SynthesizeChatCtaState();
}

class _SynthesizeChatCtaState extends State<SynthesizeChatCta>
    with TickerProviderStateMixin {
  /// Continuous starlight shimmer — drives the sparkle border painter.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// One-shot ignition burst (scale 0.95 → 1.04 → 1.0 + bright flash).
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  late final TweenSequence<double> _burstScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.95, end: 1.04)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.04, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 50,
    ),
  ]);

  @override
  void initState() {
    super.initState();
    // A restored/readied session mounts already ignited — no burst replay.
    if (widget.ignited) _burst.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant SynthesizeChatCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ignited && !oldWidget.ignited) {
      HapticFeedback.mediumImpact();
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.generating) return;
    if (!widget.ignited) {
      // Dormant: gentle haptic progress hint — flips are still pending.
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  String get _label {
    if (widget.generating) return 'WEAVING THE READING · · ·';
    if (!widget.ignited) {
      if (widget.faceUp <= 0) return '✦ SYNTHESIZE IN CHAT (FLIP ALL CARDS)';
      return '✦ SYNTHESIZE IN CHAT '
          '(${widget.faceUp} OF ${widget.total} FACE-UP)';
    }
    return widget.synthesized
        ? '✦ OPEN ORACLE CHAT →'
        : '✦ SYNTHESIZE IN CHAT →';
  }


  @override
  Widget build(BuildContext context) {
    final ignited = widget.ignited && !widget.generating;
    return Opacity(
      opacity: ignited ? 1.0 : 0.42,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _burst]),
          builder: (context, _) {
            return Transform.scale(
              scale: ignited ? _burstScale.evaluate(_burst) : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (ignited)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StarlightBorderPainter(animation: _loop),
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      gradient: ignited
                          ? LinearGradient(
                              colors: [
                                AppColors.lavender.withValues(alpha: 0.24),
                                AppColors.indigo.withValues(alpha: 0.14),
                              ],
                            )
                          : null,
                      color: ignited
                          ? null
                          : AppColors.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ignited ? AppColors.lavender : AppColors.border,
                        width: ignited ? 1.2 : 1.0,
                      ),
                      boxShadow: ignited
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.lavender.withValues(alpha: 0.3),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                        color: ignited
                            ? AppColors.lavender
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  // Bright ignition flash — fades right after the burst.
                  if (ignited && _burst.value < 1.0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white
                                .withValues(alpha: 0.35 * (1.0 - _burst.value)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


/// Continuous shimmering starlight border: a pulsing lavender/cyan aura
/// plus 6 orbiting sparkles walking the rounded-rect perimeter. Driven by
/// the host's repeating [animation] via `super(repaint:)` — repaints on
/// every tick at frame rate.
class _StarlightBorderPainter extends CustomPainter {
  _StarlightBorderPainter({required this.animation})
      : super(repaint: animation);

  final Animation<double> animation;

  /// Perimeter point at normalized arc length [s] (0..1) of [rect].
  static Offset _perimeterPoint(Rect rect, double s) {
    final w = rect.width;
    final h = rect.height;
    final total = 2 * (w + h);
    var d = s * total;
    if (d < w) return Offset(rect.left + d, rect.top);
    d -= w;
    if (d < h) return Offset(rect.right, rect.top + d);
    d -= h;
    if (d < w) return Offset(rect.right - d, rect.bottom);
    d -= w;
    return Offset(rect.left, rect.bottom - d);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );

    // Pulsing aura: lavender breathing in, cyan breathing out of phase.
    final lavenderGlow = 0.10 + 0.06 * math.sin(t * 2 * math.pi);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.lavender.withValues(alpha: lavenderGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final cyanGlow = 0.10 + 0.06 * math.cos(t * 2 * math.pi + 1.2);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.harmonyCyan.withValues(alpha: cyanGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Six orbiting sparkles gliding along the border.
    const sparkles = 6;
    for (var i = 0; i < sparkles; i++) {
      final s = (t * 0.35 + i / sparkles) % 1.0;
      final point = _perimeterPoint(Offset.zero & size, s);
      final twinkle = 0.55 + 0.45 * math.sin(t * 6 * math.pi + i * 2.1);
      canvas.drawCircle(
        point,
        2.0 + math.sin(t * 6 * math.pi + i),
        Paint()
          ..color = (i.isEven ? AppColors.lavender : AppColors.harmonyCyan)
              .withValues(alpha: twinkle)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarlightBorderPainter oldDelegate) => false;
}
