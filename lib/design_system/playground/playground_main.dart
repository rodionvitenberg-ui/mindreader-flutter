import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../taro.dart';
import 'glass_playground.dart';

/// Отдельная точка входа для изолированного playground:
/// `flutter run -t lib/design_system/playground/playground_main.dart`
///
/// Использует общую тему [buildTaroTheme] дизайн-системы Tarot Tree.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PlaygroundApp());
  // Прогрев шейдеров в фоне, НЕ блокируя первый кадр. На устройствах без
  // Flutter GPU (Impeller OpenGLES) `precache()` может зависнуть, и тогда
  // `runApp` не выполнится вовсе (чёрный экран). Стекло само падает в FakeGlass.
  unawaited(LiquidGlass.precache());
}

class _PlaygroundApp extends StatelessWidget {
  const _PlaygroundApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarot Tree — Glass Playground',
      debugShowCheckedModeBanner: false,
      theme: buildTaroTheme(),
      home: const GlassPlayground(),
    );
  }
}
