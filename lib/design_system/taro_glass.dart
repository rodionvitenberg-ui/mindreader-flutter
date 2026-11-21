import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'taro_tokens.dart';

/// Режим рендеринга стекла (переключается в playground для замеров FPS/батареи).
enum TaroGlassMode {
  /// Полный liquid glass (Impeller + Flutter GPU); без GPU сам падает в FakeGlass.
  glass,

  /// Принудительно [FakeGlass] — дешевле, но всё ещё сэмплит backdrop.
  fake,

  /// Простые полупрозрачные поверхности — без glass и без backdrop filter.
  simple,

  /// Непрозрачные поверхности — ноль backdrop sampling, минимальная нагрузка.
  opaque,
}

/// Собирает [LiquidGlassSettings] из токенов Tarot Tree.
///
/// Берёт фиттинг iOS 27 regular material и перенастраивает оптику на
/// «умеренное преломление + лёгкую атмосферную глубину».
LiquidGlassSettings taroSettings(Brightness brightness) =>
    LiquidGlassSettings.ios27Regular(brightness: brightness).copyWith(
      refractionHeight: TaroOptics.refractionHeight,
      refractionAmount: TaroOptics.refractionAmount,
      frost: TaroOptics.frost,
      highlight: TaroOptics.highlight,
      contourStrength: TaroOptics.contourStrength,
      tintAmount: TaroOptics.tintAmount,
    );

/// Дефолтный appearance: тёплый лавандовый tint поверх iOS 27 material.
LiquidGlassAppearance taroAppearance(Brightness brightness, {Color? tint}) =>
    LiquidGlassAppearance.ios27Regular(
      brightness: brightness,
      tint: tint ?? TaroColors.lavender.withValues(alpha: 0.14),
    );

/// Inherited scope, который [TaroGlassLayer] даёт поддереву.
///
/// [TaroGlassSurface] читает его, чтобы понять, в каком режиме рисовать и
/// существует ли общий [LiquidGlassLayer] (общий backdrop sample).
class _TaroGlassScope extends InheritedWidget {
  const _TaroGlassScope({
    required this.mode,
    required this.brightness,
    required this.settings,
    required this.appearance,
    required super.child,
  });

  final TaroGlassMode mode;
  final Brightness brightness;
  final LiquidGlassSettings settings;
  final LiquidGlassAppearance appearance;

  static _TaroGlassScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TaroGlassScope>();

  @override
  bool updateShouldNotify(_TaroGlassScope old) =>
      mode != old.mode ||
      brightness != old.brightness ||
      settings != old.settings ||
      appearance != old.appearance;
}


/// Единый слой стекла для экрана / playground.
///
/// В режимах [TaroGlassMode.glass] / [TaroGlassMode.fake] оборачивает поддерево
/// в ОДИН [LiquidGlassLayer] — все [TaroGlassSurface] внутри делят один backdrop
/// sample (не по слою на кнопку). В [simple]/[opaque] режимах стекло не
/// создаётся вовсе, и поверхности рендерятся простыми заливками.
class TaroGlassLayer extends StatelessWidget {
  const TaroGlassLayer({
    required this.child,
    this.mode = TaroGlassMode.glass,
    super.key,
  });

  final Widget child;
  final TaroGlassMode mode;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final settings = taroSettings(brightness);
    final appearance = taroAppearance(brightness);
    final useGlass =
        mode == TaroGlassMode.glass || mode == TaroGlassMode.fake;

    if (!useGlass) {
      return _TaroGlassScope(
        mode: mode,
        brightness: brightness,
        settings: settings,
        appearance: appearance,
        child: child,
      );
    }

    return _TaroGlassScope(
      mode: mode,
      brightness: brightness,
      settings: settings,
      appearance: appearance,
      child: LiquidGlassLayer(
        settings: settings,
        defaultAppearance: appearance,
        fake: mode == TaroGlassMode.fake,
        child: child,
      ),
    );
  }
}


/// Одна стеклянная поверхность: скруглённая форма + ребёнок поверх стекла.
///
/// В режиме glass/fake рендерит [LiquidGlass] (наследует настройки родительского
/// [LiquidGlassLayer]); вне слоя — собственный слой через [LiquidGlass.auto].
/// В simple/opaque — обычный [Container] с полупрозрачной/непрозрачной заливкой.
class TaroGlassSurface extends StatelessWidget {
  const TaroGlassSurface({
    required this.radius,
    required this.child,
    this.shape,
    this.tint,
    this.fillColor,
    this.borderColor,
    this.glow,
    super.key,
  });

  /// Радиус скругления (используется и для fallback-контейнера).
  final double radius;

  final Widget child;

  /// Переопределение формы; по умолчанию [LiquidRoundedSuperellipse].
  final LiquidShape? shape;

  /// Тёплый tint стекла; null → дефолтный appearance слоя.
  final Color? tint;

  /// Базовая заливка для simple/opaque режимов.
  final Color? fillColor;

  /// Цвет hairline-бордера (simple/opaque).
  final Color? borderColor;

  /// Мягкое свечение/тень.
  final List<BoxShadow>? glow;

  @override
  Widget build(BuildContext context) {
    final scope = _TaroGlassScope.maybeOf(context);
    final brightness =
        scope?.brightness ?? MediaQuery.platformBrightnessOf(context);
    final mode = scope?.mode ?? TaroGlassMode.glass;
    final liquidShape =
        shape ?? LiquidRoundedSuperellipse(borderRadius: radius);
    final appearance = tint != null
        ? taroAppearance(brightness, tint: tint)
        : scope?.appearance;
    final shadows = glow ?? const <BoxShadow>[];

    switch (mode) {
      case TaroGlassMode.glass:
      case TaroGlassMode.fake:
        if (scope != null) {
          return LiquidGlass(
            shape: liquidShape,
            appearance: appearance,
            shadows: shadows,
            child: child,
          );
        }
        // Standalone: собственный слой (без родительского LiquidGlassLayer).
        return LiquidGlass.auto(
          shape: liquidShape,
          settings: taroSettings(brightness),
          fake: mode == TaroGlassMode.fake,
          appearance: appearance,
          shadows: shadows,
          child: child,
        );
      case TaroGlassMode.simple:
      case TaroGlassMode.opaque:
        final isOpaque = mode == TaroGlassMode.opaque;
        final fill = fillColor ?? TaroColors.surface;
        return Container(
          decoration: BoxDecoration(
            color: isOpaque
                ? fill
                : fill.withValues(alpha: TaroOpacity.surfaceStrong),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  borderColor ??
                  TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
            boxShadow: glow,
          ),
          child: child,
        );
    }
  }
}
