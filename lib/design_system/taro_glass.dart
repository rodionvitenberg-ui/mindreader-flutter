import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'taro_glass_capability.dart';
import 'taro_glass_mode.dart';
import 'taro_tokens.dart';

export 'taro_glass_mode.dart';

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

/// Дефолтный appearance: тёплый лавандовый tint в Twilight или глубокий
/// charcoal-obsidian tint в Moonlit Night поверх iOS 27 material.
LiquidGlassAppearance taroAppearance(
  Brightness brightness, {
  Color? tint,
  TaroPalette? palette,
}) => LiquidGlassAppearance.ios27Regular(
  brightness: brightness,
  tint: tint ?? (palette ?? TaroPalette.twilight).glassTint,
);

/// Inherited scope, который [TaroGlassLayer] даёт поддереву.
///
/// [TaroGlassSurface] читает его, чтобы понять, в каком режиме рисовать и
/// существует ли общий [LiquidGlassLayer] (общий backdrop sample).
class _TaroGlassScope extends InheritedWidget {
  const _TaroGlassScope({
    required this.mode,
    required this.brightness,
    required this.palette,
    required this.settings,
    required this.appearance,
    required super.child,
  });

  final TaroGlassMode mode;
  final Brightness brightness;
  final TaroPalette palette;
  final LiquidGlassSettings settings;
  final LiquidGlassAppearance appearance;

  static _TaroGlassScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TaroGlassScope>();

  @override
  bool updateShouldNotify(_TaroGlassScope old) =>
      mode != old.mode ||
      brightness != old.brightness ||
      palette != old.palette ||
      settings != old.settings ||
      appearance != old.appearance;
}


/// Единый слой стекла для экрана / playground.
///
/// По умолчанию [TaroGlassMode.auto]: резолвит режим по возможностям устройства
/// через [TaroGlassCapability] — [TaroGlassMode.glass] где доступно (Impeller
/// Metal/Vulkan + Flutter GPU), иначе [TaroGlassMode.fake]. В glass/fake
/// оборачивает поддерево в ОДИН [LiquidGlassLayer] — все [TaroGlassSurface]
/// внутри делят один backdrop sample. В simple/opaque стекло не создаётся.
class TaroGlassLayer extends StatelessWidget {
  const TaroGlassLayer({
    required this.child,
    this.mode = TaroGlassMode.auto,
    this.useBackdropGroup = true,
    super.key,
  });

  final Widget child;
  final TaroGlassMode mode;

  /// Разделять ли захват бэкдропа с ближайшим [BackdropGroup]. Для локальных
  /// изолированных виджетов внутри скроллящихся/перелистываемых экранов
  /// передавайте `false`, чтобы их проходы не сцеплялись с глобальным доком.
  final bool useBackdropGroup;

