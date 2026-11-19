import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounded, diagnosable workspace helpers shared by the widget tests.
///
/// The two-step Table refactor (Choose Spread → Active Table) means a test
/// that boots [MindreaderApp] lands on Step 1 (the spread picker), NOT the
/// Active Table. These helpers (a) enter Step 2 deterministically and
/// (b) swipe between panes with a CAPPED pump loop so a regression fails
/// fast with a clear message instead of hanging the whole run.

/// Step 1 → Step 2: taps the free spread card named [cardLabel] (the
/// picker strips the leading `N · ` prefix, e.g. `3 · Triad Flow` →
/// `Triad Flow`). Tapping a free card selects it AND activates the table.
///
/// Idempotent: if the card is not on screen (already on the Active Table)
/// it simply returns.
Future<void> activateSpread(WidgetTester tester, String cardLabel) async {
  final card = find.text(cardLabel);
  if (card.evaluate().isEmpty) return;
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Step 1: switches the divination system (TAROT/LENORMAND/RUNES) and then
/// enters the Active Table (Step 2) by tapping the [spreadLabel] card of
/// that system (the picker strips the leading `N · ` prefix).
Future<void> activateSystem(
  WidgetTester tester,
  String systemLabel,
  String spreadLabel,
) async {
  await tester.tap(find.text(systemLabel));
  await tester.pump();
  await activateSpread(tester, spreadLabel);
}

/// Swipes horizontally between the three workspace panes until [pane] is
/// active. Both loops are BOUNDED: the post-drag fling settles within
/// [settleIterations] frames, and at most [maxAttempts] swipes are made.
/// Throws a descriptive [TestFailure] if the target pane is not reached
/// (instead of looping forever).
Future<void> goToPane(
  WidgetTester tester,
  int pane, {
  int maxAttempts = 4,
  int settleIterations = 12,
}) async {
  final controller =
      tester.widget<PageView>(find.byType(PageView)).controller!;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final current = controller.page!.round();
    if (current == pane) return;
    await tester.dragFrom(
      const Offset(200, 300),
      Offset(current < pane ? -600 : 600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // While the drag's ballistic keeps the PageView in pointer-ignoring
    // mode, pump — but never more than [settleIterations] frames.
    var iterations = 0;
    while (controller.position.isScrollingNotifier.value &&
        iterations < settleIterations) {
      await tester.pump(const Duration(milliseconds: 250));
      iterations++;
    }
    await tester.pump();
  }
  final page = controller.page!.round();
  if (page != pane) {
    throw TestFailure(
      'goToPane: could not reach pane $pane after $maxAttempts swipes '
      '(stuck on $page, isScrolling='
      '${controller.position.isScrollingNotifier.value}). '
      'Did you activate the table (Step 2) with activateSpread first? '
      'Visible texts: ${_visibleTexts(tester)}',
    );
  }
}

String _visibleTexts(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((t) => t.trim().isNotEmpty)
      .take(24)
      .toList();
  return texts.toString();
}
