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

  testWidgets('carousel: tapping a FREE spread switches the table geometry',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Default is Triad Flow (3 slots).
    expect(find.text('3 · Triad Flow'), findsOneWidget);
    expect(find.text('3 · Vector'), findsOneWidget);

    await tester.tap(find.text('4 · Target & Shadow'));
    await tester.pump();

    final ctrl = tester
        .element(find.byType(SpreadBlueprintCarousel))
        .read<SpreadController>();
    expect(ctrl.spreadType, SpreadType.four);
    // The header pill + the 4 numbered slot labels reflect the new geometry.
    expect(find.textContaining('4 · TARGET & SHADOW'), findsOneWidget);
    expect(find.text('1 · Shore'), findsOneWidget);
    expect(find.text('4 · Turning'), findsOneWidget);
    expect(find.text('3 · Vector'), findsNothing);
  });

  testWidgets('carousel: tapping a LOCKED PRO spread opens the paywall',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('5 · Love & Relationship Bridge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ACTIVATE PRO'), findsOneWidget);
    // The active spread is unchanged — the locked blueprint never applies.
    final ctrl = tester
        .element(find.byType(SpreadBlueprintCarousel))
        .read<SpreadController>();
    expect(ctrl.spreadType, SpreadType.three);
  });

  testWidgets('carousel: swiping left reveals later blueprints',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.drag(
      find.byType(SpreadBlueprintCarousel),
      const Offset(-500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The final PRO blueprint is now built and tappable.
    expect(find.text('10 · Celtic Cross'), findsOneWidget);
  });
}
