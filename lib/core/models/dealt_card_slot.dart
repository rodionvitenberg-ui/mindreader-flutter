import 'divination_card.dart';

/// Lifecycle of one slot on the vertical board.
enum SlotState { empty, faceDown, faceUp }

/// Where the cards on the table came from.
///
/// * [digitalDeck] — dealt from the on-screen tactile deck/cluster (the
///   digital ledger tracks every extraction).
/// * [physicalCameraSync] — photographed from the user's real physical deck
///   via the camera pipeline. These cards exist OUTSIDE the digital
///   ledger: they never decrement [remaining].
enum TableSourceMode { digitalDeck, physicalCameraSync }

class DealtCardSlot {
  final int index;
  final String role; // from the active spread's slotRoles / 'Clarifier N'

  SlotState state;
  DivinationCard? card;
  bool isReversed;

  /// Pre-draw intention: the selected context chip and/or the typed/spoken
  /// note for THIS card, composed into one string.
  String? userContext;

  /// Present only for clarifiers requested from the Oracle or camera.
  String? oracleQuestion;

  /// True when this card was photographed from a real physical deck —
  /// it never left the digital ledger.
  bool fromPhysicalCard;

  DealtCardSlot({required this.index, required this.role})
      : state = SlotState.empty,
        card = null,
        isReversed = false,
        fromPhysicalCard = false;

  /// Manual deal: lands FACE DOWN; orientation is known but hidden.
  void placeCardFaceDown(DivinationCard c, bool reversed) {
    card = c;
    isReversed = reversed;
    state = SlotState.faceDown;
  }

  /// Scanned spread: materializes already FACE UP.
  void placeCardFaceUp(DivinationCard c, bool reversed) {
    card = c;
    isReversed = reversed;
    state = SlotState.faceUp;
  }

  void flipToFaceUp() => state = SlotState.faceUp;

  /// Composes the pre-draw intention from the tapped chip and/or the
  /// custom typed/spoken note, e.g. `Inner Doubt · "my own words"`.
  void setUserContext({String? chip, String? text}) {
    final parts = <String>[
      if (chip != null && chip.isNotEmpty) chip,
      if (text != null && text.isNotEmpty) '"$text"',
    ];
    userContext = parts.isEmpty ? null : parts.join(' · ');
  }

  void clear() {
    card = null;
    isReversed = false;
    state = SlotState.empty;
    userContext = null;
    oracleQuestion = null;
    fromPhysicalCard = false;
  }
}

