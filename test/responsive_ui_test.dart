import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/main.dart';

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
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

    // Oracle Chat pane renders its input capsule without overflowing. Jump
    // the workspace PageView directly (gesture distance is viewport-dependent
    // and irrelevant to the layout contract this test asserts).
    final pageView = tester.widget<PageView>(find.byType(PageView).first);
    pageView.controller!.jumpToPage(1);
    await tester.pump();
    expect(find.byType(GeminiInputCapsule), findsOneWidget);
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
