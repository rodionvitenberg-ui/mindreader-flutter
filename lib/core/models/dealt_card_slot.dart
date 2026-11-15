import 'tarot_card_model.dart';

/// Lifecycle of one slot on the vertical board.
enum SlotState { empty, faceDown, faceUp }

class DealtCardSlot {
  final int index;
  final String role; // from SpreadType.slotRoles

  SlotState state;
  TarotCard? card;
  bool isReversed;

  DealtCardSlot({required this.index, required this.role})
      : state = SlotState.empty,
        card = null,
        isReversed = false;

  /// Manual deal: lands FACE DOWN; orientation is known but hidden.
  void placeCardFaceDown(TarotCard c, bool reversed) {
    card = c;
    isReversed = reversed;
    state = SlotState.faceDown;
  }

  /// Scanned spread: materializes already FACE UP.
  void placeCardFaceUp(TarotCard c, bool reversed) {
    card = c;
    isReversed = reversed;
    state = SlotState.faceUp;
  }

  void flipToFaceUp() => state = SlotState.faceUp;

  void clear() {
    card = null;
    isReversed = false;
    state = SlotState.empty;
  }
}
