import '../core/services/reading_relationships.dart';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/data/guide_content.dart';
import '../core/data/lenormand_data.dart';
import '../core/data/runes_data.dart';
import '../core/data/tarot_deck_data.dart';
import '../core/l10n/app_strings.dart';
import '../core/models/custom_spread.dart';
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
/// True when [role] is a clarifier label in ANY supported language, so a
/// session restored after a language switch still recognises its clarifiers.
bool isClarifierRole(String role) => AppLanguage.values.any(
  (lang) => role.startsWith(AppStrings.t(lang, 'table.clarifierWord')),
);

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

  static const maxTableCards = 15;
  static const maxBaseSpreadCards = 12;

  String get dealLockMessage {
    if (isClarifierLimitReached) {
      return AppStrings.g('table.maxCardsReached', {'max': maxTableCards});
    }
    if (remaining == 0) return AppStrings.g('table.deckEmpty');
    if (clarifierScanRequested) {
      return AppStrings.g('table.finishScanFirst');
    }
    return AppStrings.g('table.flipAllFirst');
  }

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

  CustomSpreadConfig? _customSpread;
  CustomSpreadConfig? get customSpread => _customSpread;
  List<ReadingRelationship> get relationships => readingRelationships(
    system: system, type: spreadType, custom: customSpread, slots: slots,
  );
  bool get isCustomSpread => _customSpread != null;

  /// Canonical slot count of the ACTIVE spread (or custom spread count).
  int get spreadCardCount =>
      _customSpread?.cardCount ??
      switch (_system) {
        DivinationSystem.tarot => _spreadType.cardCount,
        DivinationSystem.lenormand => _lenormandSpread.cardCount,
        DivinationSystem.runes => _runeCast.cardCount,
      };

  /// Concise label, e.g. '3 · Three Cards', '9 · 3×3 Portrait Box',
  /// '7 · Heimdall’s Bridge', or '5 · Custom Spread'.
  String get spreadLabel =>
      _customSpread?.label ??
      switch (_system) {
        DivinationSystem.tarot => _spreadType.label,
        DivinationSystem.lenormand => _lenormandSpread.label,
        DivinationSystem.runes => _runeCast.label,
      };

  /// The role each slot plays in the reading, top to bottom.
  List<String> get spreadSlotRoles =>
      _customSpread?.slotRoles ??
      switch (_system) {
        DivinationSystem.tarot => _spreadType.slotRoles,
        DivinationSystem.lenormand => _lenormandSpread.slotRoles,
        DivinationSystem.runes => _runeCast.slotRoles,
      };

  /// What the reading focuses on (used by the oracle synthesis).
  String get spreadFocusLine =>
      _customSpread?.focusLine ??
      switch (_system) {
        DivinationSystem.tarot => _spreadType.focusLine,
        DivinationSystem.lenormand => _lenormandSpread.focusLine,
        DivinationSystem.runes => _runeCast.focusLine,
      };

  /// Compact single-word role per slot (`1 · State`, `2 · Shadow`, ...) for
  /// the overview slot labels.
  List<String> get spreadSlotRoleShorts =>
      _customSpread?.slotRoleShorts ??
      switch (_system) {
        DivinationSystem.tarot => _spreadType.slotRoleShorts,
        DivinationSystem.lenormand => _lenormandSpread.slotRoleShorts,
        DivinationSystem.runes => _runeCast.slotRoleShorts,
      };

  /// A concise "why this position matters" lesson, localized (G4). Null for
  /// custom spreads (the reader authored those questions) and out-of-range
  /// slots.
  String? slotLesson(int index, AppLanguage lang) {
    if (_customSpread != null) return null;
    return guideSlotLesson(
      system: _system,
      spreadKey: _spreadKey,
      slot: index,
      lang: lang,
    );
  }

  /// Why this spread exists and how it reads, localized (G4). Null for custom
  /// spreads.
  String? guidePurpose(AppLanguage lang) {
    if (_customSpread != null) return null;
    return guidePurposeLine(_system, _spreadKey)?.forLanguage(lang);
  }

  /// The active spread's stable, language-independent key (enum `name`, or
  /// `'custom'` for reader-authored spreads). Used by Guided Reading to
  /// remember learned lessons across language switches.
  String get spreadKey => _customSpread != null ? 'custom' : _spreadKey;

  /// The active preset spread's stable content key (enum `name`).
  String get _spreadKey => switch (_system) {
        DivinationSystem.tarot => _spreadType.name,
        DivinationSystem.lenormand => _lenormandSpread.name,
        DivinationSystem.runes => _runeCast.name,
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
  /// waits for all base cards to be revealed before allowing a further draw.
  int get baseCardLimit => spreadCardCount;

  /// How many clarifying cards have been drawn above the base spread.
  int get clarifierCount => _clarifierCount;

  int get maxCardsForCurrentSpread => maxTableCards;

  bool get isClarifierLimitReached => dealtCount >= maxTableCards;

  bool get _canAppendCard => initialSpreadAllFaceUp &&
      allFaceUp && !isClarifierLimitReached;

  bool get canDrawExtraCard =>
      _canAppendCard && remaining > 0 && !clarifierScanRequested;

  bool get isDealLocked => remaining == 0 ||
      isClarifierLimitReached ||
      (nextEmptySlotIndex == null && !canDrawExtraCard);

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
  bool get canSynthesize => _slots.length >= initialSpreadCardCount && allFaceUp;

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

  /// The advisory slot to deal into or reveal next. Never drives the deck — a
  /// recommendation only, so the reader may always act out of order. While
  /// dealing it is the first empty base slot; once every base slot holds a
  /// face-down card, the centre of a Three-card Tarot spread is recommended
  /// first (a card is read with its flanks), otherwise the first face-down
  /// slot.
  int? get recommendedSlot {
    final empty = nextEmptySlotIndex;
    if (empty != null && empty < spreadCardCount) return empty;
    final slots = _slots.take(spreadCardCount).toList();
    final centerFirst =
        !isCustomSpread &&
        _system == DivinationSystem.tarot &&
        _spreadType == SpreadType.three &&
        slots.length >= 3;
    if (centerFirst && slots[1].state == SlotState.faceDown) return 1;
    for (final slot in slots) {
      if (slot.state == SlotState.faceDown) return slot.index;
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

  // A revision identifies one reading across both views and distinguishes
  // a fresh deal from a change to the cards within the current reading.
  int _readingRevision = 0;
  int get readingRevision => _readingRevision;
  String _readingQuestion = '';
  String get readingQuestion => _readingQuestion;
  bool? _readingForSelf;
  bool? get readingForSelf => _readingForSelf;

  void setReadingQuestion(String question) {
    if (_readingQuestion == question) return;
    _readingQuestion = question;
    notifyListeners();
  }

  void setReadingForSelf(bool value) {
    if (_readingForSelf == value) return;
    _readingForSelf = value;
    notifyListeners();
  }

  void _startReading({String question = '', bool? forSelf}) {
    _readingRevision++;
    _readingQuestion = question;
    _readingForSelf = forSelf;
  }

  void _resetSlots() {
    _startReading();
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
    if (_isReversed.isNotEmpty) _isReversed[0] = _rng.nextBool();
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
    if (type == _spreadType && _customSpread == null) return;
    _customSpread = null;
    _spreadType = type;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  void setLenormandSpread(LenormandSpread spread) {
    if (_system != DivinationSystem.lenormand) return;
    if (spread == _lenormandSpread && _customSpread == null) return;
    _customSpread = null;
    _lenormandSpread = spread;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  void setRuneCast(RuneCast cast) {
    if (_system != DivinationSystem.runes) return;
    if (cast == _runeCast && _customSpread == null) return;
    _customSpread = null;
    _runeCast = cast;
    _resetSlots();
    _resetDeck();
    shuffleDeck();
  }

  /// Activates a user-defined custom spread (1..12 question-driven positions)
  /// on the active divination system, resetting the table and physical stack.
  void setCustomSpread(CustomSpreadConfig config) {
    final maxAllowed = min(maxBaseSpreadCards, _deckSize);
    _customSpread = CustomSpreadConfig.fromQuestions(
      questions: config.questions,
      name: config.name,
      compareNeighbors: config.compareNeighbors,
      maxCards: maxAllowed,
    );
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
    _customSpread = null;
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
    final index = nextEmptySlotIndex;
    if (index == null || isClarifierLimitReached ||
        depthFromTop < 0 || depthFromTop >= remaining) {
      return null;
    }
    _dealInto(_slots[index], depthFromTop);
    return index;
  }

  void _dealInto(DealtCardSlot slot, int depthFromTop, {bool reveal = false}) {
    final pos = _topIndex + depthFromTop;
    final card = activeSystemCards[_cardIds[pos]];
    var reversed = _isReversed[pos];
    if (_system == DivinationSystem.lenormand) reversed = false;
    if (_system == DivinationSystem.runes && !card.supportsReversal) {
      reversed = false;
    }
    _cardIds.removeAt(pos);
    _isReversed.removeAt(pos);
    if (reveal) {
      slot.placeCardFaceUp(card, reversed);
    } else {
      slot.placeCardFaceDown(card, reversed);
    }
    notifyListeners();
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

  // ---- Additional cards ----

  int _clarifierCount = 0;

  int? dealNextCardOrClarifier() => dealCardAtOrClarifier(0);

  /// Manual draws use the same deck order and leave the new card face down.
  int? dealCardAtOrClarifier(int depthFromTop) {
    if (depthFromTop < 0 || depthFromTop >= remaining) return null;
    final base = dealCardAt(depthFromTop);
    if (base != null) return base;
    if (!canDrawExtraCard) return null;
    final slot = _appendClarifierSlot();
    _dealInto(slot, depthFromTop);
    return slot.index;
  }

  /// The conversation draws and reveals the actual top card in one update.
  int? drawOracleClarifier(String question) {
    if (!canDrawExtraCard || question.trim().isEmpty) return null;
    final slot = _appendClarifierSlot(oracleQuestion: question.trim());
    _dealInto(slot, 0, reveal: true);
    return slot.index;
  }

  DealtCardSlot _appendClarifierSlot({String? oracleQuestion}) {
    final slot = DealtCardSlot(
      index: _slots.length,
      role: '${AppStrings.g('table.clarifierWord')} ${++_clarifierCount}',
    )..oracleQuestion = oracleQuestion;
    slot.setUserContext(text: oracleQuestion);
    _slots.add(slot);
    return slot;
  }

  // ---- phygital camera-to-table sync ------------------------------------

  String? _pendingClarifierQuestion;

  String? get pendingClarifierQuestion => _pendingClarifierQuestion;

  bool get clarifierScanRequested => _pendingClarifierQuestion != null;

  bool requestClarifierScan(String question) {
    if (!_canAppendCard || clarifierScanRequested || question.trim().isEmpty) {
      return false;
    }
    _pendingClarifierQuestion = question.trim();
    _sourceMode = TableSourceMode.physicalCameraSync;
    notifyListeners();
    return true;
  }

  /// Physical clarifiers extend the same spread without touching the deck.
  int? completeClarifierScan(TarotCard card, bool reversed) {
    final question = _pendingClarifierQuestion;
    if (question == null || !_canAppendCard) return null;
    _pendingClarifierQuestion = null;
    final slot = _appendClarifierSlot(oracleQuestion: question);
    slot.fromPhysicalCard = true;
    slot.placeCardFaceUp(TarotDivinationCard(card), reversed);
    notifyListeners();
    return slot.index;
  }

  void cancelClarifierScan() {
    if (_pendingClarifierQuestion == null) return;
    _pendingClarifierQuestion = null;
    notifyListeners();
  }

  /// Camera handoff (Phase 2): rebuilds the table with the exact scanned
  /// spread, every card FACE UP with threads ready. Generalized over all
  /// three systems; the chosen spread (or Freeform) supplies the slot roles.
  /// Extra cards are NEVER dropped — Freeform keeps every card (generic
  /// `Card N` roles beyond the template). The digital ledger is untouched
  /// (full reset + shuffle, never a fake `dealCardAt`).
  void loadScannedSpread({
    required DivinationSystem system,
    required List<DivinationCard> cards,
    required List<bool> reversed,
    SpreadType? spreadType,
    LenormandSpread? lenormandSpread,
    RuneCast? runeCast,
  }) {
    if (cards.isEmpty || cards.length > maxTableCards) return;
    _startReading();
    _customSpread = null;
    _system = system;
    _deckSize = switch (system) {
      DivinationSystem.tarot => tarotDeck.length,
      DivinationSystem.lenormand => lenormandDeck.length,
      DivinationSystem.runes => elderFuthark.length,
    };

    // Resolve slot roles: an explicit template wins; otherwise (Freeform)
    // fall back to the count-based default and pad generic roles so NO card
    // is ever dropped, even beyond the canonical template count.
    List<String> roles;
    if (spreadType != null) {
      _spreadType = spreadType;
      roles = spreadType.slotRoles;
    } else if (lenormandSpread != null) {
      _lenormandSpread = lenormandSpread;
      roles = lenormandSpread.slotRoles;
    } else if (runeCast != null) {
      _runeCast = runeCast;
      roles = runeCast.slotRoles;
    } else {
      roles = const [];
      switch (system) {
        case DivinationSystem.tarot:
          _spreadType = spreadTypeForCount(cards.length);
          roles = _spreadType.slotRoles;
          break;
        case DivinationSystem.lenormand:
          _lenormandSpread = lenormandSpreadForCount(cards.length);
          roles = _lenormandSpread.slotRoles;
          break;
        case DivinationSystem.runes:
          _runeCast = runeCastForCount(cards.length);
          roles = _runeCast.slotRoles;
          break;
      }
    }

    _isSpreadActive = true; // land directly on the Active Digital Table
    _clarifierCount = 0;
    _pendingClarifierQuestion = null;
    _sourceMode = TableSourceMode.physicalCameraSync;
    _sessionContextNotes.clear();
    _pendingChip = null;
    _pendingNote = null;
    _slots = List.generate(cards.length, (i) {
      final role = i < roles.length
          ? roles[i]
          : '${AppStrings.g('table.cardWord')} ${i + 1}';
      final slot = DealtCardSlot(index: i, role: role);
      slot.fromPhysicalCard = true;
      slot.placeCardFaceUp(cards[i], i < reversed.length ? reversed[i] : false);
      return slot;
    });
    _resetDeck();
    shuffleDeck();
    notifyListeners();
  }

  /// Legacy TAROT-only entry point (pre-Phase 2). Delegates to
  /// [loadScannedSpread] so existing callers/tests keep working.
  void loadScannedSpreadFaceUp(List<(TarotCard, bool)> cards) {
    loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: [for (final c in cards) TarotDivinationCard(c.$1)],
      reversed: [for (final c in cards) c.$2],
      spreadType: spreadTypeForCount(cards.length),
    );
  }

  /// Prepares the table for a Guided Physical Spread: resets to EMPTY slots
  /// for the ACTIVE spread (physical camera-sync source) so the coordinator
  /// binds cards one at a time as they are confirmed. The digital ledger is
  /// untouched.
  void startGuidedSpread() {
    _resetSlots();
    _sourceMode = TableSourceMode.physicalCameraSync;
    _resetDeck();
    shuffleDeck();
  }

  /// Binds ONE confirmed physical card into [slotIndex] FACE UP, marking the
  /// slot as physical. Returns false (no-op) when the index is out of range —
  /// the Guided FSM guarantees a valid index, so this is a defensive boundary
  /// check, not a control path.
  bool bindGuidedCard(int slotIndex, DivinationCard card, bool reversed) {
    if (slotIndex < 0 || slotIndex >= _slots.length) return false;
    final slot = _slots[slotIndex];
    slot.fromPhysicalCard = true;
    slot.placeCardFaceUp(card, reversed);
    notifyListeners();
    return true;
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

  /// Restore the exact reading and shuffle the remaining digital cards.
  /// Older callers without source information use physical snapshot semantics.
  void restoreSpread({
    required DivinationSystem system,
    SpreadType? type,
    LenormandSpread? lenormandSpread,
    RuneCast? runeCast,
    String? customSpread,
    List<String> customQuestions = const [],
    bool compareNeighbors = false,
    required List<({int cardId, bool reversed, String role, String? userContext})> cards,
    required List<String> sessionNotes,
    String readingQuestion = '',
    bool? readingForSelf,
    Map<int, String> oracleQuestions = const {},
    Set<int> faceDownCards = const {},
    Set<int>? physicalCards,
    TableSourceMode sourceMode = TableSourceMode.physicalCameraSync,
  }) {
    _startReading(question: readingQuestion, forSelf: readingForSelf);
    _system = system;
    _isSpreadActive = true; // restored sessions land on the Active Digital Table
    _spreadType = type ?? SpreadType.three;
    _lenormandSpread = lenormandSpread ?? LenormandSpread.three;
    _runeCast = runeCast ?? RuneCast.three;
    final baseCards = cards.where((c) => !isClarifierRole(c.role)).toList();
    final restoredQuestions = customQuestions.isNotEmpty
        ? customQuestions
        : [for (final c in baseCards) c.role];
    if (customSpread != null &&
        customSpread.trim().isNotEmpty &&
        restoredQuestions.isNotEmpty) {
      _customSpread = CustomSpreadConfig.fromQuestions(
        questions: restoredQuestions,
        name: customSpread,
        compareNeighbors: compareNeighbors,
      );
    } else {
      _customSpread = null;
    }
    _deckSize = switch (system) {
      DivinationSystem.tarot => tarotDeck.length,
      DivinationSystem.lenormand => lenormandDeck.length,
      DivinationSystem.runes => elderFuthark.length,
    };
    _clarifierCount =
        cards.where((c) => isClarifierRole(c.role)).length;
    _pendingClarifierQuestion = null;
    _pendingChip = null;
    _pendingNote = null;
    _sourceMode = sourceMode;
    _slots = List.generate(cards.length, (i) {
      final slot = DealtCardSlot(index: i, role: cards[i].role)
        ..fromPhysicalCard = physicalCards?.contains(i) ?? true
        ..userContext = cards[i].userContext
        ..oracleQuestion = oracleQuestions[i];
      final card = _cardById(cards[i].cardId);
      if (card != null) {
        if (faceDownCards.contains(i)) {
          slot.placeCardFaceDown(card, cards[i].reversed);
        } else {
          slot.placeCardFaceUp(card, cards[i].reversed);
        }
      }
      return slot;
    });
    _sessionContextNotes
      ..clear()
      ..addAll(sessionNotes);
    _resetDeck();
    for (final slot in _slots) {
      if (slot.fromPhysicalCard || slot.card == null) continue;
      final index = _cardIds.indexOf(slot.card!.id);
      if (index < 0) continue;
      _cardIds.removeAt(index);
      _isReversed.removeAt(index);
    }
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

