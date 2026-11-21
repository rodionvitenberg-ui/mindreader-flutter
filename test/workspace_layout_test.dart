import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/analyze_reading_button.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/reading_context_field.dart';
import 'package:mindreader/features/digital_table/widgets/reading_subject_toggle.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';

import 'helpers/table_test_helpers.dart';

/// Workspace layout contract:
/// * Pane 0 (Digital Table) — clean tactile space: NO subject toggle, NO topic
///   field, NO large Synthesize CTA, NO capsule/chips; only the single compact
///   Analyze Reading button.
/// * Pane 1 (Oracle AI Chat) — hosts the preparation controls, Gemini input
///   capsule, and interactive context chips.
void main() {
  testWidgets(
      'Pane 0 keeps no Oracle prep or chat UI: only the compact Analyze Reading button',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');

    // No top 3-pill nav bar anymore ('TABLE' only remains on the bottom
    // navigation dock).
    expect(find.text('ORACLE CHAT'), findsNothing);
    expect(find.text('HISTORY'), findsNothing);

    // No capsule, no context chips, and no redundant Oracle prep controls on
    // the Digital Table.
    expect(find.byType(GeminiInputCapsule), findsNothing);
    expect(find.byType(ReadingSubjectToggle), findsNothing);
    expect(find.byType(ReadingContextField), findsNothing);
    expect(find.byType(SynthesizeChatCta), findsNothing);
    expect(find.text('✨ Relationships'), findsNothing);
    expect(find.text('⚡ Crossroads'), findsNothing);
    expect(find.text('🔮 Blind Draw'), findsNothing);

    // Only the single compact Analyze Reading button is shown (dormant before
    // deal/flip).
    final analyzeBtn = find.byType(AnalyzeReadingButton);
    expect(analyzeBtn, findsOneWidget);
    expect(tester.widget<AnalyzeReadingButton>(analyzeBtn).enabled, isFalse);
    expect(find.text('Analyze Reading'), findsOneWidget);
  });

  testWidgets('Pane 1 hosts the capsule and the context chips exclusively',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    await goToPane(tester, 1);

    expect(find.byType(GeminiInputCapsule), findsOneWidget);
    expect(find.text('✨ Relationships'), findsOneWidget);
    expect(find.text('⚡ Crossroads'), findsOneWidget);
    expect(find.text('🔮 Blind Draw'), findsOneWidget);
    // The table button never renders on the chat pane.
    expect(find.byType(AnalyzeReadingButton), findsNothing);
    expect(find.byType(SynthesizeChatCta), findsNothing);
  });

  testWidgets(
      'context pills: single-select radio, zero size change, zero overflow',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
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
