import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'taro_glass_mode.dart';

/// Определяет лучший [TaroGlassMode] для текущего устройства.
///
/// Настоящее стекло требует Impeller + Flutter GPU: на iOS/macOS это Metal
/// (работает), на Android — Vulkan. Если Shader-фильтры или Vulkan недоступны —
/// остаётся [TaroGlassMode.fake] (FakeGlass), который рисуется везде.
///
/// Значение резолвится один раз и кешируется в [mode]. Пока идёт проба —
/// держим безопасный [TaroGlassMode.fake], чтобы первый кадр не был чёрным.
abstract final class TaroGlassCapability {
  static const _channel = MethodChannel('taro/glass_capability');

  /// Кешированный режим. Стартует безопасно с [TaroGlassMode.fake].
  static final ValueNotifier<TaroGlassMode> mode =
      ValueNotifier<TaroGlassMode>(TaroGlassMode.fake);

  static bool _resolved = false;
  static Completer<void> _resolvedCompleter = Completer<void>();

  /// Завершается, когда первичная проба [ensureResolved] определила режим стекла.
  static Future<void> get whenResolved => _resolvedCompleter.future;

  /// Чистое решение по результатам проб — без платформенных вызовов, тестируется.
  static TaroGlassMode decide({
    required bool shaderFiltersSupported,
    required bool isAndroid,
    required bool isApple,
    required bool androidVulkanSupported,
    bool? selfTestGlassWorks,
  }) {
    if (!shaderFiltersSupported) return TaroGlassMode.fake;
    // Render-самопроверка решает окончательно: ловит устройства, которые
    // рапортуют GPU, но реально рисуют чёрное (часть MediaTek + Impeller GLES).
    if (selfTestGlassWorks == false) return TaroGlassMode.fake;
    if (selfTestGlassWorks == true) return TaroGlassMode.glass;
    if (isApple) return TaroGlassMode.glass; // Metal + Flutter GPU
    if (isAndroid) {
      return androidVulkanSupported ? TaroGlassMode.glass : TaroGlassMode.fake;
    }
    return TaroGlassMode.fake;
  }

  /// Один раз пробит возможности и запишет результат в [mode].
  ///
  /// Если передан [overlay] — дополнительно выполняется render-самопроверка
  /// (см. [_selfTestGlass]): она ловит устройства, которые рапортуют GPU, но
  /// реально рисуют чёрный кадр.
  static Future<void> ensureResolved({OverlayState? overlay}) async {
    if (_resolved) return _resolvedCompleter.future;
    _resolved = true;
    try {
      final shaderOk = ui.ImageFilter.isShaderFilterSupported;
      final isAndroid = !kIsWeb && Platform.isAndroid;
      final isApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

      if (!shaderOk) {
        mode.value = TaroGlassMode.fake;
        return;
      }

      var vulkan = false;
      if (isAndroid) {
        try {
          vulkan = await _channel.invokeMethod<bool>('hasVulkan') ?? false;
        } on Object {
          vulkan = false;
        }
      }

      bool? selfTest;
      final canRunSelfTest =
          overlay != null &&
          WidgetsBinding.instance is WidgetsFlutterBinding &&
          (isAndroid || isApple);
      if (canRunSelfTest) {
        selfTest = await _selfTestGlass(overlay);
      }

      mode.value = decide(
        shaderFiltersSupported: shaderOk,
        isAndroid: isAndroid,
        isApple: isApple,
        androidVulkanSupported: vulkan,
        selfTestGlassWorks: selfTest,
      );
    } finally {
      if (!_resolvedCompleter.isCompleted) {
        _resolvedCompleter.complete();
      }
    }
  }

  /// Сбрасывает кеш пробы (только для тестов).
  @visibleForTesting
  static void resetForTest() {
    _resolved = false;
    _resolvedCompleter = Completer<void>();
    mode.value = TaroGlassMode.fake;
  }

  /// Рисует крошечное настоящее стекло над ярким фоном и проверяет пиксели.
  ///
  /// `false` — настоящий glass выдал чёрный/пустой кадр, упал в FakeGlass или
  /// проба не смогла подтвердить рабочий GPU-рендеринг (fail-safe в FakeGlass).
  /// `true` — настоящее стекло (`RenderLiquidGlassLayer`) реально отрисовалось
  /// и дало не-чёрный результат.
  static Future<bool> _selfTestGlass(OverlayState overlay) async {
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFFFFFFF)),
                    ),
                    Positioned.fill(
                      child: LiquidGlassLayer(
                        settings: LiquidGlassSettings.ios27Regular(
                          brightness: Brightness.dark,
                        ),
                        defaultAppearance: LiquidGlassAppearance.ios27Regular(
                          brightness: Brightness.dark,
                        ),
                        fake: false,
                        child: const LiquidGlass(
                          shape: LiquidRoundedSuperellipse(borderRadius: 14),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      // Первый кадр — FakeGlass; затем слой грузит GPU-геометрию асинхронно и
      // переключается на настоящее стекло. Ждём этот переход.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.attached) return false;
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
      }
      // Если LiquidGlassLayer(fake: false) не смог поднять Flutter GPU и тихо
      // откатился в FakeGlass — фиксируем fake, чтобы экраны не пытались
      // инициализировать GPU на каждом монтировании.
      if (_containsFakeGlassLayer(boundary)) return false;

      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return false;
      final bytes = data.buffer.asUint8List();
      var sum = 0;
      var count = 0;
      for (var i = 0; i + 3 < bytes.length; i += 32) {
        sum += (bytes[i] + bytes[i + 1] + bytes[i + 2]) ~/ 3;
        count++;
      }
      if (count == 0) return false;
      final avg = sum / count;
      // Near-black (<= 16) => сломанный real glass на Impeller GLES;
      // чистый белый (>= 252) => стекло вообще не отрисовалось поверх фона.
      return avg > 16 && avg < 252;
    } on Object {
      // Fail-safe: при ошибке пробы остаёмся в безопасном FakeGlass.
      return false;
    } finally {
      entry.remove();
    }
  }

  static bool _containsFakeGlassLayer(RenderObject root) {
    var found = false;
    void visit(RenderObject node) {
      if (found) return;
      if (node.runtimeType.toString().contains('FakeGlass')) {
        found = true;
        return;
      }
      node.visitChildren(visit);
    }

    visit(root);
    return found;
  }
}
