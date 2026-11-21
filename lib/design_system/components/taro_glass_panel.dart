import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Панель с мягкой глубиной: скругление, свечение, hairline-бордер.
class TaroGlassPanel extends StatelessWidget {
  const TaroGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint,
    this.radius = TaroRadii.panel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSurface(
      radius: radius,
      tint: tint,
      fillColor: TaroColors.surface,
      glow: TaroGlow.soft(
        TaroColors.lavender,
        blur: 28,
        offset: const Offset(0, 10),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Заголовок секции внутри панели (mono eyebrow + крупный заголовок).
class TaroGlassSectionLabel extends StatelessWidget {
  const TaroGlassSectionLabel({
    required this.eyebrow,
    required this.title,
    super.key,
  });

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: AppTypography.label(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: TaroColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTypography.heading(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TaroColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
