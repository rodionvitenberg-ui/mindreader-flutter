import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/reading_relationships.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/spread_session_snapshot.dart';
import 'package:mindreader/state/synthesis_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('explicit line of five uses two neighboring triples and one row', () {
    final ctrl = SpreadController()
      ..setCustomSpread(
        CustomSpreadConfig.fromQuestions(
          questions: ['A', 'B', 'C', 'D', 'E'],
          compareNeighbors: true,
        ),
      );
    for (var i = 0; i < 5; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    expect(ctrl.relationships.map((r) => (r.from, r.to)), [
      (0, 1),
      (2, 1),
      (2, 3),
      (4, 3),
    ]);
    expect(
      spreadBoardGeometryForCustom(
        5,
        fiveCardLine: true,
      ).slotRects.map((r) => r.top).toSet(),
      {0.0},
    );
  });
  test('custom rules round-trip while older readings retain their positional method', () {
    final ctrl = SpreadController()
      ..setCustomSpread(
        CustomSpreadConfig.fromQuestions(
          questions: ['Why?', 'What next?'],
          compareNeighbors: true,
        ),
      );
    for (var i = 0; i < 2; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    final raw = SpreadSessionSnapshot.capture(
      ctrl: ctrl,
      session: SynthesisSession(),
      timestamp: 'today',
      notebook: 'Readings',
    ).toJson();
    for (final explicit in [true, false]) {
      if (!explicit) raw.remove('compareNeighbors');
      final saved = SpreadSessionSnapshot.fromJson(raw);
      ctrl.restoreSpread(
        system: saved.system,
        customSpread: saved.customSpread,
        customQuestions: saved.customQuestions,
        compareNeighbors: saved.compareNeighbors,
        cards: saved.toRestoreCards(),
        sessionNotes: saved.sessionNotes,
      );
      expect(ctrl.relationships.length, explicit ? 1 : 0);
      expect(ctrl.slots.last.role, 'What next?');
    }
  });
  test('canonical minors and the selected dignity table', () {
    for (final card in tarotDeck.where((c) => c.suit != null)) {
      expect(card.element, card.suit!.element);
    }
    expect(
      influenceOf(Element.air, Element.earth),
      ElementalInfluence.opposing,
    );
    expect(
      influenceOf(Element.fire, Element.earth),
      ElementalInfluence.neutral,
    );
  });
  test(
    'center, flanks, semantic cross and explicitly defined custom comparisons',
    () {
      final ctrl = SpreadController();
      void reveal() {
        for (var i = 0; i < ctrl.spreadCardCount; i++) {
          ctrl.dealNextCard();
          ctrl.flipSlot(i);
        }
      }

      ctrl.setSpreadType(SpreadType.three);
      reveal();
      expect(ctrl.relationships.map((r) => (r.from, r.to)), [
        (0, 1),
        (2, 1),
        (0, 2),
      ]);
      ctrl.setSpreadType(SpreadType.celticCross);
      reveal();
      expect(ctrl.relationships, isNotEmpty);
      expect(ctrl.relationships.every((r) => r.influence == null), isTrue);
      for (final enable in [false, true]) {
        ctrl.setCustomSpread(
          CustomSpreadConfig.fromQuestions(
            questions: ['A', 'B', 'C', 'D'],
            compareNeighbors: enable,
          ),
        );
        reveal();
        expect(ctrl.relationships.length, enable ? 3 : 0);
      }
    },
  );
}
