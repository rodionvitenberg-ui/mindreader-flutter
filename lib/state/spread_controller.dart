import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/tarot_deck_data.dart';
import '../core/models/dealt_card_slot.dart';
import '../core/models/spread_type.dart';
import '../core/models/tarot_card_model.dart';

/// Single source of truth for the Digital Table AND the Camera handoff.
/// Pure domain logic — the UI only reads state and calls these methods.
class SpreadController extends ChangeNotifier {
  SpreadController({Random? random, int totalCards = 78})
      : _rng = random ?? Random.secure(),
        _deckSize = totalCards.clamp(1, tarotDeck.length) {
    _resetDeck();
    _resetSlots();
    shuffleDeck();
  }

  final Random _rng;
  final int _deckSize; // physical stack size (default 78 = full tarot deck)

  /// Hard ceiling: no reading may ever hold more than 10 cards on the
  /// table (base spread + clarifiers). Beyond it the deck refuses any
  /// further draw while the Oracle AI Chat stays fully open.
  static const maxTableCards = 10;

  /// Subtle haptic/visual prompt shown when the reader swipes a locked
  /// deck: the base spread is complete and no clarifier question is armed.
  static const dealLockedPrompt =
      'Flip all cards face-up and synthesize in Chat before drawing '
      'a clarifier.';

  /// The hard ceiling prompt once 10 cards lie on the table.
  static const maxTableCardsPrompt =
      'Maximum of 10 cards reached for this reading.';

  late List<int> _cardIds; // shuffled order of tarotDeck ids
  late List<bool> _isReversed; // parallel orientation flags → 156 states
  int _topIndex = 0; // next card to deal

  SpreadType _spreadType = SpreadType.three;
  SpreadType get spreadType => _spreadType;

  /// How the cards on the table were produced. The camera handoff flips
  /// this to [TableSourceMode.physicalCameraSync]; spread switches and
  /// table resets return to the digital deck.
  TableSourceMode _sourceMode = TableSourceMode.digitalDeck;
  TableSourceMode get sourceMode => _sourceMode;

  /// Number of slots in the ORIGINAL spread template (clarifier slots are
  /// appended on top of this count).
  int get initialSpreadCardCount => _spreadType.cardCount;

  /// The authentic canonical slot count of the active spread (1/3/4/7) —
  /// the deck locks for further dealing as soon as this many cards lie on
  /// the table.
  int get baseCardLimit => _spreadType.cardCount;

  /// How many cards this reading may hold right now:
  /// * base spread filling → the canonical [baseCardLimit];
  /// * a clarifier question armed → exactly dealtCount + 1 (ONE unlocked
  ///   card), clamped to [maxTableCards];
  /// * hard ceiling → [maxTableCards], never less.
  int get allowedCardsLimit {
    if (dealtCount >= maxTableCards) return maxTableCards;
    return min(
      maxTableCards,
      _pendingClarifierQuestion == null
          ? baseCardLimit
          : dealtCount + 1,
    );
  }

  /// True when the deck refuses further draws: the base spread is complete
  /// and no clarifier question is armed, or the 10-card ceiling is reached.
  bool get isDealLocked => dealtCount >= allowedCardsLimit;

  late List<DealtCardSlot> _slots;
  List<DealtCardSlot> get slots => List.unmodifiable(_slots);

  /// Every slot of the initial spread template holds a FACE-UP card — the
  /// gate for the ceremonial `SYNTHESIZE READING` action.
  bool get initialSpreadAllFaceUp {
    final base = _slots.take(_spreadType.cardCount).toList();
    return base.isNotEmpty &&
        base.every((s) => s.state == SlotState.faceUp);
  }

  /// Configured physical stack size (78 by default).
  int get totalCards => _deckSize;

  /// Cards still lying in the physical stack. Extracted cards are removed
  /// from the list entirely (`dealCardAt`), so the live length is the
  /// source of truth.
  int get remaining => _cardIds.length - _topIndex;

  bool get allDealt => _slots.every((s) => s.state != SlotState.empty);
  bool get allFaceUp =>
      _slots.isNotEmpty && _slots.every((s) => s.state == SlotState.faceUp);
  int get faceUpCount => _slots.where((s) => s.state == SlotState.faceUp).length;

