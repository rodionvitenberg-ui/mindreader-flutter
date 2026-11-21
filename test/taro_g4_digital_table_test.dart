import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/widgets/custom_spread_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/deck_picker_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/reading_bottom_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/reading_subject_toggle.dart';
import 'package:mindreader/features/digital_table/widgets/ritual_settings_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/spread_selector_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/table_test_helpers.dart';

Widget _wrapSimple(Widget child) => MaterialApp(
  theme: buildTaroTheme(),
  home: Scaffold(
    body: TaroGlassLayer(
      mode: TaroGlassMode.simple,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  ),
);

void main() {
  group('G4 components: TaroGlassChip & TaroGlassPill', () {
    testWidgets('interactive chip fires onTap and enforces >=44px height', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrapSimple(
          TaroGlassChip(
            label: 'Love & Relationships',
            selected: true,
            onTap: () => tapped++,
          ),
        ),
      );

      final size = tester.getSize(find.byType(TaroGlassChip));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('Love & Relationships'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('useGlass chip wraps in TaroGlassSurface and TaroGlassPill renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSimple(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaroGlassChip(
                label: 'Hero Filter',
                useGlass: true,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              const TaroGlassPill(
                label: 'PHYSICAL SYNC',
                icon: Icons.photo_camera_front_outlined,
                accent: true,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TaroGlassSurface), findsOneWidget);
      expect(find.text('PHYSICAL SYNC'), findsOneWidget);
    });
  });

  group('G4 components: TaroGlassProgress', () {
    testWidgets('renders determinate linear bar with percentage label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSimple(
          const SizedBox(
            width: 240,
            child: TaroGlassProgress(label: 'SYNTHESIS', value: 0.6),
          ),
        ),
      );

      expect(find.text('SYNTHESIS'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('renders indeterminate linear and circular variants', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapSimple(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                child: TaroGlassProgress(label: 'WEAVING'),
              ),
              SizedBox(height: 16),
              TaroGlassProgress(linear: false, label: 'Loading'),
            ],
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('WEAVING'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('G4 Digital Table migration', () {
    testWidgets(
      'Active Table shows compact AnalyzeReadingButton and Oracle keeps TaroGlassSegmentedControl for subject',
      (tester) async {
        await tester.pumpWidget(const MindreaderApp());
        await tester.pump();
        await activateSpread(tester, 'Three Cards');

        // Digital Table has no subject toggle or legacy large CTA.
        expect(find.byType(ReadingSubjectToggle), findsNothing);
        expect(find.byType(SynthesizeChatCta), findsNothing);
        expect(find.byKey(const ValueKey('analyze-reading-button')), findsOneWidget);

        // Deal and reveal all 3 cards so the button illuminates with TaroGlassSurface.
        final ctrl = tester
            .element(find.byType(PageView))
            .read<SpreadController>();
        for (var i = 0; i < 3; i++) {
          ctrl.dealNextCardOrClarifier();
          ctrl.flipSlot(i);
        }
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('analyze-reading-button')),
            matching: find.byType(TaroGlassSurface),
          ),
          findsOneWidget,
        );

        // Tapping opens Oracle where the subject segmented control lives.
        await tester.tap(find.byKey(const ValueKey('analyze-reading-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.byType(ReadingSubjectToggle), findsOneWidget);
        expect(find.byType(TaroGlassSegmentedControl<bool>), findsOneWidget);

        // Toggle subject Myself -> Someone Else on the Oracle screen.
        await tester.tap(find.text('FOR SOMEONE ELSE'));
        await tester.pump();
        final seg = tester.widget<TaroGlassSegmentedControl<bool>>(
          find.byType(TaroGlassSegmentedControl<bool>),
        );
        expect(seg.value, isFalse);
      },
    );

    testWidgets('GeminiInputCapsule uses TaroGlassSurface and sends text', (
      tester,
    ) async {
      String? sent;
      var plusTapped = 0;
      await tester.pumpWidget(
        _wrapSimple(
          GeminiInputCapsule(
            fieldKey: const ValueKey('test-field'),
            sendKey: const ValueKey('test-send'),
            onSend: (v) => sent = v,
            onPlus: () => plusTapped++,
          ),
        ),
      );

      expect(find.byType(TaroGlassSurface), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('test-field')), 'Hello');
      await tester.tap(find.byKey(const ValueKey('test-send')));
      await tester.pump();
      expect(sent, 'Hello');

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(plusTapped, 1);
    });

    testWidgets('Digital Table modal sheets render inside TaroGlassSheet', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final spread = SpreadController();
      final settings = AppSettingsController();
      final decks = DeckPackController();

      Future<void> openAndVerify(
        WidgetTester tester,
        Future<void> Function(BuildContext) opener,
        Type expectedWidget,
      ) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: spread),
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: decks),
            ],
            child: MaterialApp(
              theme: buildTaroTheme(),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => opener(context),
                      child: const Text('OPEN'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('OPEN'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(expectedWidget), findsOneWidget);
        expect(find.byType(TaroGlassSheet), findsOneWidget);
      }

      Future<void> dismiss(WidgetTester tester, Type widgetType) async {
        Navigator.of(tester.element(find.byType(widgetType))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await openAndVerify(tester, SpreadSelectorSheet.show, SpreadSelectorSheet);
      await dismiss(tester, SpreadSelectorSheet);

      await openAndVerify(tester, DeckPickerSheet.show, DeckPickerSheet);
      await dismiss(tester, DeckPickerSheet);

      await openAndVerify(tester, ReadingBottomSheet.show, ReadingBottomSheet);
      await dismiss(tester, ReadingBottomSheet);

      await openAndVerify(tester, CustomSpreadSheet.show, CustomSpreadSheet);
      await dismiss(tester, CustomSpreadSheet);

      await openAndVerify(tester, RitualSettingsSheet.show, RitualSettingsSheet);
      await tester.pumpAndSettle();
      expect(find.byType(TaroGlassToggle), findsOneWidget);
      expect(find.byType(TaroGlassButton), findsOneWidget);
      await dismiss(tester, RitualSettingsSheet);
    });
  });
}
