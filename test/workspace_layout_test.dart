import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/analyze_reading_button.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';

import 'helpers/table_test_helpers.dart';

/// Workspace layout contract:
/// * Pane 0 (Digital Table) — clean tactile space: NO subject toggle, NO large
///   Synthesize CTA, NO capsule/chips; only the single compact Analyze Reading
///   button (dormant until the spread can be analyzed).
/// * Pane 1 (Oracle Conversation) — the Oracle preparation/conversation
///   surface: no context chips, no table button; the anchored capsule appears
///   only once a reading exists.
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

    // No capsule, no context chips on the Digital Table.
    expect(find.byType(GeminiInputCapsule), findsNothing);
    expect(find.text('✨ Relationships'), findsNothing);
    expect(find.text('⚡ Crossroads'), findsNothing);
    expect(find.text('🔮 Blind Draw'), findsNothing);

    // Only the single compact Analyze Reading button is shown (dormant before
    // any deal/flip); the old big Synthesize CTA is gone from the table.
    final analyzeBtn = find.byType(AnalyzeReadingButton);
    expect(analyzeBtn, findsOneWidget);
    expect(tester.widget<AnalyzeReadingButton>(analyzeBtn).enabled, isFalse);
    expect(find.text('Analyze Reading'), findsOneWidget);
    expect(find.byType(SynthesizeChatCta), findsNothing);
  });

  testWidgets('Oracle waits for reading preparation before showing chat',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    await goToPane(tester, 1);

    expect(find.text('NO READING YET'), findsOneWidget);
    expect(find.byType(GeminiInputCapsule), findsNothing);
    expect(find.text('✨ Relationships'), findsNothing);
    expect(find.text('⚡ Crossroads'), findsNothing);
    expect(find.text('🔮 Blind Draw'), findsNothing);
    // Neither the legacy CTA nor the table's Analyze button render in Oracle.
    expect(find.byType(SynthesizeChatCta), findsNothing);
    expect(find.byType(AnalyzeReadingButton), findsNothing);
  });
}
