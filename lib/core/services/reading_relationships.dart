import '../models/custom_spread.dart';
import '../models/dealt_card_slot.dart';
import '../models/divination_system.dart';
import '../models/spread_type.dart';
import '../models/tarot_card_model.dart';

enum ElementalInfluence { reinforcing, supportive, opposing, neutral }

/// Golden Dawn-style elemental dignities. Reversal is interpreted separately.
ElementalInfluence influenceOf(Element a, Element b) {
  if (a == b) return ElementalInfluence.reinforcing;
  final pair = {a, b};
  if (pair.containsAll([Element.fire, Element.air]) ||
      pair.containsAll([Element.water, Element.earth])) {
    return ElementalInfluence.supportive;
  }
  if (pair.containsAll([Element.fire, Element.water]) ||
      pair.containsAll([Element.air, Element.earth])) {
    return ElementalInfluence.opposing;
  }
  return ElementalInfluence.neutral;
}

class ReadingRelationship {
  ReadingRelationship(
    DealtCardSlot a,
    DealtCardSlot b,
    this.method,
    this.influence,
  ) : from = a.index,
      to = b.index,
      fromId = a.card!.id,
      toId = b.card!.id,
      explanation = influence == null
          ? '${a.role} and ${b.role}: compare what each position contributes.'
          : '${a.card!.element.label} and ${b.card!.element.label} are ${influence.name} in this method.';
  final int from, to, fromId, toId;
  final String method, explanation;
  final ElementalInfluence? influence;
  bool includes(int index) => from == index || to == index;
  Map<String, Object?> toJson() => {
    'method': method,
    'positions': [from + 1, to + 1],
    'cardIds': [fromId, toId],
    'influence': influence?.name,
    'explanation': explanation,
  };
}

List<ReadingRelationship> readingRelationships({
  required DivinationSystem system,
  required SpreadType type,
  required CustomSpreadConfig? custom,
  required List<DealtCardSlot> slots,
}) {
  if (system != DivinationSystem.tarot) return const [];
  final result = <ReadingRelationship>[];
  void pair(int i, int j, String method, {bool elemental = false}) {
    if (i >= slots.length || j >= slots.length) return;
    final a = slots[i], b = slots[j];
    if (a.state != SlotState.faceUp ||
        b.state != SlotState.faceUp ||
        a.card?.system != system ||
        b.card?.system != system) {
      return;
    }
    result.add(
      ReadingRelationship(
        a,
        b,
        method,
        elemental ? influenceOf(a.card!.element, b.card!.element) : null,
      ),
    );
  }

  if (custom != null) {
    if (custom.isFiveCardLine) {
      // Positions 1–2–3 and 3–4–5. Each center is read with its two
      // immediate influences. No cross-table all-pairs network.
      for (final center in [1, 3]) {
        pair(
          center - 1,
          center,
          'Five-card line: influence on neighboring center',
          elemental: true,
        );
        pair(
          center + 1,
          center,
          'Five-card line: influence on neighboring center',
          elemental: true,
        );
      }
    } else if (custom.compareNeighbors &&
        custom.cardCount >= 2 &&
        custom.cardCount <= 4) {
      for (var i = 1; i < custom.cardCount; i++) {
        pair(i - 1, i, 'Custom neighboring positions', elemental: true);
      }
    }
  } else if (type == SpreadType.three) {
    pair(0, 1, 'Three-card dignity: influence on the center', elemental: true);
    pair(2, 1, 'Three-card dignity: influence on the center', elemental: true);
    pair(
      0,
      2,
      'Three-card dignity: compare the flanking influences',
      elemental: true,
    );
  } else if (type == SpreadType.celticCross) {
    for (final (a, b) in [(0, 1), (2, 3), (4, 5), (6, 7)]) {
      pair(a, b, 'Celtic Cross positions');
    }
  } else if (type == SpreadType.four || type == SpreadType.loveBridge) {
    pair(0, 1, 'Two shores');
  }
  return result;
}
