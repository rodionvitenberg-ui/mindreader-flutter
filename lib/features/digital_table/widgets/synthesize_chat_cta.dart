import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// The `✦ SYNTHESIZE IN CHAT →` call to action — PERMANENTLY anchored at
/// the bottom of the Digital Table (Pane 0), right above the bottom
/// navigation dock.
///
/// Two states:
/// * **Dormant**: disabled, gray, and static while any cards remain
///   to be drawn or revealed. The label shows reveal progress.
/// * **Ignited** (all cards face-up): an ignition burst plays once
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

  /// True once the entire spread is dealt and revealed.
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
  );

  /// One-shot ignition burst (scale 0.95 → 1.04 → 1.0 + bright flash).
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  late final TweenSequence<double> _burstScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.95,
        end: 1.04,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.04,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 50,
    ),
  ]);

  bool get _enabled => widget.ignited && !widget.generating;

  @override
  void initState() {
    super.initState();
    // A restored/readied session mounts already ignited — no burst replay.
    if (_enabled) {
      _burst.value = 1.0;
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SynthesizeChatCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEnabled = oldWidget.ignited && !oldWidget.generating;
    if (_enabled == wasEnabled) return;
    if (_enabled) {
      _loop.repeat();
      if (!oldWidget.ignited) {
        HapticFeedback.mediumImpact();
        _burst.forward(from: 0);
      } else {
        _burst.value = 1.0;
      }
    } else {
      _loop.stop();
      _burst.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  /// Reference label whose single-line box defines the fixed size shared by
  /// all CTA states (dormant, ignited, generating, and OPEN ORACLE CHAT).
  static const _sizeReferenceLabel = '✦ SYNTHESIZE IN CHAT →';

  String get _label {
    if (widget.generating) return 'WEAVING THE READING · · ·';
    if (widget.synthesized) return '✦ OPEN ORACLE CHAT →';
    if (!widget.ignited) {
      if (widget.faceUp <= 0) return '✦ SYNTHESIZE IN CHAT';
      return '✦ SYNTHESIZE IN CHAT (${widget.faceUp}/${widget.total})';
    }
    return '✦ SYNTHESIZE IN CHAT →';
  }

  @override
  Widget build(BuildContext context) {
    final ignited = _enabled;
    final labelStyle = AppTypography.label(
      fontSize: 10,
      letterSpacing: 1.0,
      fontWeight: FontWeight.w700,
      color: ignited ? AppColors.lavender : Colors.grey.shade500,
    );
    final refPainter = TextPainter(
      text: TextSpan(text: _sizeReferenceLabel, style: labelStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final refSize = refPainter.size;
    return Semantics(
      button: true,
      enabled: ignited,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ignited ? _handleTap : null,
        child: AnimatedBuilder(
          animation: _burst,
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
                      color: ignited ? null : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ignited
                            ? AppColors.lavender
                            : Colors.grey.shade800,
                        width: 1.2,
                      ),
                      boxShadow: ignited
                          ? [
                              BoxShadow(
                                color: AppColors.lavender.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: SizedBox(
                      width: refSize.width,
                      height: refSize.height,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _label,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ),
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
                            color: Colors.white.withValues(
                              alpha: 0.35 * (1.0 - _burst.value),
                            ),
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
