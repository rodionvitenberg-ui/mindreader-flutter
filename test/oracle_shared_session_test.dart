import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mindreader/features/shell/main_navigation_shell.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/oracle_session_controller.dart';

/// PHASE 4.1 — Shared Oracle session (verify).
///
/// The invariant: Full Chat / Voice Overlay / Compact Oracle all read ONE
/// [OracleSessionController] — one `sessionId`, one `messages` list, one
/// context — and switching between views/tabs never creates a NEW AI session.
///
/// This locks the structural guarantee at the app level: `main.dart` registers
/// the controller ONCE in a `MultiProvider`, and every consumer reads that
/// single instance. Switching tabs (IndexedStack) must preserve the instance,
/// the stable `sessionId`, and the conversation.
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

      await tester.tap(find.byIcon(Icons.auto_awesome_outlined)); // -> ASTRAL
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
}
