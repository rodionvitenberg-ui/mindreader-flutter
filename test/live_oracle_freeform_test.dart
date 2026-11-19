import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/oracle_action.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/state/live_oracle_controller.dart';

void main() {
  group('LiveOracleController', () {
    test('begin / setIntention / recordAction / reset lifecycle', () {
      final c = LiveOracleController();
      expect(c.isActive, isFalse);

      c.begin(intention: '');
      expect(c.isActive, isTrue);

      c.setIntention('  a question  ');
      expect(c.intention, 'a question');

      c.recordAction(OracleAction.suggestSpread);
      expect(c.pendingAction, OracleAction.suggestSpread);

      c.reset();
      expect(c.isActive, isFalse);
      expect(c.intention, isNull);
      expect(c.pendingAction, isNull);
    });
  });

  group('planGuidedTransition', () {
    test('never drops cards and proposes roles beyond the template', () {
      final plan = planGuidedTransition(
        existingCardCount: 5,
        targetRoles: ['Past', 'Present', 'Future'],
      );
      expect(plan.keptCards, 5);
      expect(plan.assignments, hasLength(5));
      expect(plan.requiresConfirmation, isTrue);
      expect(plan.assignments[0].role, 'Past');
      expect(plan.assignments[3].isGeneric, isTrue);
      expect(plan.assignments[3].role, 'Card 4');
    });

    test('zero existing cards -> no confirmation required', () {
      final plan = planGuidedTransition(
        existingCardCount: 0,
        targetRoles: ['Past', 'Present', 'Future'],
      );
      expect(plan.requiresConfirmation, isFalse);
      expect(plan.assignments, isEmpty);
    });
  });

  group('interpretFreeform (offline)', () {
    test('empty table -> prompts to lay cards, always respond', () async {
      final svc = OracleSynthesisService();
      final cmd = await svc.interpretFreeform(
        intention: 'love',
        slots: const [],
      );
      expect(cmd.action, OracleAction.respond);
      expect(cmd.text, contains('no spread is required'));
    });

    test('freely-laid card -> deterministic reading naming the loudest card',
        () async {
      final svc = OracleSynthesisService();
      final slots = [
        DealtCardSlot(index: 0, role: 'Card 1')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck[0]), false),
      ];
      final cmd = await svc.interpretFreeform(
        intention: 'a new beginning',
        slots: slots,
      );
      expect(cmd.action, OracleAction.respond);
      expect(cmd.text, contains('a new beginning'));
      expect(cmd.text, contains(tarotDeck[0].name));
    });
  });

  group('oraclePersona (4.8)', () {
    test('forbids categorical medical / financial / legal predictions', () {
      final p = OracleSynthesisService.oraclePersona;
      expect(p, contains('medical'));
      expect(p, contains('financial'));
      expect(p, contains('legal'));
    });

    test('keeps spoken answers shorter than written', () {
      expect(OracleSynthesisService.oraclePersona, contains('spoken'));
    });
  });
}
