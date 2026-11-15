import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/tarot_deck_data.dart';
import '../core/models/dealt_card_slot.dart';
import '../core/models/spread_type.dart';
import '../core/models/tarot_card_model.dart';

/// Single source of truth for the Digital Table AND the Camera handoff.
/// Pure domain logic — the UI only reads state and calls these methods.
class SpreadController extends ChangeNotifier {
  SpreadController({Random? random}) : _rng = random ?? Random.secure() {
    _resetDeck();
    _resetSlots();
    shuffleDeck();
  }

  final Random _rng;

  late List<int> _cardIds; // shuffled order of tarotDeck ids
  late List<bool> _isReversed; // parallel orientation flags → 156 states
  int _topIndex = 0; // next card to deal

  SpreadType _spreadType = SpreadType.three;
  SpreadType get spreadType => _spreadType;

  late List<DealtCardSlot> _slots;
  List<DealtCardSlot> get slots => List.unmodifiable(_slots);

  int get remaining => tarotDeck.length - _topIndex;

  bool get allDealt => _slots.every((s) => s.state != SlotState.empty);
  bool get allFaceUp =>
      _slots.isNotEmpty && _slots.every((s) => s.state == SlotState.faceUp);
  int get faceUpCount => _slots.where((s) => s.state == SlotState.faceUp).length;

  /// The next few cards on the stack — for the tactile deck fan display.
  List<(TarotCard, bool)> get deckTop {
    final n = min(4, remaining);
    return [
      for (var i = 0; i < n; i++)
        (tarotDeck[_cardIds[_topIndex + i]], _isReversed[_topIndex + i]),
    ];
  }

  int? get nextEmptySlotIndex {
    for (final s in _slots) {
      if (s.state == SlotState.empty) return s.index;
    }
    return null;
  }

  /// Current shuffled order of card ids (0..77). Exposed for tests.
  List<int> get deckOrder => List.unmodifiable(_cardIds);

  void _resetDeck() {
    _cardIds = List<int>.generate(tarotDeck.length, (i) => i);
    _isReversed = List<bool>.filled(tarotDeck.length, false);
    _topIndex = 0;
  }

  void _resetSlots() {
    _slots = List.generate(
      _spreadType.cardCount,
      (i) => DealtCardSlot(index: i, role: _spreadType.slotRoles[i]),
    );
  }

  /// Fisher–Yates shuffle with a cryptographically secure RNG; orientation is
  /// re-rolled per card so every one of the 156 states is reachable.
  void shuffleDeck() {
    for (var i = _cardIds.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmpId = _cardIds[i];
      _cardIds[i] = _cardIds[j];
      _cardIds[j] = tmpId;
      _isReversed[i] = _rng.nextBool();
    }
    _isReversed[0] = _rng.nextBool();
    _topIndex = 0;
    notifyListeners();
  }

  /// Picking a spread resets the table with a freshly shuffled deck.
  void setSpreadType(SpreadType type) {
    if (type == _spreadType) return;
    _spreadType = type;
    _resetSlots();
    shuffleDeck();
  }

  /// Deals the next card FACE DOWN into the first empty slot.
  /// Returns the slot index, or null when the spread is full.
  int? dealNextCard() {
    final idx = nextEmptySlotIndex;
    if (idx == null || _topIndex >= _cardIds.length) return null;
    final card = tarotDeck[_cardIds[_topIndex]];
    final reversed = _isReversed[_topIndex];
    _topIndex++;
    _slots[idx].placeCardFaceDown(card, reversed);
    notifyListeners();
    return idx;
  }

  void flipSlot(int index) {
    final slot = _slots[index];
    if (slot.state == SlotState.faceDown) {
      slot.flipToFaceUp();
      notifyListeners();
    }
  }

  /// Camera handoff: rebuilds the table with the exact scanned spread,
  /// every card materialized FACE UP with threads ready.
  void loadScannedSpreadFaceUp(List<(TarotCard, bool)> cards) {
    if (cards.isEmpty) return;
    _spreadType = spreadTypeForCount(cards.length);
    _slots = List.generate(cards.length, (i) {
      final slot = DealtCardSlot(index: i, role: _spreadType.slotRoles[i]);
      slot.placeCardFaceUp(cards[i].$1, cards[i].$2);
      return slot;
    });
    notifyListeners();
  }

  void resetTable() {
    _resetSlots();
    shuffleDeck();
  }

  /// Serialized completed spread for local history (100% local-first).
  Map<String, dynamic> buildHistoryEntry({
    required String synthesis,
    String? contextChip,
  }) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'spreadType': _spreadType.name,
      'contextChip': contextChip,
      'synthesis': synthesis,
      'cards': [
        for (final s in _slots)
          {'name': s.card!.name, 'isReversed': s.isReversed, 'role': s.role},
      ],
    };
  }
}
