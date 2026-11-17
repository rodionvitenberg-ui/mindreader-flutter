import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/lenormand_data.dart';
import 'package:mindreader/core/data/lenormand_packs_registry.dart';
import 'package:mindreader/core/data/rune_packs_registry.dart';
import 'package:mindreader/core/data/runes_data.dart';
import 'package:mindreader/core/models/lenormand_card.dart';
import 'package:mindreader/core/models/rune_stone.dart';

/// SPRINT 1/2 — dataset integrity: the canonical 36-card Petit Lenormand
/// (9 per playing-card suit, Blue Owl insets) and the 24 Elder Futhark
/// runes (3 Aetts × 8, 8 symmetrical without merkstave).
void main() {
  group('Petit Lenormand dataset (36)', () {
    test('36 cards in canonical order 1..36, unique ids 0..35', () {
      expect(lenormandDeck.length, 36);
      expect([for (final c in lenormandDeck) c.number],
          [for (var i = 0; i < 36; i++) i + 1]);
      final ids = {for (final c in lenormandDeck) c.id};
      expect(ids.length, 36);
      expect(lenormandDeck.first.name, 'Rider');
      expect(lenormandDeck.last.name, 'Cross');
    });

    test('9 cards per playing-card suit with authentic insets', () {
      for (final suit in PlayingCardSuit.values) {
        final cards = lenormandDeck.where((c) => c.playingCard == suit);
        expect(cards.length, 9, reason: '${suit.label} must hold 9 cards');
      }
      final rider = lenormandDeck[0];
      expect(rider.inset, '9♥');
      expect(rider.playingCard, PlayingCardSuit.hearts);
      final cross = lenormandDeck[35];
      expect(cross.inset, '6♣');
      expect(lenormandDeck[2].inset, '10♠'); // Ship
      expect(lenormandDeck[1].inset, '6♦'); // Clover
    });

    test('every card carries keywords, meaning, combinations, timing', () {
      for (final c in lenormandDeck) {
        expect(c.keywords.length, greaterThanOrEqualTo(2));
        expect(c.meaning, isNotEmpty);
        expect(c.combinations.length, 3);
        expect(c.timing, isNotEmpty);
        expect(c.insetLabel, matches(r'^(A|J|Q|K|\d{1,2})[♥♦♣♠]$'));
      }
    });

    test('3 built-in packs are registered with asset folders', () {
      expect(lenormandPacksRegistry.length, 3);
      for (final p in lenormandPacksRegistry) {
        expect(p.assetFolder, startsWith('assets/lenormand/'));
        expect(p.cardAssetCandidates(1).first, '${p.assetFolder}01.jpg');
        expect(p.cardAssetCandidates(36).first, '${p.assetFolder}36.jpg');
      }
      expect(lenormandPackById('antique_petit'), isNotNull);
      expect(lenormandPackById('nope'), isNull);
    });
  });

  group('Elder Futhark dataset (24)', () {
    test('24 runes: 3 Aetts × 8, canonical order Fehu..Othala', () {
      expect(elderFuthark.length, 24);
      for (final aett in RuneAett.values) {
        expect(elderFuthark.where((r) => r.aett == aett).length, 8,
            reason: '${aett.title} must hold 8 runes');
      }
      expect(elderFuthark.first.name, 'Fehu');
      expect(elderFuthark.first.glyph, 'ᚠ');
      expect(elderFuthark.last.name, 'Othala');
      expect(elderFuthark.last.glyph, 'ᛟ');
    });

    test('the 8 symmetrical runes carry NO merkstave', () {
      final symmetric = elderFuthark.where((r) => r.merkstave == null);
      expect(symmetric.map((r) => r.name).toSet(), {
        'Gebo', 'Hagalaz', 'Isa', 'Jera',
        'Eihwaz', 'Sowilo', 'Ingwaz', 'Dagaz',
      });
      // Perthro is reversible in this tradition.
      expect(
        elderFuthark.firstWhere((r) => r.name == 'Perthro').merkstave,
        isNotNull,
      );
    });

    test('glyphs are unique, every rune has lore + keywords', () {
      expect(elderFuthark.map((r) => r.glyph).toSet().length, 24);
      for (final r in elderFuthark) {
        expect(r.keywords.length, 3);
        expect(r.upright, isNotEmpty);
        expect(r.lore, isNotEmpty);
        expect(r.phonetic, isNotEmpty);
      }
    });

    test('3 built-in stone sets are registered', () {
      expect(runePacksRegistry.length, 3);
      for (final p in runePacksRegistry) {
        expect(p.assetFolder, startsWith('assets/runes/'));
      }
      expect(runePackById('obsidian_lavender'), isNotNull);
      expect(runePackById('nordic_bone'), isNotNull);
      expect(runePackById('blood_jasper'), isNotNull);
      expect(runePackById('nope'), isNull);
    });
  });
}
