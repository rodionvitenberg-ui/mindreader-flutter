import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/taro_tokens.dart';
import 'wisp_face_painter.dart';
import 'wisp_mood.dart';

/// Wisp — the Tarot Tree companion (G2.2/G2.3).
///
/// The cleaned, mirrored transparent sprite (`assets/images/wisp_body.png`)
/// supplies the luminous orb and swirling cosmic veil; the face is painted
/// procedurally dead-center on the orb so mimicry stays crisp at any size.
/// Wisp floats on an isolated [RepaintBoundary], blinks on its own schedule,
/// follows [gazeTarget], honours reduce-motion (scheduling zero frames), and
/// fires one medium haptic when transitioning into celebration.
class WispMascot extends StatefulWidget {
  const WispMascot({
    super.key,
    this.size = 96,
    this.mood = WispMood.greeting,
    this.gazeTarget = Offset.zero,
    this.glowColor = TaroColors.lavender,
    this.flipX = false,
    this.onTap,
  });

  final double size;
  final WispMood mood;

  /// Normalised look direction, each axis in -1..1.
  final Offset gazeTarget;
  final Color glowColor;

  /// Mirrors the sprite horizontally when Wisp sits on the right side facing
  /// left. Defaults to `false` (orb leans right toward a speech bubble).
  final bool flipX;
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
    // Celebration is the one physical moment worth a haptic; onboarding and
    // Step 1 set the mood once, so they never vibrate on mount.
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

    final orbCenterX = widget.flipX
        ? 1.0 - WispFacePainter.defaultOrbCenterX
        : WispFacePainter.defaultOrbCenterX;
    final orbAlignX = orbCenterX * 2.0 - 1.0;
    final orbAlignY = WispFacePainter.defaultOrbCenterY * 2.0 - 1.0;

    final sprite = Image.asset(
      'assets/images/wisp_body.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
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
                  offset: Offset(0, (t - .5) * (widget.size * .07)),
                  child: Transform.rotate(
                    angle: reduce ? 0 : (t - .5) * .055,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft radial aura centered behind Wisp's orb — zero
                        // rectangular edge, zero color-filter box artifact.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(orbAlignX, orbAlignY),
                                radius: 0.48,
                                colors: [
                                  widget.glowColor.withValues(alpha: .28),
                                  widget.glowColor.withValues(alpha: .08),
                                  widget.glowColor.withValues(alpha: 0),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Pure transparent RGBA sprite — never use a
                        // BlendMode.screen ColorFilter (that fills alpha=0
                        // corners with a visible square box).
                        if (widget.flipX)
                          Transform.flip(flipX: true, child: sprite)
                        else
                          sprite,
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
                              orbCenterX: orbCenterX,
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
