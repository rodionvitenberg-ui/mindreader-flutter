import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Чистое решение по результатам проб — без платформенных вызовов, тестируется.
  static TaroGlassMode decide({
    required bool shaderFiltersSupported,
    required bool isAndroid,
    required bool isApple,
    required bool androidVulkanSupported,
  }) {
    if (!shaderFiltersSupported) return TaroGlassMode.fake;
    if (isApple) return TaroGlassMode.glass; // Metal + Flutter GPU
    if (isAndroid) {
      return androidVulkanSupported ? TaroGlassMode.glass : TaroGlassMode.fake;
    }
    return TaroGlassMode.fake;
  }

  /// Один раз пробит возможности и запишет результат в [mode].
  static Future<void> ensureResolved() async {
    if (_resolved) return;
    _resolved = true;
    final shaderOk = ui.ImageFilter.isShaderFilterSupported;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    var vulkan = false;
    if (isAndroid && shaderOk) {
      try {
        vulkan = await _channel.invokeMethod<bool>('hasVulkan') ?? false;
      } on Object {
        vulkan = false;
      }
    }
    mode.value = decide(
      shaderFiltersSupported: shaderOk,
      isAndroid: isAndroid,
      isApple: isApple,
      androidVulkanSupported: vulkan,
    );
  }
}
