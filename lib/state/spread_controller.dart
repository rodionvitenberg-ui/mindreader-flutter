import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/lenormand_data.dart';
import '../core/data/runes_data.dart';
import '../core/data/tarot_deck_data.dart';
import '../core/models/dealt_card_slot.dart';
import '../core/models/divination_card.dart';
import '../core/models/divination_system.dart';
import '../core/models/lenormand_spread.dart';
import '../core/models/rune_cast.dart';
import '../core/models/spread_type.dart';
import '../core/models/tarot_card_model.dart';
import '../core/services/local_storage_service.dart';

/// Single source of truth for the Digital Table AND the Camera handoff.
/// Pure domain logic — the UI only reads state and calls these methods.
/// Hosts all three divination systems (Tarot 78 / Lenormand 36 / Runes 24)
/// behind one unified [DivinationCard] interface.
class SpreadController extends ChangeNotifier {
  SpreadController({
    Random? random,
    int totalCards = 78,
    LocalStorageService? storage,
  })  : _rng = random ?? Random.secure(),
        _storage = storage ?? LocalStorageService(),
        _deckSize = totalCards.clamp(1, tarotDeck.length) {
    _resetDeck();
    _resetSlots();
    shuffleDeck();
    loadTablePreferences();
  }

  final Random _rng;

  final LocalStorageService _storage;

  /// Physical stack size of the ACTIVE system (78/36/24); a custom
  /// [totalCards] only ever shrinks the tarot stack (test/scan setup).
  late int _deckSize;

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

  late List<int> _cardIds; // shuffled order of the active system's cards
  late List<bool> _isReversed; // parallel orientation flags
  int _topIndex = 0; // next card to deal

  // ---- active divination system ------------------------------------------

  DivinationSystem _system = DivinationSystem.tarot;
  DivinationSystem get system => _system;

  /// The full ordered dataset of the active system, wrapped in the
  /// unified [DivinationCard] union.
  List<DivinationCard> get activeSystemCards => switch (_system) {
        DivinationSystem.tarot =>
          [for (final c in tarotDeck) TarotDivinationCard(c)],
        DivinationSystem.lenormand =>
          [for (final c in lenormandDeck) LenormandDivinationCard(c)],
        DivinationSystem.runes =>
          [for (final r in elderFuthark) RuneDivinationCard(r)],
      };

  // ---- spreads (one enum per system, one decision per place) --------------

  SpreadType _spreadType = SpreadType.three;
  SpreadType get spreadType => _spreadType;

  LenormandSpread _lenormandSpread = LenormandSpread.three;
  LenormandSpread get lenormandSpread => _lenormandSpread;

  RuneCast _runeCast = RuneCast.three;
  RuneCast get runeCast => _runeCast;

  /// Canonical slot count of the ACTIVE system's spread (1/3/4/7 tarot,
  /// 1/3/5/9 lenormand, 1/3/5/7 runes).
  int get spreadCardCount => switch (_system) {
        DivinationSystem.tarot => _spreadType.cardCount,
        DivinationSystem.lenormand => _lenormandSpread.cardCount,
        DivinationSystem.runes => _runeCast.cardCount,
      };

  /// Concise pill label, e.g. '3 · Triad Flow', '9 · 3×3 Portrait Box',
  /// '7 · Heimdall’s Bridge'.
  String get spreadLabel => switch (_system) {
        DivinationSystem.tarot => _spreadType.label,
        DivinationSystem.lenormand => _lenormandSpread.label,
        DivinationSystem.runes => _runeCast.label,
      };

  /// The role each slot plays in the reading, top to bottom.
  List<String> get spreadSlotRoles => switch (_system) {
        DivinationSystem.tarot => _spreadType.slotRoles,
        DivinationSystem.lenormand => _lenormandSpread.slotRoles,
        DivinationSystem.runes => _runeCast.slotRoles,
      };

  /// What the reading focuses on (used by the oracle synthesis).
  String get spreadFocusLine => switch (_system) {
        DivinationSystem.tarot => _spreadType.focusLine,
        DivinationSystem.lenormand => _lenormandSpread.focusLine,
        DivinationSystem.runes => _runeCast.focusLine,
      };

  /// Compact single-word role per slot (`1 · State`, `2 · Shadow`, ...) for
  /// the overview slot labels.
  List<String> get spreadSlotRoleShorts => switch (_system) {
        DivinationSystem.tarot => _spreadType.slotRoleShorts,
        DivinationSystem.lenormand => _lenormandSpread.slotRoleShorts,
        DivinationSystem.runes => _runeCast.slotRoleShorts,
      };

