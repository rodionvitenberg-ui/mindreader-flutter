import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:provider/provider.dart';

/// Iteration 5 — Rituals, Settings and PRO now live on the full-page
/// PROFILE tab (the dock is exactly 5 tabs), and the EN/RU toggle re-labels
/// the dock instantly.
void main() {
  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('PROFILE page hosts rituals inline (no dock action)',
      (tester) async {
    await openProfile(tester);

    expect(find.text('DAILY RITUAL'), findsOneWidget);
    expect(find.text('PERSONAL CONTEXT & BIRTH DATA'), findsOneWidget);
    expect(find.text('DEVICE MIGRATION'), findsOneWidget);
    expect(find.text('RITUALS'), findsNothing);
  });

  testWidgets('PROFILE page carries the language selector + PRO cards',
      (tester) async {
    await openProfile(tester);

    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('РУССКИЙ'), findsOneWidget);
    expect(find.text('PRO MONTHLY'), findsOneWidget);
    expect(find.text('PRO ANNUAL'), findsOneWidget);
  });

  testWidgets('language toggle relabels the dock EN <-> RU', (tester) async {
    await openProfile(tester);
    expect(find.text('TABLE'), findsOneWidget);

    await tester.tap(find.text('РУССКИЙ'));
    await tester.pump();
    expect(find.text('СТОЛ'), findsOneWidget);
    expect(find.text('TABLE'), findsNothing);

    await tester.tap(find.text('ENGLISH'));
    await tester.pump();
    expect(find.text('TABLE'), findsOneWidget);
    expect(find.text('СТОЛ'), findsNothing);
  });

  testWidgets('PRO sheet reports PRO ACTIVE (restrictions disabled)',
      (tester) async {
    await openProfile(tester);

    await tester.tap(find.text('PRO MONTHLY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // PRO restrictions are disabled centrally (kProRestrictionsEnabled=false),
    // so the sheet shows the ACTIVE state instead of an ACTIVATE CTA.
    expect(find.text('PRO ACTIVE'), findsWidgets);
    expect(find.text('ACTIVATE PRO'), findsNothing);

    final settings = tester
        .element(find.byType(ProfileScreen))
        .read<AppSettingsController>();
    expect(settings.isProUnlocked, isTrue);
  });
}
