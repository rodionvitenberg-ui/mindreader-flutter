import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../core/theme/app_typography.dart';
import '../taro.dart';
import 'glass_playground.dart';

/// Отдельная точка входа для изолированного playground:
/// `flutter run -t lib/design_system/playground/playground_main.dart`
///
/// Основной `lib/main.dart` НЕ затрагивается до визуального согласования.
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
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TaroColors.background,
      fontFamily: AppTypography.familyStatic,
      colorScheme: const ColorScheme.dark(
        primary: TaroColors.lavender,
        secondary: TaroColors.indigo,
        surface: TaroColors.surface,
        onPrimary: TaroColors.background,
        onSurface: TaroColors.textPrimary,
      ),
    );
    return MaterialApp(
      title: 'Tarot Tree — Glass Playground',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: const GlassPlayground(),
    );
  }
}