  @override
  Widget build(BuildContext context) {
    if (mode != TaroGlassMode.auto) return _buildResolved(context, mode);
    final inheritedMode = _TaroGlassScope.maybeOf(context)?.mode;
    if (inheritedMode == TaroGlassMode.simple ||
        inheritedMode == TaroGlassMode.opaque) {
      return _buildResolved(context, inheritedMode!);
    }
    // Резолвим возможности один раз после первого кадра (не блокируя его).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      TaroGlassCapability.ensureResolved(
        overlay: Overlay.maybeOf(context, rootOverlay: true),
      );
    });
    return ValueListenableBuilder<TaroGlassMode>(
      valueListenable: TaroGlassCapability.mode,
      builder: (context, resolved, _) => _buildResolved(context, resolved),
    );
  }

  Widget _buildResolved(BuildContext context, TaroGlassMode resolved) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final palette = TaroPalette.of(context);
    final settings = taroSettings(brightness);
    final appearance = taroAppearance(brightness, palette: palette);

    // Настоящий LiquidGlassLayer создаётся только для TaroGlassMode.glass
    // (Apple Metal / проверенный Android Vulkan). В TaroGlassMode.fake каждая
    // поверхность рендерится напрямую через standalone FakeGlass, без
    // ConsolidatedFakeGlassLayer / SeededBackdropPassLayer / BlendMode.clear,
    // чтобы на Impeller OpenGLES скролл и касания не затемняли док/кнопки и
    // не рисовали обрезанные «огрызки» стекла.
    if (resolved != TaroGlassMode.glass) {
      return _TaroGlassScope(
        mode: resolved,
        brightness: brightness,
        palette: palette,
        settings: settings,
        appearance: appearance,
        child: child,
      );
    }

    return _TaroGlassScope(
      mode: resolved,
      brightness: brightness,
      palette: palette,
      settings: settings,
      appearance: appearance,
      child: LiquidGlassLayer(
        settings: settings,
        defaultAppearance: appearance,
        fake: false,
        useBackdropGroup: useBackdropGroup,
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
    this.visibility = 1.0,
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

  /// Видимость стекла (0..1) без внешнего [Opacity] между [LiquidGlass] и
  /// [LiquidGlassLayer] (требование `liquid_glass_renderer`).
  final double visibility;

  @override
  Widget build(BuildContext context) {
    final scope = _TaroGlassScope.maybeOf(context);
    final palette = scope?.palette ?? TaroPalette.of(context);
    final brightness =
        scope?.brightness ?? MediaQuery.platformBrightnessOf(context);
    final mode = scope?.mode ?? TaroGlassMode.auto;
    final liquidShape =
        shape ?? LiquidRoundedSuperellipse(borderRadius: radius);
    final baseAppearance = tint != null
        ? taroAppearance(brightness, tint: tint, palette: palette)
        : scope?.appearance;
    final clampedVisibility = visibility.clamp(0.0, 1.0);
    final appearance = clampedVisibility < 1.0
        ? (baseAppearance ?? taroAppearance(brightness, palette: palette))
              .copyWith(visibility: clampedVisibility)
        : baseAppearance;
    final shadows = glow ?? const <BoxShadow>[];
    final effectiveFill = fillColor ?? palette.surface;
    final effectiveBorder = borderColor ?? palette.borderHairline;
    final nocturnalChild =
        palette.isMoonlit && fillColor != Colors.transparent
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: effectiveFill.withValues(alpha: palette.surfaceAlpha),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: effectiveBorder),
                ),
                child: child,
              )
            : child;

    switch (mode) {
      case TaroGlassMode.glass:
        if (scope != null) {
          return LiquidGlass(
            shape: liquidShape,
            appearance: appearance,
            shadows: shadows,
            child: nocturnalChild,
          );
        }
        // Standalone: собственный слой (без родительского LiquidGlassLayer).
        return LiquidGlass.auto(
          shape: liquidShape,
          settings: taroSettings(brightness),
          fake: false,
          appearance: appearance,
          shadows: shadows,
          child: nocturnalChild,
        );
      case TaroGlassMode.auto:
      case TaroGlassMode.fake:
        // Прямой FakeGlass (RenderFakeGlass): один чистый ClipPath +
        // BackdropFilterLayer без SeededBackdropPassLayer и без общего
        // BackdropGroup, поэтому скролл не затемняет соседние панели и не
        // оставляет артефактов под кнопками на Impeller OpenGLES.
        return FakeGlass(
          shape: liquidShape,
          settings: scope?.settings ?? taroSettings(brightness),
          appearance:
              appearance ??
              baseAppearance ??
              taroAppearance(brightness, palette: palette),
          shadows: shadows,
          useBackdropGroup: false,
          child: nocturnalChild,
        );
      case TaroGlassMode.simple:
      case TaroGlassMode.opaque:
        final isOpaque = mode == TaroGlassMode.opaque;
        final box = Container(
          decoration: BoxDecoration(
            color: isOpaque
                ? effectiveFill
                : effectiveFill.withValues(alpha: palette.surfaceAlpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: effectiveBorder),
            boxShadow: glow,
          ),
          child: child,
        );
        return clampedVisibility < 1.0
            ? Opacity(opacity: clampedVisibility, child: box)
            : box;
    }
  }
}
