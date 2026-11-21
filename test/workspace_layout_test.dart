import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  testWidgets('Pane 0 keeps no chat UI: only the dormant Synthesize CTA',
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

    // The Synthesize CTA is permanently present — dormant before any
    // deal/flip, without the old "(FLIP ALL CARDS)" suffix.
    expect(find.byType(SynthesizeChatCta), findsOneWidget);
    expect(find.text('✦ SYNTHESIZE IN CHAT'), findsOneWidget);
    expect(find.textContaining('FLIP ALL CARDS'), findsNothing);
    expect(find.text('✦ SYNTHESIZE IN CHAT →'), findsNothing);
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
    expect(find.byType(SynthesizeChatCta), findsNothing);
  });
}
