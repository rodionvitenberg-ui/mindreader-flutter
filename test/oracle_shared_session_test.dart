import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/shell/main_navigation_shell.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/oracle_session_controller.dart';

import 'fakes/fake_camera_platform.dart';
import 'helpers/table_test_helpers.dart';

/// PHASE 4.1 — Shared Oracle session (verify).
///
/// The invariant: Full Chat / Voice Overlay / Compact Oracle all read ONE
/// [OracleSessionController] — one `sessionId`, one `messages` list, one
/// context — and switching between views/tabs never creates a NEW AI session.
///
/// This locks the structural guarantee at the app level: `main.dart` registers
/// the controller ONCE in a `MultiProvider`, and every consumer reads that
/// single instance. Switching tabs (IndexedStack) and panes (workspace
/// PageView) must preserve the instance, the stable `sessionId`, and the
/// conversation.
void main() {
  OracleSessionController sessionOf(WidgetTester tester) => tester
      .element(find.byType(MainNavigationShell))
      .read<OracleSessionController>();

  testWidgets(
    'ONE shared Oracle session survives every tab switch (no new AI session)',
    (tester) async {
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      final session = sessionOf(tester);
      session.beginSession(sessionId: 'shared-4-1');
      session.addUserMessage('hello oracle');

      // The dock icons are unique to the nav bar (verified: no other screen
      // uses these outlined glyphs), so tapping them is unambiguous.
      await tester.tap(find.byIcon(Icons.menu_book_outlined)); // -> ALMANAC
      await tester.pump();
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');

      await tester.tap(find.byType(AstralZodiacIcon)); // -> ASTRAL
      await tester.pump();
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');

      await tester.tap(find.byIcon(Icons.style_outlined)); // -> TABLE
      await tester.pump();
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');
    },
  );

  testWidgets(
    'Oracle session survives Camera ↔ Table ↔ Oracle transitions',
    (tester) async {
      CameraPlatform.instance = FakeCameraPlatform();

      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await activateSpread(tester, 'Three Cards'); // Table (Digital Table, pane 0)

      final session = sessionOf(tester);
      session.beginSession(sessionId: 'shared-4-1b');
      session.addUserMessage('hello oracle');

      // Table -> Oracle (workspace pane 0 -> pane 1, the Oracle AI Chat).
      await goToPane(tester, 1);
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1b');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');

      // Oracle -> Camera (tab 0): the camera opens (fake) but the session
      // must not be touched.
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pump();
      await tester.pump();
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1b');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');

      // Camera -> Table (tab 1): the workspace is still on the Oracle pane.
      await tester.tap(find.byIcon(Icons.style_outlined));
      await tester.pump();
      await tester.pump();
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1b');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');

      // Oracle -> Table (pane 1 -> pane 0) and back still preserve it.
      await goToPane(tester, 0);
      expect(identical(sessionOf(tester), session), isTrue);
      expect(sessionOf(tester).sessionId, 'shared-4-1b');
      expect(sessionOf(tester).messages.single.text, 'hello oracle');
    },
  );
}

