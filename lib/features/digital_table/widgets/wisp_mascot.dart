import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/taro_tokens.dart';
import 'wisp_face_painter.dart';
import 'wisp_mood.dart';

/// The Tarot Tree companion — the real look (G2.2).
///
/// The authored sprite supplies the body and veil; the face is painted
/// procedurally on top, so mimicry stays crisp at any size with no extra
/// assets. It floats on an isolated [RepaintBoundary], blinks on its own
/// schedule, follows [gazeTarget], honours reduce-motion (and then schedules
/// no frames at all) and fires one medium haptic when it starts celebrating.
class WispMascot extends StatefulWidget {
  const WispMascot({
    super.key,
    this.size = 96,
    this.mood = WispMood.greeting,
    this.gazeTarget = Offset.zero,
    this.glowColor = TaroColors.lavender,
    this.onTap,
  });

  final double size;
  final WispMood mood;

  /// Normalised look direction, each axis in -1..1.
  final Offset gazeTarget;
  final Color glowColor;
  final VoidCallback? onTap;

  @override
  State<WispMascot> createState() => _WispMascotState();
}

class _WispMascotState extends State<WispMascot> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  final _random = math.Random();
  Timer? _blinkTimer;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced && (reduced || _float.isAnimating)) return;
    _reduced = reduced;
    if (reduced) {
      _blinkTimer?.cancel();
      _float.stop();
      _float.value = .5;
      _blink.value = 0;
    } else {
      _float.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    if (_reduced) return;
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 2600 + _random.nextInt(2400)),
      () async {
        if (!mounted || _reduced) return;
        if (widget.mood != WispMood.sleeping) {
          try {
            await _blink.forward().orCancel;
            if (mounted) await _blink.reverse().orCancel;
          } catch (_) {
            // The ticker was cancelled by dispose() mid-blink.
            return;
          }
        }
        if (mounted) _scheduleBlink();
      },
    );
  }

  @override
  void didUpdateWidget(WispMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood) return;
    // Celebration is the one physical moment worth a haptic; onboarding sets
    // the mood once, so it never vibrates on its own.
    if (widget.mood == WispMood.greeting) HapticFeedback.mediumImpact();
    if (!_reduced && widget.mood != WispMood.sleeping) _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _float.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduced;
    final gaze = Offset(
      widget.gazeTarget.dx.clamp(-1.0, 1.0),
      widget.gazeTarget.dy.clamp(-1.0, 1.0),
    );
    final cacheWidth = math.max(
      256,
      (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
    );

    return ExcludeSemantics(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.translucent,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_float, _blink]),
              builder: (context, _) {
                final t = Curves.easeInOutSine.transform(_float.value);
                return Transform.translate(
                  offset: Offset(0, (t - .5) * (widget.size * .08)),
                  child: Transform.rotate(
                    angle: reduce ? 0 : (t - .5) * .07,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The only light the companion emits, tinted per moment.
                        Container(
                          width: widget.size * .72,
                          height: widget.size * .72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.glowColor.withValues(alpha: .28),
                                blurRadius: widget.size * .28,
                                spreadRadius: widget.size * .02,
                              ),
                            ],
                          ),
                        ),
                        // The authored sprite: transparent PNG, tinted with a
                        // screen blend so a dark backing cannot show through.
                        Image.asset(
                          'assets/images/wisp_body.png',
                          width: widget.size,
                          height: widget.size,
                          fit: BoxFit.contain,
                          cacheWidth: cacheWidth,
                          color: widget.glowColor.withValues(alpha: .15),
                          colorBlendMode: BlendMode.screen,
                        ),
                        TweenAnimationBuilder<Offset>(
                          tween: Tween<Offset>(
                            begin: Offset.zero,
                            end: gaze,
                          ),
                          duration: reduce
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, smoothGaze, _) => CustomPaint(
                            size: Size.square(widget.size),
                            painter: WispFacePainter(
                              mood: widget.mood,
                              blinkProgress: _blink.value,
                              gaze: smoothGaze,
                              pulse: t,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
