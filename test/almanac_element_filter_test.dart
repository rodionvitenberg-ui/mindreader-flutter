import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';

/// Sprint 6 — Almanac fixes (screenshot 1000049372):
/// * the static `ELEMENTS` label is gone;
/// * 4 equal-width clickable element filter buttons filter the grid
///   (tapping the active one clears the filter);
/// * illustrated card tiles show the FULL artwork with NO header/footer
///   text bars (MAJOR ARCANA / SUIT · ELEMENT) over the historical scan.
void main() {
  testWidgets('element filter bar: no ELEMENTS label, 4 clickable filters',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No static ELEMENTS label anymore.
    expect(find.text('ELEMENTS'), findsNothing);

    // 4 equal-width element filter buttons are present.
    expect(find.byKey(const ValueKey('element-filter-fire')), findsOneWidget);
    expect(find.byKey(const ValueKey('element-filter-water')), findsOneWidget);
    expect(find.byKey(const ValueKey('element-filter-air')), findsOneWidget);
    expect(find.byKey(const ValueKey('element-filter-earth')), findsOneWidget);

    // Illustrated tiles (default Rider-Waite pack) show full-bleed
    // artwork: no text bars over the scans.
    expect(find.text('MAJOR ARCANA'), findsNothing);
    expect(find.text('▽ WATER'), findsNothing);

    // The old "N OF 78" header counter is gone — the system switcher and
    // the All (78) pill replaced it.
    expect(find.text('All (78)'), findsOneWidget);
    expect(find.text('TAROT'), findsOneWidget);

    // Water filter narrows the grid to exactly the water cards: the water
    // High Priestess stays, the air Fool disappears.
    await tester.tap(find.byKey(const ValueKey('element-filter-water')));
    await tester.pump();
    expect(find.text('THE HIGH PRIESTESS'), findsWidgets);
    expect(find.text('THE FOOL'), findsNothing);

    // Fire filter switches the single active element.
    await tester.tap(find.byKey(const ValueKey('element-filter-fire')));
    await tester.pump();
    expect(find.text('THE EMPEROR'), findsWidgets);
    expect(find.text('THE HIGH PRIESTESS'), findsNothing);

    // Tapping the active element clears the filter.
    await tester.tap(find.byKey(const ValueKey('element-filter-fire')));
    await tester.pump();
    expect(find.text('THE FOOL'), findsWidgets);
  });
}
