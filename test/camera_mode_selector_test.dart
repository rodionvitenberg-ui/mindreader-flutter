import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/features/camera_scan/camera_scan_screen.dart';
import 'package:mindreader/features/camera_scan/widgets/camera_mode_selector.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1 (1.5) — the Camera now leads with a persisted 3-mode segmented
/// switch (QUICK SCAN | GUIDED SPREAD | LIVE ORACLE) instead of the removed
/// card-count chips, and a live guided/live session asks before switching.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<({SpreadController spread, OracleSessionController session})>
      pumpCamera(WidgetTester tester) async {
    final spread = SpreadController();
    final session = OracleSessionController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: spread),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          home: CameraScanScreen(onHandoff: () {}, isActiveTab: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (spread: spread, session: session);
  }

  testWidgets('renders the three physical reading modes', (tester) async {
    await pumpCamera(tester);

    expect(find.text('QUICK SCAN'), findsOneWidget);
    expect(find.text('GUIDED SPREAD'), findsOneWidget);
    expect(find.text('LIVE ORACLE'), findsOneWidget);
  });

  testWidgets('the card-count chips are gone', (tester) async {
    await pumpCamera(tester);

    expect(find.text('3'), findsNothing);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('tapping a mode selects it and persists the choice',
      (tester) async {
    await pumpCamera(tester);

    await tester.tap(find.byKey(const ValueKey('camera-mode-guidedSpread')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('camera_mode'), 'guidedSpread');
  });

  testWidgets('restores the persisted mode on open', (tester) async {
    SharedPreferences.setMockInitialValues({'camera_mode': 'liveOracle'});
    await pumpCamera(tester);

    final selector = tester.widget<CameraModeSelector>(
      find.byType(CameraModeSelector),
    );
    expect(selector.value, ReadingMode.liveOracle);
  });

  testWidgets('no confirmation dialog when no session is active',
      (tester) async {
    await pumpCamera(tester);

    await tester.tap(find.byKey(const ValueKey('camera-mode-liveOracle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('camera-mode-confirm')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('camera_mode'), 'liveOracle');
  });

  testWidgets('a live guided session asks before switching', (tester) async {
    final state = await pumpCamera(tester);
    state.session.beginSession(mode: ReadingMode.guidedSpread);

    await tester.tap(find.byKey(const ValueKey('camera-mode-liveOracle')));
    await tester.pumpAndSettle();

    // The confirmation dialog blocks the switch.
    expect(find.byKey(const ValueKey('camera-mode-confirm')), findsOneWidget);

    // Cancelling keeps the current mode.
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    final selector = tester.widget<CameraModeSelector>(
      find.byType(CameraModeSelector),
    );
    expect(selector.value, ReadingMode.quickScan);
  });

  testWidgets('confirming the switch changes the mode', (tester) async {
    final state = await pumpCamera(tester);
    state.session.beginSession(mode: ReadingMode.guidedSpread);

    await tester.tap(find.byKey(const ValueKey('camera-mode-liveOracle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SWITCH'));
    await tester.pumpAndSettle();

    final selector = tester.widget<CameraModeSelector>(
      find.byType(CameraModeSelector),
    );
    expect(selector.value, ReadingMode.liveOracle);
  });
}
