import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  final avatar = find
      .byKey(const ValueKey('profile-avatar-button'))
      .hitTestable();
  final profileBack = find.descendant(
    of: find.byType(ProfileScreen),
    matching: find.byType(BackButton),
  );

  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
  }

  void expectAvatar(WidgetTester tester) {
    expect(avatar, findsOneWidget);
    final rect = tester.getRect(avatar);
    expect(rect.size, const Size.square(48));
    expect(rect.right, closeTo(tester.view.physicalSize.width - 12, 0.1));
  }

  testWidgets(
    'section headers share the right profile action with the camera excluded',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 650);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      final dock = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .bottomNavigationBar!;
      final dockHeight = tester.getSize(find.byWidget(dock)).height;
      expect(dockHeight, 54 + 20);

      for (final tab in ['TABLE', 'ALMANAC', 'ASTRAL']) {
        await tester.tap(find.text(tab));
        await tester.pump();
        expectAvatar(tester);
        if (tab == 'ALMANAC') {
          final grid = find.byKey(const ValueKey('almanac-scroll'));
          final beforeScroll = tester.getRect(avatar);
          await tester.drag(grid, const Offset(0, -200));
          await tester.pump();
          expect(tester.getRect(avatar), beforeScroll);
        }
        await tester.tap(avatar);
        await settleRoute(tester);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expectAvatar(tester);
        await tester.tap(avatar);
        await settleRoute(tester);
        expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);
        await tester.tap(profileBack);
        await settleRoute(tester);
        expect(find.byType(ProfileScreen), findsNothing);
        expectAvatar(tester);
        expect(tester.takeException(), isNull);
      }

      tester.view.physicalSize = const Size(800, 600);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pump();
      await tester.tap(find.text('CAMERA'));
      await tester.pump();
      expect(avatar, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile preserves the active spread and the workspace back actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(720, 400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await activateSpread(tester, 'Daily Anchor');

      final viewport = find.byKey(const ValueKey('spread-viewport'));
      final controller = tester
          .widget<InteractiveViewer>(viewport)
          .transformationController!;
      final spread = tester.element(viewport).read<SpreadController>();
      spread.dealNextCardOrClarifier();
      spread.setReadingQuestion('A question to keep');
      controller.value = controller.value.clone()
        ..scaleByDouble(1.2, 1.2, 1.2, 1);
      final before = controller.value.clone();
      await tester.pump();
      expectAvatar(tester);

      await tester.tap(avatar);
      await settleRoute(tester);
      await tester.tap(profileBack);
      await settleRoute(tester);
      expect(controller.value, before);
      expect(spread.dealtCount, 1);
      expect(spread.readingQuestion, 'A question to keep');

      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expectAvatar(tester);
      await tester.tap(find.text('SPREAD VIEW'));
      await tester.pump();

      final pageController = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      for (final pane in [1, 2]) {
        pageController.jumpToPage(pane);
        await tester.pump();
        expectAvatar(tester);
        await tester.tap(find.byType(BackButton).hitTestable());
        await settleRoute(tester);
        expect(pageController.page, 0);
      }
      expect(spread.dealtCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
