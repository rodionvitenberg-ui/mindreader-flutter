import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../core/theme/app_typography.dart';
import '../taro.dart';
import 'glass_playground.dart';

/// Отдельная точка входа для изолированного playground:
/// `flutter run -t lib/design_system/playground/playground_main.dart
///   --enable-impeller --enable-flutter-gpu`
///
/// Основной `lib/main.dart` НЕ затрагивается до визуального согласования.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Грузим шейдеры заранее, чтобы первый кадр стекла был настоящим.
  await LiquidGlass.precache();
  runApp(const _PlaygroundApp());
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
