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

  Finder section(SettingsSection section) => find.byKey(ValueKey(section));

  testWidgets('settings show the five collapsible sections in order', (
    tester,
  ) async {
    await openProfile(tester);
    final headers = [for (final item in SettingsSection.values) section(item)];
    final positions = headers.map((f) => tester.getTopLeft(f).dy).toList();
    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.text('DAILY RITUALS'), findsNothing);
    expect(find.text('DAILY RITUAL REMINDERS'), findsNothing);

    for (final header in headers) {
      await tester.tap(header);
      await tester.pump();
    }
    final settings = tester
        .element(find.byType(ProfileScreen))
        .read<AppSettingsController>();
    expect(SettingsSection.values.any(settings.sectionExpanded), isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TaroGlassToggle), findsNothing);
    expect(find.text('IMPORT DATA'), findsNothing);
    expect(find.text('PRO MONTHLY'), findsNothing);
    expect(find.text('ENGLISH'), findsNothing);
  });

  testWidgets(
    'collapsed sections survive reopening settings and restarting the app',
    (tester) async {
      await openProfile(tester);
      for (final item in [
        SettingsSection.personalContext,
        SettingsSection.language,
      ]) {
        await tester.tap(section(item));
        await tester.pump();
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await showProfile(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('ENGLISH'), findsNothing);
      expect(find.byType(TaroGlassToggle), findsNWidgets(3));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      final settings = tester
          .element(find.byType(TaroGlassDock))
          .read<AppSettingsController>();
      await settings.initialLoad;
      await showProfile(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('ENGLISH'), findsNothing);
      await tester.tap(section(SettingsSection.language));
      await tester.pump();
      expect(find.text('ENGLISH'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
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

    await tester.tap(find.byType(TaroGlassToggle).hitTestable());
    await tester.pump();
    await tester.tap(find.text('SAVE RITUAL TIMES'));
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
    expect(
      tester
          .widget<TaroGlassToggle>(find.byType(TaroGlassToggle).hitTestable())
          .value,
      isTrue,
    );
  });

  testWidgets('PROFILE page carries the language selector + PRO cards', (
    tester,
  ) async {
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

  testWidgets('PRO sheet reports PRO ACTIVE (restrictions disabled)', (
    tester,
  ) async {
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
