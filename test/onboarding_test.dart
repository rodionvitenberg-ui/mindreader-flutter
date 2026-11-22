import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/features/shell/main_navigation_shell.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/onboarding_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingController', () {
    late AppSettingsController settings;
    late OnboardingController onboarding;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = AppSettingsController();
      // Settle the fire-and-forget load() so it never notifies after the
      // tearDown disposed the controller.
      await settings.initialLoad;
      onboarding = OnboardingController(settings: settings);
    });

    tearDown(() {
      onboarding.dispose();
      settings.dispose();
    });

    test('a fresh install opens the intro', () async {
      await onboarding.initialLoad;
      expect(onboarding.completed, isFalse);
      expect(onboarding.loaded, isTrue);
    });

    test('a beginner gets thorough guidance switched on', () async {
      await onboarding.initialLoad;
      await onboarding.complete(tarotFamiliar: false);

      expect(onboarding.completed, isTrue);
      expect(settings.guideDetail, GuideDetail.thorough);
      expect(settings.enabled(ReadingAid.guide), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed_v1'), isTrue);
    });

    test('an experienced reader keeps short hints and current switches', () async {
      await onboarding.initialLoad;
      await onboarding.complete(tarotFamiliar: true);

      expect(onboarding.completed, isTrue);
      expect(settings.guideDetail, GuideDetail.concise);
      expect(settings.enabled(ReadingAid.guide), isFalse);
    });

    test('skipping the intro changes no reading setting', () async {
      await onboarding.initialLoad;
      await onboarding.complete();

      expect(onboarding.completed, isTrue);
      expect(settings.guideDetail, GuideDetail.concise);
      expect(settings.enabled(ReadingAid.guide), isFalse);
    });

    test('the completed flag survives a restart and can be replayed', () async {
      await onboarding.initialLoad;
      await onboarding.complete(tarotFamiliar: true);

      final restored = OnboardingController(settings: settings);
      await restored.initialLoad;
      expect(restored.completed, isTrue);

      await restored.restart();
      expect(restored.completed, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed_v1'), isFalse);
      restored.dispose();
    });
  });

  group('OnboardingFlow', () {
    testWidgets('walks intro → experience → ready and seeds the level', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp(showOnboarding: true));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('onboarding-intro')), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('onboarding-experience')),
        findsOneWidget,
      );

      await tester.tap(find.text('NEW TO TAROT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('onboarding-ready')), findsOneWidget);

      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('onboarding-ready')), findsNothing);
      final settings = tester
          .element(find.byType(MainNavigationShell))
          .read<AppSettingsController>();
      expect(settings.guideDetail, GuideDetail.thorough);
      expect(settings.enabled(ReadingAid.guide), isTrue);
    });

    testWidgets('skip closes the intro and leaves guidance off', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp(showOnboarding: true));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('SKIP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('onboarding-intro')), findsNothing);

      final settings = tester
          .element(find.byType(MainNavigationShell))
          .read<AppSettingsController>();
      expect(settings.enabled(ReadingAid.guide), isFalse);
    });

    testWidgets('the overlay lives under a Material ancestor', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp(showOnboarding: true));
      await tester.pump();
      await tester.pump();

      final intro = find.byKey(const ValueKey('onboarding-intro'));
      expect(intro, findsOneWidget);
      // Above the Navigator Flutter has no Material, so text would fall back to
      // the yellow double-underline error style (caught on a real device).
      expect(
        find.ancestor(of: intro, matching: find.byType(Material)),
        findsWidgets,
      );
      expect(
        DefaultTextStyle.of(tester.element(intro)).style.decoration,
        isNot(TextDecoration.underline),
      );
    });

    testWidgets('widget tests without the flag never get the overlay', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-intro')), findsNothing);
    });

    testWidgets('Profile → Reading experience can replay the intro', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MindreaderApp(showOnboarding: true));
      await tester.pump();
      await tester.pump();
      final onboarding = tester
          .element(find.byType(MainNavigationShell))
          .read<OnboardingController>();
      await onboarding.complete(tarotFamiliar: true);
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-intro')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Replay the intro'));
      await tester.tap(find.text('Replay the intro'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('onboarding-intro')), findsOneWidget);
    });
  });
}
