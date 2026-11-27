import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/guide_copy.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/guide_event.dart';
import '../../../core/models/guide_hint.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import 'wisp_mascot.dart';
import 'wisp_mood.dart';

/// G2.3 — Wisp's floating obsidian-lavender glass speech bubble.
///
/// Wisp sits gently on the left facing into a unified frosted speech bubble
/// speaking in his own first-person voice. Readers can tap the bubble (or
/// "More") to open Wisp's detail sheet, or tuck Wisp into a compact corner
/// pill so the bubble never gets in the way of cards or gestures.
class GuideBubble extends StatefulWidget {
  const GuideBubble({
    super.key,
    required this.hint,
    required this.mood,
    required this.lang,
    required this.onOpenDetail,
    this.onBackToSpread,
  });

  final GuideHint hint;
  final WispMood mood;
  final AppLanguage lang;
  final VoidCallback onOpenDetail;
  final VoidCallback? onBackToSpread;

  @override
  State<GuideBubble> createState() => _GuideBubbleState();
}

class _GuideBubbleState extends State<GuideBubble> {
  bool _collapsed = false;
  late GuideEventType _lastEventType = widget.hint.eventType;

  @override
  void didUpdateWidget(GuideBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Gently pop Wisp's speech bubble back open only when the reading reaches
    // a new major stage (e.g. choosing -> dealing -> revealing -> complete, or
    // when the reader explicitly taps a card link). Never nag card-by-card if
    // the reader chose to tuck Wisp away.
    if (widget.hint.eventType != _lastEventType) {
      _lastEventType = widget.hint.eventType;
      if (_collapsed) _collapsed = false;
    }
  }

  void _toggleCollapsed() {
    HapticFeedback.selectionClick();
    setState(() => _collapsed = !_collapsed);
  }

  Color get _accentColor => widget.mood == WispMood.empathetic
      ? TaroColors.dawn
      : TaroColors.lavender;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final compactHeight = MediaQuery.sizeOf(context).height < 480;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        compactHeight ? 2 : 4,
        12,
        compactHeight ? 2 : 6,
      ),
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
        child: _collapsed
            ? _CollapsedWispPill(
                key: const ValueKey('guide-bubble-collapsed'),
                mood: widget.mood,
                lang: widget.lang,
                accent: _accentColor,
                hasFreshLesson: widget.hint.lesson != null,
                onExpand: _toggleCollapsed,
              )
            : _ExpandedWispBubble(
                key: const ValueKey('guide-bubble-expanded'),
                hint: widget.hint,
                mood: widget.mood,
                lang: widget.lang,
                accent: _accentColor,
                compact: compactHeight,
                reduceMotion: reduce,
                onOpenDetail: widget.onOpenDetail,
                onCollapse: _toggleCollapsed,
                onBackToSpread: widget.onBackToSpread,
              ),
      ),
    );
  }
}

class _ExpandedWispBubble extends StatelessWidget {
  const _ExpandedWispBubble({
    super.key,
    required this.hint,
    required this.mood,
    required this.lang,
    required this.accent,
    required this.compact,
    required this.reduceMotion,
    required this.onOpenDetail,
    required this.onCollapse,
    this.onBackToSpread,
  });

  final GuideHint hint;
  final WispMood mood;
  final AppLanguage lang;
  final Color accent;
  final bool compact;
  final bool reduceMotion;
  final VoidCallback onOpenDetail;
  final VoidCallback onCollapse;
  final VoidCallback? onBackToSpread;

  static const _tailWidth = 9.0;

