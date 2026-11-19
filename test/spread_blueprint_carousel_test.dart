import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/features/digital_table/widgets/spread_blueprint_carousel.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:provider/provider.dart';

/// Iteration 6 — the horizontal visual spread-blueprint carousel above the
/// deck and the top-left profile avatar:
/// * the avatar pushes the full-page ProfileScreen (the dock stays clean);
/// * tapping a FREE blueprint switches the active spread geometry instantly;
/// * tapping a LOCKED PRO blueprint opens the ProSubscriptionSheet without
///   touching the active spread;
/// * swiping the carousel reveals the later blueprints.
void main() {
  testWidgets('top-left profile avatar pushes the full-page ProfileScreen',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('PERSONAL CONTEXT & BIRTH DATA'), findsOneWidget);
  });

  testWidgets('carousel: tapping a FREE spread activates that table geometry',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Step 1 picker defaults to Triad Flow (3 slots); free blueprints are
    // shown on the swipeable row (the "N · " prefix is stripped).
    expect(find.text('Triad Flow'), findsOneWidget);
    expect(find.text('Target & Shadow'), findsOneWidget);

    await tester.tap(find.text('Target & Shadow'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ctrl =
        tester.element(find.byType(PageView)).read<SpreadController>();
    expect(ctrl.spreadType, SpreadType.four);
    // The 4 numbered slot labels reflect the new geometry on the Active Table.
    expect(find.text('1 · Shore'), findsOneWidget);
    expect(find.text('4 · Turning'), findsOneWidget);
    expect(find.text('3 · Vector'), findsNothing);
  });

  testWidgets('carousel: tapping a PRO spread now selects it (PRO disabled)',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // PRO restrictions are disabled centrally, so a PRO blueprint selects and
    // activates like any free spread (no paywall).
    await tester.tap(find.text('Love & Relationship Bridge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final ctrl =
        tester.element(find.byType(PageView)).read<SpreadController>();
    expect(ctrl.spreadType, SpreadType.loveBridge);
    expect(ctrl.isSpreadActive, isTrue);
  });

  testWidgets('carousel: swiping left reveals later blueprints',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.drag(
      find.byType(SpreadBlueprintCarousel),
      const Offset(-600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The final PRO blueprint is now built and tappable.
    expect(find.text('Celtic Cross'), findsOneWidget);
  });
}
