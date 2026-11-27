import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/features/rituals/daily_rituals_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await showProfile(tester);
  }

  Future<void> openDataTab(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('profile-tab-data')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder section(SettingsSection section) => find.byKey(ValueKey(section));

  testWidgets('settings split the six collapsible sections across two tabs in order', (
    tester,
  ) async {
    await openProfile(tester);

    const profileTabSections = [
      SettingsSection.personalContext,
      SettingsSection.subscription,
      SettingsSection.readingExperience,
    ];
    const dataTabSections = [
      SettingsSection.language,
      SettingsSection.account,
      SettingsSection.deviceMigration,
    ];

    final profilePositions = profileTabSections
        .map((item) => tester.getTopLeft(section(item)).dy)
        .toList();
    expect(profilePositions, orderedEquals([...profilePositions]..sort()));
    expect(find.text('DAILY RITUALS'), findsNothing);
    expect(find.text('DAILY RITUAL REMINDERS'), findsNothing);

    for (final item in profileTabSections) {
      await tester.tap(section(item));
      await tester.pump();
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TaroGlassToggle), findsNothing);
    expect(find.text('PRO MONTHLY'), findsNothing);

    await openDataTab(tester);
    final dataPositions = dataTabSections
        .map((item) => tester.getTopLeft(section(item)).dy)
        .toList();
    expect(dataPositions, orderedEquals([...dataPositions]..sort()));

    for (final item in dataTabSections) {
      await tester.tap(section(item));
      await tester.pump();
    }

    final settings = tester
        .element(find.byType(ProfileScreen))
        .read<AppSettingsController>();
    expect(SettingsSection.values.any(settings.sectionExpanded), isFalse);
    expect(find.text('IMPORT DATA'), findsNothing);
    expect(find.text('ENGLISH'), findsNothing);
  });

  testWidgets(
    'collapsed sections survive reopening settings and restarting the app',
    (tester) async {
      await openProfile(tester);
      await tester.tap(section(SettingsSection.personalContext));
      await tester.pump();
      await openDataTab(tester);
      await tester.tap(section(SettingsSection.language));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await showProfile(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TaroGlassToggle), findsNWidgets(3));
      await openDataTab(tester);
      expect(find.text('ENGLISH'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      final settings = tester
          .element(find.byType(TaroGlassDock))
          .read<AppSettingsController>();
      await settings.initialLoad;
      await showProfile(tester);
      expect(find.byType(TextField), findsNothing);
      await openDataTab(tester);
      expect(find.text('ENGLISH'), findsNothing);
      await tester.tap(section(SettingsSection.language));
      await tester.pump();
      expect(find.text('ENGLISH'), findsOneWidget);
    },
  );

  testWidgets(
    'the reading switch keeps its thumb visible and moves left when off',
    (tester) async {
      await openProfile(tester);
      final toggle = find.byKey(const ValueKey(ReadingAid.positions));
      final align = find.descendant(
        of: toggle,
        matching: find.byType(AnimatedAlign),
      );
      final track = find.descendant(
        of: toggle,
        matching: find.byType(AnimatedContainer),
      );
      Finder thumb() =>
          find.byWidget(tester.widget<AnimatedAlign>(align).child!);
      Color? trackColor() =>
          (tester.widget<AnimatedContainer>(track).decoration as BoxDecoration)
              .color;
      final onColor = trackColor();
      double thumbPosition() =>
          tester.getCenter(thumb()).dx - tester.getCenter(track).dx;
      final right = thumbPosition();
      await tester.tap(toggle);
      await tester.pump();
      expect(thumb().hitTestable(), findsOneWidget);
      await tester.pump(TaroMotion.fast);
      final left = thumbPosition();
      expect(left, lessThan(right));
      expect(trackColor(), isNot(onColor));
      expect(trackColor()!.r, trackColor()!.g);
      expect(thumb().hitTestable(), findsOneWidget);
      expect(tester.widget<TaroGlassToggle>(toggle).value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reading_aid.positions'), isFalse);

      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(TaroMotion.fast);
      expect(thumbPosition(), closeTo(right, .01));
      expect(tester.widget<TaroGlassToggle>(toggle).value, isTrue);
    },
  );

  testWidgets('the bell opens Daily Rituals in the last dock tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    final dock = find.byType(TaroGlassDock);
    final bell = find.descendant(
      of: dock,
      matching: find.byIcon(Icons.notifications_outlined),
    );
    expect(
      tester.getCenter(bell).dx,
      greaterThan(tester.getCenter(find.text('ASTRAL')).dx),
    );
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(find.byType(DailyRitualsScreen), findsOneWidget);
    expect(find.text('DAILY RITUALS'), findsOneWidget);
    expect(tester.widget<TaroGlassDock>(dock).index, 4);

    final dailyToggle = find.byKey(const ValueKey('ritual-daily-toggle'));
    expect(find.text('DISABLE RITUALS'), findsNothing);
    await tester.tap(dailyToggle);
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('ritual_enabled'),
      isTrue,
    );
    expect(find.byType(DailyRitualsScreen), findsOneWidget);

    await tester.tap(find.text('TABLE'));
    await tester.pumpAndSettle();
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(tester.widget<TaroGlassToggle>(dailyToggle).value, isTrue);
  });

  testWidgets('PROFILE tabs carry PRO cards on tab 1 and language selector on tab 2', (
    tester,
  ) async {
    await openProfile(tester);

    expect(find.text('PRO MONTHLY'), findsOneWidget);
    expect(find.text('PRO ANNUAL'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-terms-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-privacy-link')), findsOneWidget);

    await openDataTab(tester);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('РУССКИЙ'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-migration-warning')), findsOneWidget);
  });

  testWidgets('language toggle on DATA & LANGUAGE tab relabels the dock EN <-> RU', (
    tester,
  ) async {
    await openProfile(tester);
    await openDataTab(tester);
    expect(find.text('TABLE', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('РУССКИЙ'));
    await tester.pump();
    expect(find.text('СТОЛ', skipOffstage: false), findsOneWidget);
    expect(find.text('TABLE', skipOffstage: false), findsNothing);

    await tester.tap(find.text('ENGLISH'));
    await tester.pump();
    expect(find.text('TABLE', skipOffstage: false), findsOneWidget);
    expect(find.text('СТОЛ', skipOffstage: false), findsNothing);
  });

  testWidgets('PRO sheet displays Early Supporter offer (\$4.99 vs \$6.99) and status check', (
    tester,
  ) async {
    await openProfile(tester);

    await tester.tap(find.text('PRO MONTHLY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('pro-subscription-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-early-supporter-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-checkout-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-check-status-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('pro-support-project-button')), findsOneWidget);
    expect(find.text('\$4.99'), findsWidgets);
    expect(find.text('\$6.99'), findsWidgets);
    expect(find.text('\$39.99'), findsWidgets);
  });
}
