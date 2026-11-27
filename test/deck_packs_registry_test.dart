import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/deck_packs_registry.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/tarot_deck_pack.dart';

void main() {
  test('registry ships exactly 4 built-in decks with unique ids (soimoi lives in the store)', () {
    expect(deckPacksRegistry.length, 4);
    final ids = deckPacksRegistry.map((p) => p.id).toList();
    expect(ids.toSet().length, 4);
    expect(deckPackById('rider_waite')!.name, 'Rider-Waite');
    expect(deckPackById('oswald_wirth'), isNull);
    expect(deckPackById('etteilla'), isNull);
    expect(deckPackById('visconti_sforza'), isNull);
    expect(deckPackById('soimoi'), isNull);
    expect(deckPackById('unknown_id'), isNull);
  });

  test('the 3 built-in real open-source decks are registered with their license', () {
    const realIds = [
      'rider_waite',
      'marseille',
      'vieville',
    ];
    for (final id in realIds) {
      final pack = deckPackById(id);
      expect(pack, isNotNull, reason: id);
      expect(pack!.license, isNotEmpty);
    }
  });

  test('every pack points into assets/decks/ and carries a license', () {
    for (final pack in deckPacksRegistry) {
      expect(pack.assetFolder, startsWith('assets/decks/'));
      expect(pack.assetFolder, endsWith('/'));
      expect(pack.license, isNotEmpty);
      expect(pack.name, isNotEmpty);
    }
  });

  test('asset candidates resolve id-based and padded naming', () {
    final rws = deckPackById('rider_waite')!;
    expect(rws.naming, CardNaming.indexed);
    final fool = tarotDeck[0]; // The Fool, id 0
    final candidates = rws.cardAssetCandidates(fool);
    expect(candidates, contains('assets/decks/rider_waite/0.jpg'));
    expect(candidates, contains('assets/decks/rider_waite/00.jpg'));

    final ace = tarotDeck[22]; // Ace of Wands, id 22
    final aceCandidates = rws.cardAssetCandidates(ace);
    expect(aceCandidates, contains('assets/decks/rider_waite/22.jpg'));
  });

  test('real scan backs are wired where the sources ship a Cover', () {
    expect(deckPackById('rider_waite')!.backAsset, 'back');
    expect(deckPackById('vieville')!.backAsset, 'back');
    expect(deckPackById('marseille')!.backAsset, isNull);
  });

  test('all 7 built-in packs are free and selectable (no locked/pro tiers)', () {
    expect(deckPacksRegistry.every((p) => !p.isLocked), isTrue);
    expect(deckPacksRegistry.every((p) => !p.isPro), isTrue);
    expect(deckPackById('obsidian_minimal'), isNotNull);
  });
}
