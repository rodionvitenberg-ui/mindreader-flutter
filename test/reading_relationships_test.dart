import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/reading_relationships.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