  // ---- two-step entry flow (Step 1 picker → Step 2 active table) ----------

  bool _isSpreadActive = false;

  /// True while the reader is on Step 2 (the Active Digital Table). False on
  /// Step 1 — the pre-table "Choose Spread" selection view, which is the
  /// DEFAULT entry state of the Table tab before a spread is started.
  bool get isSpreadActive => _isSpreadActive;

  /// Step 1 → Step 2: enters the Active Digital Table. Call AFTER the spread
  /// has been selected (setSpreadType / setLenormandSpread / setRuneCast) or
  /// after a camera handoff / session restore.
  void activateSpread() {
    if (_isSpreadActive) return;
    _isSpreadActive = true;
    notifyListeners();
  }

  /// Step 2 → Step 1: exits the Active Digital Table back to the spread
  /// selection view and clears the table so the next selection starts fresh.
  void exitSpread() {
    _isSpreadActive = false;
    resetTable(); // notifies via shuffleDeck()
  }

  // ---- table view mode (SPREAD VIEW default, persisted) -------------------

  bool _isSpreadOverview = true;

  /// True → SPREAD VIEW (full-table overview), false → FOCUS VIEW (tactile
  /// hero deck). Defaults to true; the reader's toggle choice is persisted.
  bool get isSpreadOverview => _isSpreadOverview;

  /// UI-first persistence: memory + notify synchronously, then write
  /// `SharedPreferences` in the background (widget tests never block).
  void setSpreadOverview(bool value) {
    if (_isSpreadOverview == value) return;
    _isSpreadOverview = value;
    notifyListeners();
    _storage
        .saveTableSpreadOverview(value)
        .then((_) {}, onError: (Object _) {});
  }

  /// Restores the persisted view mode. Non-blocking — the SPREAD VIEW default
  /// is already in memory, so the async read only corrects an earlier FOCUS
  /// choice and NEVER clobbers a choice the reader just made this session.
  Future<void> loadTablePreferences() async {
    try {
      final stored = await _storage.loadTableSpreadOverview();
      if (!stored && _isSpreadOverview) {
        _isSpreadOverview = false;
        notifyListeners();
      }
    } catch (_) {
      // Storage unavailable — keep the default SPREAD VIEW.
    }
  }

  /// How the cards on the table were produced. The camera handoff flips
  /// this to [TableSourceMode.physicalCameraSync]; spread switches and
  /// table resets return to the digital deck.
  TableSourceMode _sourceMode = TableSourceMode.digitalDeck;
  TableSourceMode get sourceMode => _sourceMode;

  /// Number of slots in the ORIGINAL spread template (clarifier slots are
  /// appended on top of this count).
  int get initialSpreadCardCount => spreadCardCount;

  /// The authentic canonical slot count of the active spread — the deck
  /// locks for further dealing as soon as this many cards lie on the table.
  int get baseCardLimit => spreadCardCount;

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
    final base = _slots.take(spreadCardCount).toList();
    return base.length == spreadCardCount &&
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
  List<DivinationCard> get deckTop {
    final n = min(4, remaining);
    return [
      for (var i = 0; i < n; i++)
        activeSystemCards[_cardIds[_topIndex + i]],
    ];
  }

