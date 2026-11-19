import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';

import 'helpers/table_test_helpers.dart';

/// Sprint 4 layout contract:
/// * Pane 0 (Digital Table) — a pure tactile sanctuary: NO capsule, NO
///   context chips; only the permanently-anchored dormant Synthesize CTA.
/// * Pane 1 (Oracle AI Chat) — the ONLY home of the Gemini input capsule
///   and the interactive context chips.
/// * Panes switch exclusively by horizontal swipe (the top 3-pill bar is
///   gone).
///
/// Two-step entry: the app boots on Step 1 (Choose Spread). These tests
/// activate a spread first to reach the Active Digital Table (Step 2).
void main() {
  testWidgets('Pane 0 keeps no chat UI: only the dormant Synthesize CTA',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Triad Flow');

    // No top 3-pill nav bar anymore ('TABLE' only remains on the bottom
    // navigation dock).
    expect(find.text('ORACLE CHAT'), findsNothing);
    expect(find.text('HISTORY'), findsNothing);

    // No capsule, no context chips on the Digital Table.
    expect(find.byType(GeminiInputCapsule), findsNothing);
    expect(find.text('✨ Relationships'), findsNothing);
    expect(find.text('⚡ Crossroads'), findsNothing);
    expect(find.text('🔮 Blind Draw'), findsNothing);

    // The Synthesize CTA is permanently present — dormant before any
    // deal/flip, with the progress hint label.
    expect(find.byType(SynthesizeChatCta), findsOneWidget);
    expect(find.text('✦ SYNTHESIZE IN CHAT (FLIP ALL CARDS)'), findsOneWidget);
    expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsNothing);
  });

  testWidgets('Pane 1 hosts the capsule and the context chips exclusively',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Triad Flow');
    await goToPane(tester, 1);

    expect(find.byType(GeminiInputCapsule), findsOneWidget);
    expect(find.text('✨ Relationships'), findsOneWidget);
    expect(find.text('⚡ Crossroads'), findsOneWidget);
    expect(find.text('🔮 Blind Draw'), findsOneWidget);
    // The table CTA never renders on the chat pane.
    expect(find.byType(SynthesizeChatCta), findsNothing);
  });

  testWidgets(
      'context pills: single-select radio, zero size change, zero overflow',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Triad Flow');
    await goToPane(tester, 1);

    // Tapping a pill activates it with a soft glow — NO ✓ icon is ever
    // rendered.
    await tester.tap(find.byKey(const ValueKey('context-chip-0')));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byKey(const ValueKey('context-chip-0-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('context-chip-1-active')), findsNothing);

    // Tapping another pill switches the single selection.
    await tester.tap(find.byKey(const ValueKey('context-chip-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('context-chip-0-active')), findsNothing);
    expect(find.byKey(const ValueKey('context-chip-1-active')), findsOneWidget);

    // Tapping the active pill deselects it.
    await tester.tap(find.byKey(const ValueKey('context-chip-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('context-chip-1-active')), findsNothing);

    // The 3 pills never overflow the screen (16 px margins, Expanded
    // equal widths — the old row bled 13 px past the right edge).
    final rightEdge =
        tester.getTopRight(find.byKey(const ValueKey('context-chip-2'))).dx;
    expect(rightEdge, lessThanOrEqualTo(800));
  });
}
