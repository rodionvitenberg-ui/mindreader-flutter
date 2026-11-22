import '../l10n/app_strings.dart';
import '../models/custom_spread.dart';
import '../models/dealt_card_slot.dart';
import '../models/divination_card.dart';
import '../models/divination_system.dart';
import '../models/spread_type.dart';
import '../models/tarot_card_model.dart';

enum ElementalInfluence { reinforcing, supportive, opposing, neutral }

/// What a link actually teaches — the mentor names the method instead of
/// pretending every pair is elemental.
enum ReadingLinkKind {
  /// Golden Dawn dignities between two Tarot elements.
  elementalDignity,

  /// A positional comparison (Celtic Cross pairs, custom neighbours).
  positional,

  /// Lenormand: the second card qualifies the first (no reversals, no dignities).
  lenormandPair,
}

/// The traditional pair line for [a] read with [b] ("With the Scythe, …"),
/// or null when the dataset has no authored line for that exact pair.
///
/// One lookup for the whole app: the Focus-view pill and the reading engine
/// must never disagree about what a pair says.
String? lenormandCombination(
  LenormandDivinationCard a,
  LenormandDivinationCard b,
) {
  final needle = b.card.name.toLowerCase();
  for (final line in a.card.combinations) {
    if (line.toLowerCase().contains(needle)) return line;
  }
  return null;
}

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
    this.influence, {
    this.kind = ReadingLinkKind.positional,
    this.combination,
  }) : from = a.index,
       to = b.index,
       fromId = a.card!.id,
       toId = b.card!.id,
       fromName = a.card!.name,
       toName = b.card!.name,
       fromRole = a.role,
       toRole = b.role,
       fromElement = a.card!.element,
       toElement = b.card!.element;
  final int from, to, fromId, toId;
  final String method, fromRole, toRole;

  /// Reader-facing explanation in the language currently being rendered.
  String get explanation => localizedExplanation(AppStrings.current);
  final String fromName, toName;
  final Element fromElement, toElement;
  final ElementalInfluence? influence;
  final ReadingLinkKind kind;

  /// Lenormand only: the authored traditional pair line, when it exists.
  final String? combination;

  bool includes(int index) => from == index || to == index;

  /// True when this method reads the two cards as pulling against each other
  /// (opposing elemental dignities). A tension to interpret — never a
  /// cancellation, and never a "bad" card (G4.2).
  bool get isContradictory =>
      kind == ReadingLinkKind.elementalDignity &&
      influence == ElementalInfluence.opposing;

  /// Localized, reader-facing explanation of this link.
  String localizedExplanation(AppLanguage lang) => switch (kind) {
    ReadingLinkKind.lenormandPair => AppStrings.t(lang, 'reading.link.lenormandPair', {
      'a': fromName,
      'b': toName,
    }),
    ReadingLinkKind.elementalDignity => _elemental(lang),
    ReadingLinkKind.positional => AppStrings.t(lang, 'reading.link.positional', {
      'a': fromRole,
      'b': toRole,
    }),
  };

  String _elemental(AppLanguage lang) {
    final influence = this.influence;
    if (influence == null) {
      return AppStrings.t(lang, 'reading.link.positional', {
        'a': fromRole,
        'b': toRole,
      });
    }
    return AppStrings.t(lang, 'reading.link.elemental', {
      'a': fromElement.label,
      'b': toElement.label,
      'influence': AppStrings.t(lang, 'reading.influence.${influence.name}'),
    });
  }

  Map<String, Object?> toJson() => {
    'method': method,
    'kind': kind.name,
    'positions': [from + 1, to + 1],
    'cardIds': [fromId, toId],
    'influence': influence?.name,
    'explanation': explanation,
    if (combination != null) 'combination': combination,
  };
}

List<ReadingRelationship> readingRelationships({
  required DivinationSystem system,
  required SpreadType type,
  required CustomSpreadConfig? custom,
  required List<DealtCardSlot> slots,
}) {
  final result = <ReadingRelationship>[];
  void pair(
    int i,
    int j,
    String method, {
    bool elemental = false,
    ReadingLinkKind kind = ReadingLinkKind.positional,
  }) {
    if (i >= slots.length || j >= slots.length) return;
    final a = slots[i], b = slots[j];
    if (a.state != SlotState.faceUp ||
        b.state != SlotState.faceUp ||
        a.card?.system != system ||
        b.card?.system != system) {
      return;
    }
    final left = a.card!, right = b.card!;
    result.add(
      ReadingRelationship(
        a,
        b,
        method,
        elemental ? influenceOf(left.element, right.element) : null,
        kind: elemental ? ReadingLinkKind.elementalDignity : kind,
        combination:
            kind == ReadingLinkKind.lenormandPair &&
                left is LenormandDivinationCard &&
                right is LenormandDivinationCard
            ? lenormandCombination(left, right)
            : null,
      ),
    );
  }

  // Lenormand is read as neighbouring pairs (subject + qualifier) — never as
  // elemental dignities, never reversed. The Focus-view pill uses the same
  // `lenormandCombination` lookup, so board and engine cannot disagree.
  if (system == DivinationSystem.lenormand) {
    for (var i = 1; i < slots.length; i++) {
      pair(
        i - 1,
        i,
        'Lenormand pair: subject + qualifier',
        kind: ReadingLinkKind.lenormandPair,
      );
    }
    return result;
  }
  if (system != DivinationSystem.tarot) return result;

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
