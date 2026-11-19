import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/oracle_action.dart';
import 'package:mindreader/core/models/oracle_payload.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';

void main() {
  test('canonicalCardId qualifies a card id by system', () {
    expect(canonicalCardId(DivinationSystem.tarot, 13), 'tarot:13');
    expect(canonicalCardId(DivinationSystem.lenormand, 9), 'lenormand:9');
    expect(canonicalCardId(DivinationSystem.runes, 5), 'runes:5');
  });

  test('build describes only face-up cards with real canonical ids', () {
    final slots = <DealtCardSlot>[
      DealtCardSlot(index: 0, role: 'The Heart')
        ..placeCardFaceUp(TarotDivinationCard(tarotDeck[0]), false),
      DealtCardSlot(index: 1, role: 'The Shadow')
        ..placeCardFaceDown(TarotDivinationCard(tarotDeck[13]), true),
      DealtCardSlot(index: 2, role: 'The Path')
        ..placeCardFaceUp(TarotDivinationCard(tarotDeck[22]), true),
    ];
    slots[2].fromPhysicalCard = true;

    final payload = OraclePayload.build(
      sessionId: 's-1',
      source: ReadingSource.physical,
      mode: ReadingMode.liveOracle,
      system: DivinationSystem.tarot,
      slots: slots,
      currentPosition: 2,
      expectedAction: OracleAction.requestNextCard,
    );

    expect(payload.schemaVersion, OraclePayload.currentSchemaVersion);
    expect(payload.sessionId, 's-1');
    expect(payload.source, 'physical');
    expect(payload.mode, 'liveOracle');
    expect(payload.system, 'tarot');
    expect(payload.currentPosition, 2);
    expect(payload.expectedAction, 'requestNextCard');

    // The face-down card at index 1 is NOT leaked to the Oracle.
    expect(payload.cards, hasLength(2));
    expect(payload.cards[0].cardId, 'tarot:0');
    expect(payload.cards[0].orientation, 'upright');
    expect(payload.cards[0].source, 'digital');
    expect(payload.cards[0].confirmed, isTrue);
    expect(payload.cards[1].cardId, 'tarot:22');
    expect(payload.cards[1].orientation, 'reversed');
    expect(payload.cards[1].source, 'physical');
  });

  test('toJson emits the compact contract shape (no bbox, no image)', () {
    final payload = OraclePayload.build(
      sessionId: 's-2',
      source: ReadingSource.digital,
      mode: ReadingMode.standard,
      system: DivinationSystem.tarot,
      slots: [
        DealtCardSlot(index: 0, role: 'R1')
          ..placeCardFaceUp(TarotDivinationCard(tarotDeck[0]), false),
      ],
    );

    final json = payload.toJson();
    expect(json['schemaVersion'], 1);
    expect(json['cards'], isA<List>());
    expect(json.containsKey('spreadId'), isFalse);
    expect(json.containsKey('expectedAction'), isFalse);

    final card = (json['cards'] as List).first as Map;
    expect(
      card.keys.toSet(),
      {'cardId', 'position', 'role', 'orientation', 'source', 'confirmed'},
    );
  });
}
