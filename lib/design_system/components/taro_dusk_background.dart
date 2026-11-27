import 'package:flutter/material.dart';

import '../taro_tokens.dart';

/// Bundled full-bleed atmospheric background artworks (WebP-optimized for fast PWA startup).
abstract final class TaroBackgroundAssets {
  /// Twilight pine forest — Digital Table & Almanac (non-Zodiac) screens.
  static const forest = 'assets/images/forest.webp';

  /// Ancient twilight oak — Astral & Daily Rituals screens.
  static const oak = 'assets/images/oak.webp';

  /// Moonlit Night pine forest (drop-in asset; falls back to [forest] + scrim).
  static const forestNight = 'assets/images/forest_night.webp';

  /// Moonlit Night ancient oak (drop-in asset; falls back to [oak] + scrim).
  static const oakNight = 'assets/images/oak_night.webp';

  /// Returns the dedicated Moonlit Night asset path for [asset], if mapped.
  static String? nightVariantFor(String asset) => switch (asset) {
    forest => forestNight,
    oak => oakNight,
    _ => null,
  };
}

/// Общий фон «мягкие сумерки» (Tarot Tree): вертикальный градиент сумерек
/// с тёплым рассветным свечением (лавандовый, пыльно-розовый, рассвет) или
/// полноэкранная иллюстрация ([imageAsset]) с мягкой сумеречной вуалью для
/// сохранения читаемости текста и стеклянных панелей.
///
/// В режиме [SanctuaryThemeMode.moonlit] переключается на ночной обсидиан
/// (`#06070B`), пытается загрузить ночную иллюстрацию (`*_night.webp`) и при её
/// отсутствии мягко откатывается к основной иллюстрации с ночной вуалью
/// `#05060A` (0.45 opacity).
///
/// Обычный [DecoratedBox] + [Stack] без эффектов стекла (фон не сэмплится
/// бэкдропом). Обёрнут в [RepaintBoundary] и [IgnorePointer] для кеширования
/// GPU-текстуры и нулевого перехвата касаний.
class TaroDuskBackground extends StatelessWidget {
  const TaroDuskBackground({super.key, this.imageAsset});

  /// Optional asset path (e.g. [TaroBackgroundAssets.forest] or
  /// [TaroBackgroundAssets.oak]). When `null`, renders the default twilight
  /// dusk gradient with radial ambient glows.
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final palette = TaroPalette.of(context);
    final asset = imageAsset;
    return IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.background,
                palette.duskMid,
                palette.duskHorizon,
              ],
            ),
          ),
          child: AnimatedSwitcher(
            duration: TaroMotion.normal,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                ?currentChild,
              ],
            ),
            child: asset != null
                ? _ArtworkBackdrop(
                    key: ValueKey<String>('${palette.mode.name}:$asset'),
                    asset: asset,
                    palette: palette,
                  )
                : _AmbientGlowBackdrop(
                    key: ValueKey<String>('${palette.mode.name}:dusk'),
                    palette: palette,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkBackdrop extends StatelessWidget {
  const _ArtworkBackdrop({
    super.key,
    required this.asset,
    required this.palette,
  });

  final String asset;
  final TaroPalette palette;

  @override
  Widget build(BuildContext context) {
    if (!palette.isMoonlit) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 0.78, 1.0],
                colors: [
                  TaroColors.background.withValues(alpha: 0.48),
                  TaroColors.background.withValues(alpha: 0.38),
                  TaroColors.background.withValues(alpha: 0.32),
                  TaroColors.background.withValues(alpha: 0.44),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final nightAsset = TaroBackgroundAssets.nightVariantFor(asset);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (nightAsset != null)
          Image.asset(
            nightAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _NocturnalFallbackImage(asset: asset),
          )
        else
          _NocturnalFallbackImage(asset: asset),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 0.78, 1.0],
              colors: [
                palette.background.withValues(alpha: 0.40),
                palette.background.withValues(alpha: 0.22),
                palette.background.withValues(alpha: 0.20),
                palette.background.withValues(alpha: 0.42),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the standard twilight artwork with the `#05060A` `0.45`-opacity
/// nocturnal scrim when a dedicated `*_night.webp` asset is not yet bundled.
class _NocturnalFallbackImage extends StatelessWidget {
  const _NocturnalFallbackImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        ColoredBox(
          key: const ValueKey('moonlit-nocturnal-scrim'),
          color: TaroColors.moonlitScrim.withValues(
            alpha: TaroOpacity.moonlitScrim,
          ),
        ),
      ],
    );
  }
}

class _AmbientGlowBackdrop extends StatelessWidget {
  const _AmbientGlowBackdrop({super.key, required this.palette});

  final TaroPalette palette;

  @override
  Widget build(BuildContext context) {
    if (palette.isMoonlit) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _glow(TaroColors.lavender, 0.14, 240),
          ),
          Positioned(
            top: 140,
            left: -110,
            child: _glow(TaroColors.indigo, 0.10, 220),
          ),
          Positioned(
            bottom: -140,
            left: 36,
            child: _glow(TaroColors.lanternAmber, 0.18, 280),
          ),
        ],
      );
    }

    return Stack(
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