  @override
  Widget build(BuildContext context) {
    final mascotSize = compact ? 44.0 : 60.0;
    final isLink = hint.eventType == GuideEventType.relationshipTapped;
    final hasLesson = hint.lesson != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        WispMascot(
          size: mascotSize,
          mood: mood,
          glowColor: accent,
          gazeTarget: const Offset(0.32, -0.12),
          onTap: onOpenDetail,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Semantics(
            button: true,
            label: '${GuideCopy.mascotName(lang)}: ${hint.title}',
            child: GestureDetector(
              key: const ValueKey('reading-guide'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenDetail,
              child: CustomPaint(
                painter: _SpeechBubbleShapePainter(
                  tailWidth: _tailWidth,
                  radius: 18,
                  fillTop: Color.alphaBlend(
                    accent.withValues(alpha: 0.14),
                    const Color(0xDF131524),
                  ),
                  fillBottom: Color.alphaBlend(
                    accent.withValues(alpha: 0.06),
                    const Color(0xE80E101B),
                  ),
                  borderColor: accent.withValues(alpha: 0.38),
                  glowColor: accent.withValues(alpha: 0.18),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _tailWidth + 12,
                    compact ? 7 : 9,
                    10,
                    compact ? 7 : 9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.75),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            GuideCopy.mascotName(lang),
                            style: AppTypography.label(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: accent,
                            ),
                          ),
                          if (hasLesson) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 11,
                              color: accent.withValues(alpha: 0.85),
                            ),
                          ],
                          const Spacer(),
                          if (isLink && onBackToSpread != null) ...[
                            GestureDetector(
                              key: const ValueKey('guide-bubble-back'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onBackToSpread,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  '← ${GuideCopy.backToSpread(lang)}',
                                  style: AppTypography.label(
                                    fontSize: 8.5,
                                    letterSpacing: 0.4,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                          ],
                          GestureDetector(
                            key: const ValueKey('guide-bubble-collapse'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onCollapse,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: TaroColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        ),
                        child: Column(
                          key: ValueKey('${hint.id}:${hint.title}'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hint.title,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                color: TaroColors.textPrimary,
                                height: 1.28,
                              ),
                            ),
                            if (!compact && hint.body.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                hint.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                  fontSize: 11.5,
                                  color: TaroColors.textSecondary,
                                  height: 1.36,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              GuideCopy.moreAction(lang),
                              style: AppTypography.label(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.9,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 13,
                              color: accent,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsedWispPill extends StatelessWidget {
  const _CollapsedWispPill({
    super.key,
    required this.mood,
    required this.lang,
    required this.accent,
    required this.hasFreshLesson,
    required this.onExpand,
  });

  final WispMood mood;
  final AppLanguage lang;
  final Color accent;
  final bool hasFreshLesson;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: GuideCopy.mascotName(lang),
        child: GestureDetector(
          key: const ValueKey('guide-bubble-expand'),
          behavior: HitTestBehavior.opaque,
          onTap: onExpand,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.14),
                    const Color(0xDF131524),
                  ),
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.06),
                    const Color(0xE80E101B),
                  ),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.38)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WispMascot(
                  size: 38,
                  mood: mood,
                  glowColor: accent,
                  gazeTarget: const Offset(0.25, -0.1),
                ),
                const SizedBox(width: 6),
                Text(
                  GuideCopy.mascotName(lang),
                  style: AppTypography.label(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: accent,
                  ),
                ),
                if (hasFreshLesson) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints ONE seamless obsidian-lavender glass speech bubble with an integrated
/// left-pointing tail toward Wisp — zero double-border corners, zero seam line,
/// and zero extra BackdropFilter GPU readbacks.
class _SpeechBubbleShapePainter extends CustomPainter {
  const _SpeechBubbleShapePainter({
    required this.tailWidth,
    required this.radius,
    required this.fillTop,
    required this.fillBottom,
    required this.borderColor,
    required this.glowColor,
  });

  final double tailWidth;
  final double radius;
  final Color fillTop;
  final Color fillBottom;
  final Color borderColor;
  final Color glowColor;

  Path _buildPath(Size size) {
    final left = tailWidth;
    final right = size.width;
    final top = 0.0;
    final bottom = size.height;
    final r = radius.clamp(0.0, (bottom - top) / 2);
    final midY = (top + bottom) * 0.5;
    final tailHalf = 8.0.clamp(0.0, (bottom - top) / 2 - r).toDouble();

    final path = Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..arcToPoint(Offset(right, top + r), radius: Radius.circular(r))
      ..lineTo(right, bottom - r)
      ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
      ..lineTo(left + r, bottom)
      ..arcToPoint(Offset(left, bottom - r), radius: Radius.circular(r));

    if (tailHalf >= 3.0) {
      path
        ..lineTo(left, midY + tailHalf)
        ..quadraticBezierTo(left * 0.35, midY + tailHalf * 0.25, 0, midY)
        ..quadraticBezierTo(left * 0.35, midY - tailHalf * 0.25, left, midY - tailHalf);
    }

    path
      ..lineTo(left, top + r)
      ..arcToPoint(Offset(left + r, top), radius: Radius.circular(r))
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Ambient lavender glow behind the bubble.
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Frosted obsidian-lavender gradient body.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ).createShader(Offset.zero & size),
    );

    // Subtle top rim sheen inside the bubble.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            borderColor.withValues(alpha: 0.55),
            borderColor.withValues(alpha: 0.22),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SpeechBubbleShapePainter old) =>
      old.tailWidth != tailWidth ||
      old.radius != radius ||
      old.fillTop != fillTop ||
      old.fillBottom != fillBottom ||
      old.borderColor != borderColor ||
      old.glowColor != glowColor;
}
