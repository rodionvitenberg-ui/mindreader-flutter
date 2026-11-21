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
    this.fillColor,
    this.borderColor,
    this.glow,
    this.radius = TaroRadii.panel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? fillColor;
  final Color? borderColor;
  final List<BoxShadow>? glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // TaroGlassSurface лежит фоновым sibling-слоем в Stack, чтобы вложенные
    // TaroGlassButton/TaroGlassToggle/TaroGlassInput внутри панели не
    // создавали вложенный LiquidGlass поверх LiquidGlass.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: TaroGlassSurface(
              radius: radius,
              tint: tint,
              fillColor: fillColor ?? TaroColors.surface,
              borderColor: borderColor,
              glow: glow ??
                  TaroGlow.soft(
                    TaroColors.lavender,
                    blur: 28,
                    offset: const Offset(0, 10),
                  ),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
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
