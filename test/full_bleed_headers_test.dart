import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro_tokens.dart';
import 'package:mindreader/features/digital_table/widgets/spread_deck_dock.dart';
import 'package:mindreader/features/profile/widgets/profile_header.dart';
import 'package:mindreader/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  const statusBarTop = 44.0;

  Future<void> bootWithStatusBar(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: statusBarTop, bottom: 20);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
  }

  testWidgets(
    'SPREAD VIEW dock backdrop covers status bar while other Table screens stay inset',
    (tester) async {
      await bootWithStatusBar(tester);

      // Step 1 (Spread Selection): ProfileHeader starts below status bar.
      expect(
        tester.getTopLeft(find.byType(ProfileHeader)).dy,
        closeTo(statusBarTop, 0.5),
      );
      expect(find.byType(SpreadDeckDock), findsNothing);

      // Step 2 (SPREAD VIEW): semi-transparent dock starts at y = 0,
      // covering the status bar, while the header controls stay at y = 44.
      await activateSpread(tester, 'Three Cards');
      final dockFinder = find.byKey(const ValueKey('spread-deck-dock'));
      expect(dockFinder, findsOneWidget);
      final dockRect = tester.getRect(dockFinder);
      expect(dockRect.top, closeTo(0.0, 0.5));
      expect(dockRect.left, closeTo(0.0, 0.5));
      expect(dockRect.right, closeTo(390.0, 0.5));

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(of: dockFinder, matching: find.byType(DecoratedBox))
            .first,
      );
      final boxDec = decorated.decoration as BoxDecoration;
      expect(boxDec.color, TaroColors.surface.withValues(alpha: 0.72));

      final spreadHeaderTop = tester
          .getTopLeft(
            find.descendant(
              of: dockFinder,
              matching: find.byType(ProfileHeader),
            ),
          )
          .dy;
      expect(spreadHeaderTop, closeTo(statusBarTop, 0.5));

      // Switch to FOCUS VIEW: no dock, ProfileHeader stays at y = 44.
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expect(find.byType(SpreadDeckDock), findsNothing);
      expect(
        tester.getTopLeft(find.byType(ProfileHeader)).dy,
        closeTo(statusBarTop, 0.5),
      );

      // Oracle Chat (Pane 1) and History (Pane 2) keep their top SafeArea inset.
      await goToPane(tester, 1);
      expect(
        tester.getTopLeft(find.byType(ProfileHeader)).dy,
        closeTo(statusBarTop, 0.5),
      );

      await goToPane(tester, 2);
      expect(
        tester.getTopLeft(find.byType(ProfileHeader)).dy,
        closeTo(statusBarTop, 0.5),
      );
    },
  );

  testWidgets(
    'Almanac filter backdrop covers switcher, header and status bar on Tarot/Lenormand/Runes but not Zodiac',
    (tester) async {
      await bootWithStatusBar(tester);

      await tester.tap(find.text('ALMANAC'));
      await tester.pump();

      final topBarFinder = find.byKey(const ValueKey('almanac-top-bar'));
      final filtersFinder = find.byKey(const ValueKey('almanac-filters'));
      final expectedColor = TaroColors.background.withValues(alpha: 0.64);

      for (final tabKey in [
        'almanac-system-tarot',
        'almanac-system-lenormand',
        'almanac-system-runes',
      ]) {
        await tester.tap(find.byKey(ValueKey(tabKey)));
        await tester.pump();

        final topBar = tester.widget<ColoredBox>(topBarFinder);
        final filters = tester.widget<ColoredBox>(filtersFinder);
        expect(topBar.color, expectedColor);
        expect(filters.color, expectedColor);

        final topBarRect = tester.getRect(topBarFinder);
        expect(topBarRect.top, closeTo(0.0, 0.5));
        expect(topBarRect.left, closeTo(0.0, 0.5));
        expect(topBarRect.right, closeTo(390.0, 0.5));

        final headerRect = tester.getRect(
          find.descendant(
            of: topBarFinder,
            matching: find.byType(ProfileHeader),
          ),
        );
        expect(headerRect.top, closeTo(statusBarTop, 0.5));

        final switcherRect = tester.getRect(find.byKey(ValueKey(tabKey)));
        expect(switcherRect.top, greaterThanOrEqualTo(headerRect.bottom - 0.5));
        expect(switcherRect.bottom, lessThanOrEqualTo(topBarRect.bottom + 0.5));

        final deckPillRect = tester.getRect(
          find.byKey(const ValueKey('almanac-pack-pill')),
        );
        expect(deckPillRect.top, closeTo(topBarRect.bottom, 0.5));
      }

      // Zodiac tab stays untouched: topBar sits below status bar with 0.92 alpha.
      await tester.tap(find.byKey(const ValueKey('almanac-system-zodiac')));
      await tester.pumpAndSettle();

      final zodiacTopBar = tester.widget<ColoredBox>(topBarFinder);
      expect(zodiacTopBar.color, TaroColors.background.withValues(alpha: 0.92));
      expect(
        tester.getRect(topBarFinder).top,
        closeTo(statusBarTop, 0.5),
      );
    },
  );
}
