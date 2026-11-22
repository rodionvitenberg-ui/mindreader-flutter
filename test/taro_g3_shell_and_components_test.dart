import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/almanac/almanac_screen.dart';
import 'package:mindreader/features/astral/astral_screen.dart';
import 'package:mindreader/features/camera_scan/camera_scan_screen.dart';
import 'package:mindreader/features/digital_table/table_workspace.dart';
import 'package:mindreader/features/shell/widgets/app_settings_sheet.dart';
import 'package:mindreader/features/shell/widgets/pro_subscription_sheet.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:provider/provider.dart';

Widget _wrapSimple(Widget child) => MaterialApp(
  theme: buildTaroTheme(),
  home: Scaffold(
    body: TaroGlassLayer(
      mode: TaroGlassMode.simple,
      child: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  ),
);

void main() {
  group('G3 components: TaroGlassToggle', () {
    testWidgets('toggles value on tap and enforces >=44px touch height', (
      tester,
    ) async {
      bool? latest;
      await tester.pumpWidget(
        _wrapSimple(
          TaroGlassToggle(
            label: 'Quiet mode',
            subtitle: 'Skip movement cues',
            value: false,
            onChanged: (v) => latest = v,
          ),
        ),
      );

      final size = tester.getSize(find.byType(TaroGlassToggle));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('Quiet mode'));
      await tester.pump();
      expect(latest, isTrue);
    });

    testWidgets('disabled toggle ignores taps', (tester) async {
      await tester.pumpWidget(
        _wrapSimple(
          const TaroGlassToggle(
            label: 'Locked toggle',
            value: true,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('Locked toggle'));
      await tester.pump();
      expect(find.text('Locked toggle'), findsOneWidget);
    });
  });

  group('G3 components: TaroGlassSlider', () {
    testWidgets('tap updates value, snaps to divisions and has >=44px touch zone', (
      tester,
    ) async {
      var current = 0.0;
      double? ended;
      await tester.pumpWidget(
        _wrapSimple(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 240,
              child: TaroGlassSlider(
                label: 'Cadence',
                value: current,
                divisions: 4,
                onChanged: (v) => setState(() => current = v),
                onChangeEnd: (v) => ended = v,
              ),
            ),
          ),
        ),
      );

      final gestureFinder = find.descendant(
        of: find.byType(TaroGlassSlider),
        matching: find.byType(GestureDetector),
      );
      final rect = tester.getRect(gestureFinder);
      expect(rect.height, greaterThanOrEqualTo(44));

      // Tap near 75% width → snaps to 0.75 with 4 divisions.
      await tester.tapAt(Offset(rect.left + rect.width * 0.76, rect.center.dy));
      await tester.pump();
      expect(current, closeTo(0.75, 0.001));
      expect(ended, closeTo(0.75, 0.001));
    });

    testWidgets('disabled slider ignores interaction', (tester) async {
      await tester.pumpWidget(
        _wrapSimple(
          const SizedBox(
            width: 200,
            child: TaroGlassSlider(value: 0.5, onChanged: null),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TaroGlassSlider));
      await tester.tapAt(rect.centerRight);
      await tester.pump();
      expect(find.byType(TaroGlassSlider), findsOneWidget);
    });
  });

  group('G3 components: TaroGlassIconButton', () {
    testWidgets('fires onPressed and enforces >=44x44 touch target', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrapSimple(
          TaroGlassIconButton(
            icon: Icons.mic_none,
            tooltip: 'Voice input',
            size: 32, // below 44 — must clamp up to 44
            active: true,
            onPressed: () => taps++,
          ),
        ),
      );

      final size = tester.getSize(find.byType(TaroGlassIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.byTooltip('Voice input'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled icon button does not fire', (tester) async {
      await tester.pumpWidget(
        _wrapSimple(
          const TaroGlassIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Send',
            onPressed: null,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });

  group('G3 components: TaroGlassSheet', () {
    testWidgets('showTaroGlassSheet displays title, subtitle and content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTaroGlassSheet<void>(
                    context: context,
                    builder: (_) => const TaroGlassSheet(
                      title: 'Ritual Sheet',
                      subtitle: 'SUBTITLE',
                      child: Text('Sheet Body'),
                    ),
                  ),
                  child: const Text('Launch'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.text('Ritual Sheet'), findsOneWidget);
      expect(find.text('SUBTITLE'), findsOneWidget);
      expect(find.text('Sheet Body'), findsOneWidget);
    });
  });

  group('G3 Shell migration', () {
    testWidgets('isolates tab and dock glass while preserving tab state', (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      final camera = find.byType(CameraScanScreen, skipOffstage: false);
      final table = find.byType(TableWorkspace, skipOffstage: false);
      final tableState = tester.state(table);
      final cameraState = tester.state(camera);

      final tableLayer = find.descendant(
        of: table,
        matching: find.byType(TaroGlassLayer, skipOffstage: false),
      );
      final layers = [
        camera,
        find.byType(AlmanacScreen, skipOffstage: false),
        find.byType(AstralScreen, skipOffstage: false),
        find.byType(TaroGlassDock),
      ].map((target) {
        final layer = find.ancestor(
          of: target,
          matching: find.byType(TaroGlassLayer, skipOffstage: false),
        );
        return tester.element(layer);
      }).toSet();
      layers.add(tester.element(tableLayer));
      expect(layers, hasLength(5));

      const shutter = ValueKey('shutter');
      expect(find.byKey(shutter, skipOffstage: false), findsOneWidget);
      expect(find.byKey(shutter, skipOffstage: false).hitTestable(), findsNothing);

      await tester.tap(find.text('CAMERA'));
      await tester.pump();
      expect(find.byKey(shutter).hitTestable(), findsOneWidget);

      await tester.tap(find.text('TABLE'));
      await tester.pump();
      expect(find.byKey(shutter, skipOffstage: false).hitTestable(), findsNothing);
      expect(tester.state(table), same(tableState));
      expect(tester.state(camera), same(cameraState));
      expect(find.byType(TaroGlassDock), findsOneWidget);
    });

    testWidgets('MainNavigationShell uses TaroGlassDock and switches all 4 tabs', (
      tester,
    ) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      expect(find.byType(TaroGlassDock), findsOneWidget);
      final dockSize = tester.getSize(find.byType(TaroGlassDock));
      expect(dockSize.height, greaterThanOrEqualTo(48));

      // Switch through Almanac -> Astral -> Camera -> Table.
      await tester.tap(find.text('ALMANAC'));
      await tester.pump();
      expect(find.text('All (78)'), findsOneWidget);

      await tester.tap(find.text('ASTRAL'));
      await tester.pump();
      expect(find.byType(TaroGlassDock), findsOneWidget);

      await tester.tap(find.text('CAMERA'));
      await tester.pump();
      expect(find.byKey(const ValueKey('shutter')), findsOneWidget);

      await tester.tap(find.text('TABLE'));
      await tester.pump();
      expect(find.text('Choose Spread'), findsOneWidget);
    });

    testWidgets('AppSettingsSheet uses TaroGlassSheet + segmented language + Pro card', (
      tester,
    ) async {
      final settings = AppSettingsController();
      final astral = AstralController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: astral),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AppSettingsSheet.show(context),
                    child: const Text('Open Settings'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.byType(TaroGlassSegmentedControl<AppLanguage>), findsOneWidget);
      expect(find.byType(TaroGlassPanel), findsOneWidget);

      await tester.tap(find.text('РУССКИЙ'));
      await tester.pumpAndSettle();
      expect(settings.language, AppLanguage.ru);

      await tester.tap(find.byKey(const ValueKey('settings-pro-card')));
      await tester.pumpAndSettle();
      expect(find.byType(ProSubscriptionSheet), findsOneWidget);
      expect(find.byType(TaroGlassButton), findsOneWidget);
    });
  });
}
