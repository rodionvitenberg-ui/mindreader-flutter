import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/deck_packs_registry.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/tarot_deck_pack.dart';

void main() {
  test('registry ships exactly 8 selectable decks with unique ids', () {
    expect(deckPacksRegistry.length, 8);
    final ids = deckPacksRegistry.map((p) => p.id).toList();
    expect(ids.toSet().length, 8);
    expect(deckPackById('rider_waite')!.name, 'Rider-Waite');
    expect(deckPackById('unknown_id'), isNull);
  });

  test('every pack points into assets/decks/ and carries a license', () {
    for (final pack in deckPacksRegistry) {
      expect(pack.assetFolder, startsWith('assets/decks/'));
      expect(pack.assetFolder, endsWith('/'));
      expect(pack.license, isNotEmpty);
      expect(pack.name, isNotEmpty);
    }
  });

  test('asset candidates resolve id-based, padded and RWS naming', () {
    final rws = deckPackById('rider_waite')!;
    expect(rws.naming, CardNaming.rws);
    final fool = tarotDeck[0]; // The Fool, id 0
    final candidates = rws.cardAssetCandidates(fool);
    expect(candidates, contains('assets/decks/rider_waite/0.jpg'));
    expect(candidates, contains('assets/decks/rider_waite/00.jpg'));
    expect(candidates, contains('assets/decks/rider_waite/00_The_Fool.jpg'));

    final ace = tarotDeck[22]; // Ace of Wands, id 22
    final aceCandidates = rws.cardAssetCandidates(ace);
    expect(aceCandidates, contains('assets/decks/rider_waite/Wands01.jpg'));
    expect(
      aceCandidates,
      contains('assets/decks/rider_waite/22_Ace_of_Wands.jpg'),
    );
  });

  test('pro packs are flagged but remain selectable (no lock)', () {
    final pro = deckPacksRegistry.where((p) => p.isPro).toList();
    expect(pro, isNotEmpty);
    expect(pro.every((p) => p.isLocked), isFalse);
  });
}