  /// Cards currently lying on the table (any slot that holds a card).
  int get dealtCount => _slots.where((s) => s.card != null).length;

  /// Ledger invariant: physical stack + dealt cards == the full deck.
  /// MUST always equal [totalCards] — resetting re-inserts every dealt
  /// card back into the stack instead of losing it.
  int get ledgerTotal => remaining + dealtCount;

  /// The next few cards on the stack — for the tactile deck fan display.
  List<(TarotCard, bool)> get deckTop {
    final n = min(4, remaining);
    return [
      for (var i = 0; i < n; i++)
        (tarotDeck[_cardIds[_topIndex + i]], _isReversed[_topIndex + i]),
    ];
  }

  /// The full physical stack still lying on the table (top of the deck is
  /// the FIRST entry). Drives the 78-layer 3D thickness and the live badge.
  List<(TarotCard, bool)> get remainingDeck {
    return [
      for (var i = _topIndex; i < _cardIds.length; i++)
        (tarotDeck[_cardIds[i]], _isReversed[i]),
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
    // Growable: `dealCardAt` physically removes extracted cards from the
    // middle of the stack (pick ANY exposed layer).
    _cardIds =
        List<int>.generate(_deckSize, (i) => i, growable: true);
    _isReversed = List<bool>.filled(_deckSize, false, growable: true);
    _topIndex = 0;
  }

  void _resetSlots() {
    _slots = List.generate(
      _spreadType.cardCount,
      (i) => DealtCardSlot(index: i, role: _spreadType.slotRoles[i]),
    );
    _clarifierCount = 0;
    _pendingClarifierQuestion = null;
    _sourceMode = TableSourceMode.digitalDeck;
    _sessionContextNotes.clear();
    _pendingChip = null;
    _pendingNote = null;
  }

  /// Fisher–Yates shuffle with a cryptographically secure RNG; orientation is
  /// re-rolled per card so every one of the 156 states is reachable.
  /// Resets depletion — used by spread switching and initial setup.
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

  /// One riffle/weave pass: cryptographically permutes ONLY the cards still
  /// lying in the stack ([remaining] cards) without touching already dealt
  /// cards or the depletion counter — called on every shuffle weave tick.
  void weaveShuffleRemaining({int swaps = 1}) {
    final count = _cardIds.length - _topIndex;
    if (count < 2) return;
    for (var s = 0; s < swaps; s++) {
      final a = _topIndex + _rng.nextInt(count);
      final b = _topIndex + _rng.nextInt(count);
      final tmpId = _cardIds[a];
      _cardIds[a] = _cardIds[b];
      _cardIds[b] = tmpId;
      final tmpRev = _isReversed[a];
      _isReversed[a] = _isReversed[b];
      _isReversed[b] = tmpRev;
    }
    notifyListeners();
  }

  /// Picking a spread resets the table with a freshly shuffled FULL deck:
  /// every dealt card is re-inserted into the 78-card physical stack, so
  /// `remaining + dealtCount` always equals [totalCards] — no card is ever
  /// lost from the ledger.
  void setSpreadType(SpreadType type) {
    if (type == _spreadType) return;
    _spreadType = type;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  /// Deals the next card FACE DOWN into the first empty slot.
  /// Returns the slot index, or null when the spread is full.
  int? dealNextCard() => dealCardAt(0);

  /// Extracts the card at [depthFromTop] (0 = top card, 1 = the card under
  /// it, ...) from the shuffled physical stack and deals it FACE DOWN into
  /// the first empty slot. Returns the slot index, or null when the spread
  /// is full or the depth is out of range.
  int? dealCardAt(int depthFromTop) {
    final idx = nextEmptySlotIndex;
    if (idx == null) return null;
    final pos = _topIndex + depthFromTop;
    if (depthFromTop < 0 || pos >= _cardIds.length) return null;
    final card = tarotDeck[_cardIds[pos]];
    final reversed = _isReversed[pos];
    _cardIds.removeAt(pos);
    _isReversed.removeAt(pos);
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

  /// Stores the pre-draw intention (chip and/or typed/spoken note) on the
  /// slot that just received card [index].
  void setSlotUserContext(int index, {String? chip, String? text}) {
    if (index < 0 || index >= _slots.length) return;
    final slot = _slots[index];
    if (slot.userContext == null) {
      slot.setUserContext(chip: chip, text: text);
      notifyListeners();
    }
  }

  /// Camera-sync helper: attaches the context to the first FACE-UP slot
  /// that has no intention yet. Returns false when every card is tagged.
  bool attachContextToNextUntagged({String? chip, String? text}) {
    for (final s in _slots) {
      if (s.card != null && s.userContext == null) {
        s.setUserContext(chip: chip, text: text);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  // ---- locked clarifier loop (+1 Card, hard 10-card ceiling) ------------

  int _clarifierCount = 0;

  /// Arms the deck for EXACTLY ONE +1 Clarifier Card with [question] (an
  /// AI-suggested or the reader's own follow-up). Returns false when the
  /// base spread is incomplete, the question is blank, or the hard
  /// 10-card ceiling is reached.
  bool armClarifierQuestion(String question) {
    if (question.trim().isEmpty) return false;
    if (dealtCount >= maxTableCards) return false;
    if (dealtCount < baseCardLimit) return false;
    _pendingClarifierQuestion = question;
    notifyListeners();
    return true;
  }

  /// Deals the next card; when the initial spread is already full this
  /// consumes an armed clarifier question and appends Clarifier N+1
  /// instead of refusing. Refuses (null) while the deck is locked.
  int? dealNextCardOrClarifier() => dealCardAtOrClarifier(0);

  /// The single legal digital-deal gate (tactile grab AND overview tap):
  /// * base slots fill freely up to the canonical limit;
  /// * beyond it a card may only be drawn while a clarifier question is
  ///   armed — exactly ONE, then the deck locks again;
  /// * at [maxTableCards] the deck refuses permanently.
  int? dealCardAtOrClarifier(int depthFromTop) {
    if (depthFromTop < 0 || depthFromTop >= remaining) return null;
    if (dealtCount >= maxTableCards) return null;
    final direct = dealCardAt(depthFromTop);
    if (direct != null) return direct;
    final question = _pendingClarifierQuestion;
    if (question == null) return null; // deck locked: no question armed
    final idx = _appendClarifierSlot(question);
    _pendingClarifierQuestion = null; // ONE card, then the deck locks again
    dealCardAt(depthFromTop);
    notifyListeners();
    return idx;
  }

  int _appendClarifierSlot(String question) {
    _clarifierCount++;
    final slot = DealtCardSlot(
      index: _slots.length,
      role: 'Clarifier $_clarifierCount',
    );
    slot.setUserContext(text: question);
    _slots.add(slot);
    return slot.index;
  }

  // ---- phygital camera-to-table sync ------------------------------------

  String? _pendingClarifierQuestion;

  /// The armed clarifier question (AI-suggested or the reader's own) —
  /// drives the unlocked +1 card AND the camera handoff. Null while the
  /// deck is locked or no follow-up is requested.
  String? get pendingClarifierQuestion => _pendingClarifierQuestion;

  /// True while the camera is expected to photograph ONE physical clarifier
  /// card that extends the current spread.
  bool get clarifierScanRequested => _pendingClarifierQuestion != null;

  /// Arms the clarifier camera scan with the follow-up question and marks
  /// the session as a physical camera sync. Refuses beyond the hard
  /// 10-card ceiling.
  void requestClarifierScan(String question) {
    if (dealtCount >= maxTableCards) return;
    if (question.trim().isEmpty) return;
    _pendingClarifierQuestion = question;
    _sourceMode = TableSourceMode.physicalCameraSync;
    notifyListeners();
  }

  /// The camera recognized the photographed physical clarifier: append it
  /// FACE UP as Card N+1. The digital 78-card ledger is untouched — a real
  /// card never decrements [remaining]. Returns the new slot index, or
  /// null when nothing is armed or the 10-card ceiling is reached.
  int? completeClarifierScan(TarotCard card, bool reversed) {
    final question = _pendingClarifierQuestion;
    if (question == null) return null;
    if (dealtCount >= maxTableCards) return null;
    _pendingClarifierQuestion = null;
    final idx = _appendClarifierSlot(question);
    final slot = _slots[idx];
    slot.fromPhysicalCard = true;
    slot.placeCardFaceUp(card, reversed);
    notifyListeners();
    return idx;
  }

  void cancelClarifierScan() {
    if (_pendingClarifierQuestion == null) return;
    _pendingClarifierQuestion = null;
    notifyListeners();
  }

  /// Camera handoff: rebuilds the table with the exact scanned spread,
  /// every card materialized FACE UP with threads ready. The session
  /// switches to [TableSourceMode.physicalCameraSync].
  void loadScannedSpreadFaceUp(List<(TarotCard, bool)> cards) {
    if (cards.isEmpty) return;
    _spreadType = spreadTypeForCount(cards.length);
    _clarifierCount = 0;
    _pendingClarifierQuestion = null;
    _sourceMode = TableSourceMode.physicalCameraSync;
    _sessionContextNotes.clear();
    _pendingChip = null;
    _pendingNote = null;
    _slots = List.generate(cards.length, (i) {
      final slot = DealtCardSlot(index: i, role: _spreadType.slotRoles[i]);
      slot.fromPhysicalCard = true;
      slot.placeCardFaceUp(cards[i].$1, cards[i].$2);
      return slot;
    });
    notifyListeners();
  }

  /// Clears the table AND physically returns every dealt card into the
  /// 78-card stack (fresh `_resetDeck` + full shuffle), so the live counter
  /// jumps back up to [totalCards] — the dealt cards are never lost.
  void resetTable() {
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  // ---- Gemini input capsule → session context notes (the ether) -------

  /// Every thought the reader sent into the ether for the CURRENT spread
  /// (context chips and/or typed/spoken notes). Woven into the synthesis
  /// lens and persisted with the session.
  final List<String> _sessionContextNotes = [];
  List<String> get sessionContextNotes => List.unmodifiable(_sessionContextNotes);

  void addSessionContextNote(String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    _sessionContextNotes.add(trimmed);
    notifyListeners();
  }

  /// Pending context queued by the input capsule — attaches to the NEXT
  /// dealt card (pre-draw intention).
  String? _pendingChip;
  String? _pendingNote;
  bool get hasPendingContext => _pendingChip != null || _pendingNote != null;

  void queueContext({String? chip, String? note}) {
    _pendingChip = chip;
    _pendingNote = note;
    notifyListeners();
  }

  void clearPendingContext() {
    if (_pendingChip == null && _pendingNote == null) return;
    _pendingChip = null;
    _pendingNote = null;
    notifyListeners();
  }

  /// Stores the pending context into the freshly dealt slot [slotIndex]
  /// and clears the queue for the next card. Returns false when nothing
  /// was queued.
  bool consumePendingContext(int slotIndex) {
    final chip = _pendingChip;
    final note = _pendingNote;
    if (chip == null && note == null) return false;
    if (slotIndex >= 0 && slotIndex < _slots.length) {
      _slots[slotIndex].setUserContext(chip: chip, text: note);
    }
    _pendingChip = null;
    _pendingNote = null;
    notifyListeners();
    return true;
  }

  /// 1-tap session restore (Pane 2): rebuilds the table with the exact
  /// saved cards, orientations, roles and intentions — all FACE UP with
  /// threads ready. The physical stack refreshes to a full shuffled 78:
  /// restored cards are a snapshot (camera-sync semantics) that never
  /// touches the digital ledger.
  void restoreSpread({
    required SpreadType type,
    required List<({int cardId, bool reversed, String role, String? userContext})> cards,
    required List<String> sessionNotes,
  }) {
    _spreadType = type;
    _clarifierCount =
        cards.where((c) => c.role.startsWith('Clarifier')).length;
    _pendingClarifierQuestion = null;
    _pendingChip = null;
    _pendingNote = null;
    _sourceMode = TableSourceMode.physicalCameraSync;
    _slots = List.generate(cards.length, (i) {
      final slot = DealtCardSlot(index: i, role: cards[i].role);
      slot.fromPhysicalCard = true;
      slot.userContext = cards[i].userContext;
      final card = _cardById(cards[i].cardId);
      if (card != null) {
        slot.placeCardFaceUp(card, cards[i].reversed);
      }
      return slot;
    });
    _sessionContextNotes
      ..clear()
      ..addAll(sessionNotes);
    _resetDeck();
    shuffleDeck();
  }

  TarotCard? _cardById(int id) {
    for (final c in tarotDeck) {
      if (c.id == id) return c;
    }
    return null;
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
