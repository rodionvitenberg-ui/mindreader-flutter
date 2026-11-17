import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/spread_controller.dart';

/// SPRINT 1/2 — the multi-system engine: switching between TAROT,
/// LENORMAND and RUNES rebuilds the physical stack to the system's
/// canonical deck size, resets the table, and enforces the system's
/// orientation laws (Lenormand never reverses, symmetrical runes never
/// merkstave).
void main() {
  group('DivinationSystem switch', () {
    test('default is tarot with a full 78-card stack', () {
      final c = SpreadController(random: Random(1));
      expect(c.system, DivinationSystem.tarot);
      expect(c.totalCards, 78);
      expect(c.remaining, 78);
      expect(c.activeSystemCards.length, 78);
    });

    test('switch to LENORMAND rebuilds a full 36-card stack + slots', () {
      final c = SpreadController(random: Random(2));
      c.setSystem(DivinationSystem.lenormand);
      expect(c.system, DivinationSystem.lenormand);
      expect(c.totalCards, 36);
      expect(c.remaining, 36);
      expect(c.activeSystemCards.length, 36);
      // Default 3-card Lenormand Line spread.
      expect(c.spreadCardCount, 3);
      expect(c.spreadLabel, '3 · Lenormand Line');
      expect(c.slots.length, 3);
      expect(c.slots.every((s) => s.state == SlotState.empty), isTrue);
    });

    test('switch to RUNES rebuilds a full 24-stone stack + slots', () {
      final c = SpreadController(random: Random(3));
      c.setSystem(DivinationSystem.runes);
      expect(c.totalCards, 24);
      expect(c.remaining, 24);
      expect(c.activeSystemCards.length, 24);
      expect(c.spreadLabel, '3 · The Three Norns');
      expect(c.spreadSlotRoles, [
        'Urd — What Was',
        'Verdandi — What Is',
        'Skuld — What Becomes',
      ]);
    });

    test('switching back to tarot restores the 78-card ledger', () {
      final c = SpreadController(random: Random(4));
      c.setSystem(DivinationSystem.runes);
      c.setSystem(DivinationSystem.tarot);
      expect(c.totalCards, 78);
      expect(c.remaining, 78);
      expect(c.system, DivinationSystem.tarot);
    });

    test('switching systems resets dealt cards', () {
      final c = SpreadController(random: Random(5));
      c.dealNextCard();
      expect(c.dealtCount, 1);
      c.setSystem(DivinationSystem.lenormand);
      expect(c.dealtCount, 0);
      expect(c.remaining, 36);
    });

    test('tarot spread setters refuse on non-tarot systems', () {
      final c = SpreadController(random: Random(6));
      c.setSystem(DivinationSystem.runes);
      c.setSpreadType(SpreadType.seven); // ignored
      expect(c.spreadCardCount, 3);
      expect(c.spreadType, SpreadType.three);
      c.setLenormandSpread(LenormandSpread.nine); // ignored
      expect(c.spreadCardCount, 3);
    });
  });

  group('orientation laws per system', () {
    test('lenormand deals are ALWAYS upright', () {
      final c = SpreadController(random: Random(7));
      c.setSystem(DivinationSystem.lenormand);
      for (var i = 0; i < 3; i++) {
        c.dealNextCard();
      }
      expect(c.slots.every((s) => !s.isReversed), isTrue);
      // And the union reports no reversal meaning for lenormand.
      expect(c.slots.every((s) => s.card!.reversed == null), isTrue);
      expect(c.slots.every((s) => !s.card!.supportsReversal), isTrue);
    });

    test('symmetrical runes never land merkstave', () {
      final c = SpreadController(random: Random(8));
      c.setSystem(DivinationSystem.runes);
      // Cast all 24 stones one by one across resets; every dealt Gebo / Isa
      // / Hagalaz must be upright.
      for (var round = 0; round < 6; round++) {
        for (var i = 0; i < 3; i++) {
          c.dealNextCard();
        }
        for (final s in c.slots) {
          if (s.card!.reversed == null) {
            expect(s.isReversed, isFalse,
                reason: '${s.card!.name} is symmetrical and must stay upright');
          }
        }
        c.resetTable();
      }
      // The 8 symmetrical runes exist in the dataset.
      final all = c.activeSystemCards
          .where((x) => !x.supportsReversal)
          .map((x) => x.name)
          .toSet();
      expect(all.length, 8);
    });

    test('tarot still lands reversed normally', () {
      final c = SpreadController(random: Random(9));
      var anyReversed = false;
      for (var round = 0; round < 10; round++) {
        for (var i = 0; i < 3; i++) {
          c.dealNextCard();
        }
        anyReversed |= c.slots.any((s) => s.isReversed);
        c.resetTable();
      }
      expect(anyReversed, isTrue);
    });
  });

  group('per-system spreads', () {
    test('lenormand 9-card portrait box configures 9 slots', () {
      final c = SpreadController(random: Random(10));
      c.setSystem(DivinationSystem.lenormand);
      c.setLenormandSpread(LenormandSpread.nine);
      expect(c.spreadCardCount, 9);
      expect(c.slots.length, 9);
      expect(c.slots[4].role, 'The Querent');
      expect(c.spreadLabel, '9 · 3×3 Portrait Box');
    });

    test('rune 7-stone Heimdall bridge configures 7 slots', () {
      final c = SpreadController(random: Random(11));
      c.setSystem(DivinationSystem.runes);
      c.setRuneCast(RuneCast.seven);
      expect(c.spreadCardCount, 7);
      expect(c.slots.length, 7);
      expect(c.slots[3].role, 'The Toll');
      expect(c.spreadLabel, '7 · Heimdall’s Bridge');
    });

    test('lenormand 5-cross and 1-daily-sign counts', () {
      final c = SpreadController(random: Random(12));
      c.setSystem(DivinationSystem.lenormand);
      c.setLenormandSpread(LenormandSpread.five);
      expect(c.spreadCardCount, 5);
      expect(c.baseCardLimit, 5);
      c.setLenormandSpread(LenormandSpread.one);
      expect(c.spreadCardCount, 1);
      expect(c.spreadLabel, '1 · Daily Sign');
    });
  });

  group('session restore across systems', () {
    test('restoreSpread rebuilds a lenormand table', () {
      final c = SpreadController(random: Random(13));
      c.setSystem(DivinationSystem.lenormand);
      c.dealNextCard();
      final dealt = c.slots[0].card!;
      c.restoreSpread(
        system: DivinationSystem.lenormand,
        lenormandSpread: LenormandSpread.three,
        cards: [
          (
            cardId: dealt.id,
            reversed: false,
            role: 'Past',
            userContext: null,
          ),
        ],
        sessionNotes: const [],
      );
      expect(c.system, DivinationSystem.lenormand);
      expect(c.totalCards, 36);
      expect(c.slots[0].card!.id, dealt.id);
      expect(c.slots[0].isReversed, isFalse);
      expect(c.slots[0].state, SlotState.faceUp);
    });

    test('restoreSpread rebuilds a rune cast with merkstave', () {
      final c = SpreadController(random: Random(14));
      c.restoreSpread(
        system: DivinationSystem.runes,
        runeCast: RuneCast.three,
        cards: [
          (
            cardId: 0, // Fehu — reversible
            reversed: true,
            role: 'Urd — What Was',
            userContext: null,
          ),
        ],
        sessionNotes: const [],
      );
      expect(c.system, DivinationSystem.runes);
      expect(c.slots[0].card!.name, 'Fehu');
      expect(c.slots[0].isReversed, isTrue);
      expect(c.slots[0].card!.reversed, isNotNull);
    });
  });

  group('history entry carries the system', () {
    test('buildHistoryEntry tags the active system + spreads', () {
      final c = SpreadController(random: Random(15));
      c.setSystem(DivinationSystem.runes);
      c.setRuneCast(RuneCast.five);
      c.dealNextCard();
      final entry = c.buildHistoryEntry(synthesis: 'test');
      expect(entry['system'], 'runes');
      expect(entry['runeCast'], 'five');
      expect(entry['lenormandSpread'], 'three');
    });
  });
}