  /// The full physical stack still lying on the table (top of the deck is
  /// the FIRST entry). Drives the layer thickness and the live badge.
  List<DivinationCard> get remainingDeck {
    return [
      for (var i = _topIndex; i < _cardIds.length; i++)
        activeSystemCards[_cardIds[i]],
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

  /// Parallel orientation flags of the cards still lying in the stack —
  /// exposed for tests (advisory until the deal resolves the orientation).
  List<bool> get remainingReversalFlags => List.unmodifiable(
        [for (var i = _topIndex; i < _cardIds.length; i++) _isReversed[i]],
      );

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
      spreadCardCount,
      (i) => DealtCardSlot(index: i, role: spreadSlotRoles[i]),
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
  /// every dealt card is re-inserted into the physical stack, so
  /// `remaining + dealtCount` always equals [totalCards] — no card is ever
  /// lost from the ledger.
  void setSpreadType(SpreadType type) {
    if (_system != DivinationSystem.tarot) return;
    if (type == _spreadType) return;
    _spreadType = type;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  void setLenormandSpread(LenormandSpread spread) {
    if (_system != DivinationSystem.lenormand) return;
    if (spread == _lenormandSpread) return;
    _lenormandSpread = spread;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  void setRuneCast(RuneCast cast) {
    if (_system != DivinationSystem.runes) return;
    if (cast == _runeCast) return;
    _runeCast = cast;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  /// Switches the active divination system (TAROT | LENORMAND | RUNES).
  /// Resets the table AND the physical stack to the new system's full
  /// canonical deck size. Camera-sync state does not survive the switch —
  /// a scanned physical spread is tarot by definition.
  void setSystem(DivinationSystem system) {
    if (system == _system) return;
    _system = system;
    _deckSize = switch (system) {
      DivinationSystem.tarot => tarotDeck.length,
      DivinationSystem.lenormand => lenormandDeck.length,
      DivinationSystem.runes => elderFuthark.length,
    };
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
  ///
  /// Orientation is authoritative HERE: Lenormand cards never reverse, and
  /// the 8 symmetrical runes always land upright — the parallel
  /// `_isReversed` flag is only advisory for those systems.
  int? dealCardAt(int depthFromTop) {
    final idx = nextEmptySlotIndex;
    if (idx == null) return null;
    final pos = _topIndex + depthFromTop;
    if (depthFromTop < 0 || pos >= _cardIds.length) return null;
    final card = activeSystemCards[_cardIds[pos]];
    var reversed = _isReversed[pos];
    if (_system == DivinationSystem.lenormand) reversed = false;
    if (_system == DivinationSystem.runes && !card.supportsReversal) {
      reversed = false;
    }
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

  /// Overwrites the personal note on slot [index] — the Card Inspector
  /// sheet auto-saves the reader's typed/spoken note into
  /// `slot.userContext` as they type (blank clears it).
  void updateSlotUserContext(int index, {String? text}) {
    if (index < 0 || index >= _slots.length) return;
    _slots[index].setUserContext(text: text);
    notifyListeners();
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
    slot.placeCardFaceUp(TarotDivinationCard(card), reversed);
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
  /// switches to [TableSourceMode.physicalCameraSync] and to the TAROT
  /// system — the phygital scanner photographs a physical tarot deck.
  void loadScannedSpreadFaceUp(List<(TarotCard, bool)> cards) {
    if (cards.isEmpty) return;
    _system = DivinationSystem.tarot;
    _spreadType = spreadTypeForCount(cards.length);
    _isSpreadActive = true; // land directly on the Active Digital Table
    _clarifierCount = 0;
    _pendingClarifierQuestion = null;
    _sourceMode = TableSourceMode.physicalCameraSync;
    _sessionContextNotes.clear();
    _pendingChip = null;
    _pendingNote = null;
    _slots = List.generate(cards.length, (i) {
      final slot = DealtCardSlot(index: i, role: _spreadType.slotRoles[i]);
      slot.fromPhysicalCard = true;
      slot.placeCardFaceUp(TarotDivinationCard(cards[i].$1), cards[i].$2);
      return slot;
    });
    _resetDeck();
    shuffleDeck();
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
  /// threads ready. The physical stack refreshes to a full shuffle of the
  /// saved system: restored cards are a snapshot (camera-sync semantics)
  /// that never touches the digital ledger.
  void restoreSpread({
    required DivinationSystem system,
    SpreadType? type,
    LenormandSpread? lenormandSpread,
    RuneCast? runeCast,
    required List<({int cardId, bool reversed, String role, String? userContext})> cards,
    required List<String> sessionNotes,
  }) {
    _system = system;
    _isSpreadActive = true; // restored sessions land on the Active Digital Table
    _spreadType = type ?? SpreadType.three;
    _lenormandSpread = lenormandSpread ?? LenormandSpread.three;
    _runeCast = runeCast ?? RuneCast.three;
    _deckSize = switch (system) {
      DivinationSystem.tarot => tarotDeck.length,
      DivinationSystem.lenormand => lenormandDeck.length,
      DivinationSystem.runes => elderFuthark.length,
    };
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

  DivinationCard? _cardById(int id) {
    for (final c in activeSystemCards) {
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
      'system': _system.name,
      'spreadType': _spreadType.name,
      'lenormandSpread': _lenormandSpread.name,
      'runeCast': _runeCast.name,
      'contextChip': contextChip,
      'synthesis': synthesis,
      'cards': [
        for (final s in _slots)
          if (s.card != null)
            {'name': s.card!.name, 'isReversed': s.isReversed, 'role': s.role},
      ],
    };
  }
}

