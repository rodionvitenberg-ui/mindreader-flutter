import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/data/lenormand_data.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/custom_spread.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_card.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/reading_relationships.dart';
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
  test('Lenormand reads neighboring face-up cards as one pair each', () {
    final ctrl = SpreadController()..setSystem(DivinationSystem.lenormand);
    ctrl.setLenormandSpread(LenormandSpread.three);
    ctrl.dealNextCard();
    ctrl.flipSlot(0);
    expect(ctrl.relationships, isEmpty, reason: 'a pair needs two cards');

    for (var i = 1; i < 3; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    expect(ctrl.relationships.map((r) => (r.from, r.to)), [(0, 1), (1, 2)]);

    final first = ctrl.relationships.first;
    expect(first.kind, ReadingLinkKind.lenormandPair);
    expect(first.influence, isNull, reason: 'no elemental dignities here');
    expect(first.localizedExplanation(AppLanguage.en), contains('subject'));
    expect(first.localizedExplanation(AppLanguage.ru), contains('уточня'));
    expect(
      first.combination == null ||
          first.combination!.toLowerCase().startsWith('with the'),
      isTrue,
      reason: 'the authored pair line is preserved verbatim',
    );
  });

  test('the authored Lenormand pair line is found by the second card', () {
    final byName = {for (final c in lenormandDeck) c.name: c};
    for (final card in lenormandDeck) {
      for (final line in card.combinations) {
        if (!line.toLowerCase().startsWith('with the ')) continue;
        final rest = line.substring('with the '.length);
        LenormandCard? partner;
        for (final entry in byName.entries) {
          if (rest.toLowerCase().startsWith(entry.key.toLowerCase())) {
            partner = entry.value;
            break;
          }
        }
        if (partner == null) continue;
        expect(
          lenormandCombination(
            LenormandDivinationCard(card),
            LenormandDivinationCard(partner),
          ),
          line,
          reason: '${card.name} + ${partner.name}',
        );
        return; // one authenticated pair is enough to pin the lookup
      }
    }
    fail('the dataset has no authored pair line');
  });

  test('runes have no relationship links', () {
    final ctrl = SpreadController()..setSystem(DivinationSystem.runes);
    ctrl.setRuneCast(RuneCast.three);
    for (var i = 0; i < 3; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    expect(ctrl.relationships, isEmpty);
  });

  test('tarot links keep their kind', () {
    final ctrl = SpreadController()..setSpreadType(SpreadType.three);
    for (var i = 0; i < 3; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    expect(
      ctrl.relationships.every(
        (r) => r.kind == ReadingLinkKind.elementalDignity,
      ),
      isTrue,
    );

    ctrl.setSpreadType(SpreadType.celticCross);
    for (var i = 0; i < ctrl.spreadCardCount; i++) {
      ctrl.dealNextCard();
      ctrl.flipSlot(i);
    }
    expect(
      ctrl.relationships.every((r) => r.kind == ReadingLinkKind.positional),
      isTrue,
    );
  });

  test('only opposing dignities count as a contradictory link', () {
    final ctrl = SpreadController()
      ..loadScannedSpread(
        system: DivinationSystem.tarot,
        cards: [
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == Element.fire),
          ),
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == Element.water),
          ),
        ],
        reversed: [false, false],
        spreadType: SpreadType.three,
      );
    expect(ctrl.relationships.first.influence, ElementalInfluence.opposing);
    expect(ctrl.relationships.first.isContradictory, isTrue);

    final peaceful = SpreadController()
      ..loadScannedSpread(
        system: DivinationSystem.tarot,
        cards: [
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == Element.fire),
          ),
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == Element.air),
          ),
        ],
        reversed: [false, false],
        spreadType: SpreadType.three,
      );
    expect(
      peaceful.relationships.first.influence,
      ElementalInfluence.supportive,
    );
    expect(peaceful.relationships.first.isContradictory, isFalse);
  });
}
