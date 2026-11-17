import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/gemini_input_capsule.dart';
import 'package:mindreader/features/digital_table/widgets/synthesize_chat_cta.dart';
import 'package:mindreader/main.dart';

/// Sprint 4 layout contract:
/// * Pane 0 (Digital Table) — a pure tactile sanctuary: NO capsule, NO
///   context chips; only the permanently-anchored dormant Synthesize CTA.
/// * Pane 1 (Oracle AI Chat) — the ONLY home of the Gemini input capsule
///   and the interactive context chips.
/// * Panes switch exclusively by horizontal swipe (the top 3-pill bar is
///   gone).
void main() {
  Future<void> goToPane(WidgetTester tester, int pane) async {
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    var current = controller.page!.round();
    while (current != pane) {
      await tester.dragFrom(
        const Offset(200, 300),
        Offset(current < pane ? -600 : 600, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // Settle the post-drag fling ballistic — while it runs, the
      // PageView's scrollable ignores pointer events.
      while (controller.position.isScrollingNotifier.value) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.pump();
      current = controller.page!.round();
    }
  }

  testWidgets('Pane 0 keeps no chat UI: only the dormant Synthesize CTA',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

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
    await goToPane(tester, 1);

    expect(find.byType(GeminiInputCapsule), findsOneWidget);
    expect(find.text('✨ Relationships'), findsOneWidget);
    expect(find.text('⚡ Crossroads'), findsOneWidget);
    expect(find.text('🔮 Blind Draw'), findsOneWidget);
    // The table CTA never renders on the chat pane.
    expect(find.byType(SynthesizeChatCta), findsNothing);
  });

  testWidgets('chip tap shows the ✓ selected state, a second tap toggles off',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await goToPane(tester, 1);

    await tester.tap(find.byKey(const ValueKey('context-chip-0')));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('context-chip-0')));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
