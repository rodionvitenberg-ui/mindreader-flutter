import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_camera_platform.dart';
import 'helpers/table_test_helpers.dart';

/// PHASE 5.5 — Responsive UI audit.
///
/// Boots the whole app at compact portrait, standard portrait and compact
/// landscape, activates the Digital Table and walks the panes. Any RenderFlex
/// overflow or layout exception is a hard failure in widget tests, so these
/// checks catch clipped/overlapping elements on small screens without brittle
/// pixel assertions.
void main() {
  Future<void> bootAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    CameraPlatform.instance = FakeCameraPlatform();
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
  }

  Future<void> walkTheApp(WidgetTester tester) async {
    await activateSpread(tester, 'Three Cards');
    expect(find.text('SPREAD VIEW'), findsOneWidget);
    // Dock is always reachable: every tab icon stays on screen.
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.style_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byType(AstralZodiacIcon), findsOneWidget);

    // Check both Oracle layouts at each size.
    final pages = find.byType(PageView).first;
    tester.widget<PageView>(pages).controller!.jumpToPage(1);
    await tester.pump();
    expect(find.text('NO READING YET'), findsOneWidget);
    expect(find.byType(GeminiInputCapsule), findsNothing);

    final spread = tester.element(pages).read<SpreadController>();
    for (var i = 0; i < spread.spreadCardCount; i++) {
      spread.dealNextCard();
      spread.flipSlot(i);
    }
    await tester.pump();
    final synthesize = find.text('✦ SYNTHESIZE IN CHAT →');
    await tester.ensureVisible(synthesize);
    await tester.tap(synthesize);
    await tester.pump();
    expect(find.byType(GeminiInputCapsule), findsOneWidget);
    await tester.tap(find.byTooltip('Show reading cards'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('oracle-card-rail')), findsOneWidget);
  }

  testWidgets('compact portrait (360x640) renders without overflow',
      (tester) async {
    await bootAt(tester, const Size(360, 640));
    await walkTheApp(tester);
  });

  testWidgets('standard portrait (412x915) renders without overflow',
      (tester) async {
    await bootAt(tester, const Size(412, 915));
    await walkTheApp(tester);
  });

  testWidgets('compact landscape (640x360) renders without overflow',
      (tester) async {
    await bootAt(tester, const Size(640, 360));
    await walkTheApp(tester);
  });

  testWidgets('1.3x text scaling renders without overflow', (tester) async {
    await bootAt(tester, const Size(360, 640), textScale: 1.3);
    await walkTheApp(tester);
  });
}
