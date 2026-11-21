import 'package:flutter/material.dart';

import '../taro_tokens.dart';

/// Общий фон «мягкие сумерки» (Tarot Tree): вертикальный градиент сумерек
/// с тёплым рассветным свечением (лавандовый, пыльно-розовый, рассвет).
///
/// Обычный [Container] + [Stack] с радиальными градиентами без эффектов стекла
/// (фон не сэмплится бэкдропом). Обёрнут в [RepaintBoundary] и [IgnorePointer]
/// для кеширования GPU-текстуры и нулевого перехвата касаний.
class TaroDuskBackground extends StatelessWidget {
  const TaroDuskBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TaroColors.background,
                TaroColors.duskMid,
                TaroColors.duskHorizon,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: _glow(TaroColors.lavender, TaroOpacity.glow, 240),
              ),
              Positioned(
                top: 120,
                left: -100,
                child: _glow(TaroColors.rose, 0.22, 220),
              ),
              Positioned(
                bottom: -140,
                left: 40,
                child: _glow(TaroColors.dawn, 0.18, 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(Color color, double alpha, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
