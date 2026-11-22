import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/theme/app_typography.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/main.dart';

void main() {
  group('buildTaroTheme', () {
    test('configures Tarot Tree palette, typography and optics extension', () {
      final theme = buildTaroTheme();

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, TaroColors.background);

      expect(theme.colorScheme.primary, TaroColors.lavender);
      expect(theme.colorScheme.secondary, TaroColors.indigo);
      expect(theme.colorScheme.tertiary, TaroColors.dawn);
      expect(theme.colorScheme.surface, TaroColors.surface);
      expect(theme.colorScheme.error, TaroColors.error);
      expect(theme.colorScheme.onPrimary, TaroColors.background);
      expect(theme.colorScheme.onSurface, TaroColors.textPrimary);
      expect(theme.colorScheme.onSurfaceVariant, TaroColors.textSecondary);

      expect(theme.textTheme.displayLarge?.color, TaroColors.textPrimary);
      expect(theme.textTheme.displayLarge?.fontFamily, AppTypography.familyVariable);
      expect(theme.textTheme.bodyMedium?.color, TaroColors.textPrimary);
      expect(theme.textTheme.bodySmall?.color, TaroColors.textSecondary);
      expect(theme.textTheme.labelMedium?.color, TaroColors.textSecondary);

      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.bottomSheetTheme.backgroundColor, Colors.transparent);

      final optics = theme.extension<TaroOpticsTheme>();
      expect(optics, isNotNull);
      expect(optics!.refractionHeight, TaroOptics.refractionHeight);
      expect(optics.refractionAmount, TaroOptics.refractionAmount);
      expect(optics.frost, TaroOptics.frost);
      expect(optics.highlight, TaroOptics.highlight);
      expect(optics.contourStrength, TaroOptics.contourStrength);
      expect(optics.tintAmount, TaroOptics.tintAmount);
    });

    test('TaroOpticsTheme supports copyWith and lerp', () {
      const a = TaroOpticsTheme();
      final b = a.copyWith(frost: 24.0, highlight: 0.9);
      expect(b.frost, 24.0);
      expect(b.highlight, 0.9);
      expect(b.refractionAmount, a.refractionAmount);

      final mid = a.lerp(b, 0.5);
      expect(mid.frost, closeTo(18.0, 0.001));
      expect(mid.highlight, closeTo(0.7, 0.001));
      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('MindreaderApp Tarot Tree theme wiring', () {
    testWidgets('boots with a dusk backdrop and visible tab and dock glass', (
      tester,
    ) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.scaffoldBackgroundColor, TaroColors.background);
      expect(materialApp.theme?.extension<TaroOpticsTheme>(), isNotNull);

      expect(find.byType(TaroDuskBackground), findsOneWidget);
      // Visible local glass layers on Step 1: system selector, custom spread
      // action, and bottom navigation dock (all sharing one BackdropGroup).
      expect(find.byType(TaroGlassLayer), findsNWidgets(3));
      expect(find.byType(TaroGlassDock), findsOneWidget);
    });

    testWidgets('TaroDuskBackground ignores pointer events', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                  child: const SizedBox.expand(),
                ),
              ),
              const Positioned.fill(child: TaroDuskBackground()),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 100));
      expect(tapped, isTrue);
    });
  });
}
