import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/features/digital_table/widgets/reading_guide.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  testWidgets(
    'visibility and optional guidance follow out-of-order reveals in both views',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await activateSpread(tester, 'Three Cards');
      final ctx = tester.element(find.byType(DigitalTableScreen));
      final ctrl = ctx.read<SpreadController>();
      final settings = ctx.read<AppSettingsController>();
      await settings.setAid(ReadingAid.positions, false);
      await tester.pump();
      expect(find.text('1 · State'), findsNothing);
      final guide = find.byKey(const ValueKey('reading-guide'));
      expect(guide, findsNothing);
      final order = ctrl.deckTop.map((c) => c.id).take(3).toList();
      await tester.tap(find.byKey(const ValueKey('overview-deck')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await settings.setAid(ReadingAid.guide, true);
      await tester.pump();
      expect(guide, findsOneWidget);
      expect(recommendedPosition(ctrl), 1);
      ctrl.dealNextCard();
      ctrl.dealNextCard();
      ctrl.flipSlot(2);
      expect(recommendedPosition(ctrl), 1);
      ctrl.flipSlot(1);
      expect(recommendedPosition(ctrl), 0);
      ctrl.flipSlot(0);
      expect(recommendedPosition(ctrl), isNull);
      await tester.pump();
      await tester.tap(find.text('FOCUS VIEW'));
      await tester.pump();
      expect(guide, findsOneWidget);
      expect(ctrl.slots.map((s) => s.card!.id), order);
      String prompt() => OracleSynthesisService.buildSynthesisPrompt(
        slots: ctrl.slots,
        system: ctrl.system,
        spreadLabel: ctrl.spreadLabel,
        focusLine: ctrl.spreadFocusLine,
        relationships: ctrl.relationships,
      )!;
      final before = prompt();
      expect(
        before,
        contains('Three-card dignity: compare the flanking influences'),
      );
      await settings.setAid(ReadingAid.guide, false);
      await settings.setAid(ReadingAid.relationships, true);
      await tester.pump();
      expect(guide, findsNothing);
      expect(prompt(), before);
    },
  );
}
