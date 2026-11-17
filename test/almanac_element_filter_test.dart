import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
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

    // Water filter narrows the grid to exactly the water cards.
    final waterCount =
        tarotDeck.where((c) => c.element == Element.water).length;
    await tester.tap(find.byKey(const ValueKey('element-filter-water')));
    await tester.pump();
    expect(find.text('$waterCount OF 78'), findsOneWidget);

    // Fire filter switches the single active element.
    final fireCount =
        tarotDeck.where((c) => c.element == Element.fire).length;
    await tester.tap(find.byKey(const ValueKey('element-filter-fire')));
    await tester.pump();
    expect(find.text('$fireCount OF 78'), findsOneWidget);

    // Tapping the active element clears the filter.
    await tester.tap(find.byKey(const ValueKey('element-filter-fire')));
    await tester.pump();
    expect(find.text('78 OF 78'), findsOneWidget);
  });
}
