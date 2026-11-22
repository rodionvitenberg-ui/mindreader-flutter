import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/rune_pack.dart';
import 'package:mindreader/core/models/store_models.dart';
import 'package:mindreader/core/models/tarot_deck_pack.dart';
import 'package:mindreader/core/services/deck_package_installer.dart';
import 'package:mindreader/core/services/pack_asset_store.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _zipFiles(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackAssetStore.setForTesting(InMemoryPackAssetStore());
  });

  test('verifies and installs a Tarot store package and registers it in DeckPackController', () async {
    final fakeBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
    final digest = _sha(fakeBytes);
    final manifest = {
      'schemaVersion': 1,
      'deckId': 'deck-soimoi',
      'system': 'tarot',
      'version': '1.0.0',
      'minAppVersion': '0.0.0',
      'incomplete': true,
      'cover': {'path': 'cover.webp', 'sha256': digest},
      'back': {'path': 'back.jpg', 'sha256': digest},
      'previews': <Object>[],
      'cards': {
        'tarot:0': {'path': 'cards/00.jpg', 'sha256': digest},
        'tarot:17': {'path': 'cards/17.jpg', 'sha256': digest},
      },
      'style': {'backStyle': 'cyber', 'isIllustrated': true},
    };
    final zip = _zipFiles({
      'cover.webp': fakeBytes,
      'back.jpg': fakeBytes,
      'cards/00.jpg': fakeBytes,
      'cards/17.jpg': fakeBytes,
      'deck_manifest.json': utf8.encode(jsonEncode(manifest)),
    });

    final product = StoreProduct(
      id: 'deck-soimoi',
      slug: 'soimoi',
      title: 'SOMOI Tarot',
      tagline: 'Japanese style',
      description: 'Test',
      system: DivinationSystem.tarot,
      itemType: 'tarot_deck',
      badge: 'FEATURED',
      featured: true,
      sortOrder: 1,
      visualConfig: const {},
      artist: 'Mike Koz',
      publisher: 'koz.tv',
      license: 'CC BY 4.0',
      attribution: '',
      free: false,
      priceMinor: 499,
      currency: 'USD',
      owned: true,
    );
    final dl = StoreDownloadInfo(
      version: '1.0.0',
      minAppVersion: '0.0.0',
      incomplete: true,
      cardCount: 2,
      sizeBytes: zip.length,
      sha256: _sha(zip),
      url: 'https://example.test/pkg.zip',
    );

    final installer = DeckPackageInstaller();
    final record = await installer.verifyAndInstall(
      product: product,
      download: dl,
      zipBytes: zip,
    );
    expect(record.slug, 'soimoi');
    expect(record.cardPaths[17], 'cards/17.jpg');
    expect(record.backPath, 'back.jpg');

    final controller = DeckPackController();
    await controller.initialLoad;
    await controller.registerInstalledPack(record);

    expect(controller.isInstalled(DivinationSystem.tarot, 'soimoi'), isTrue);
    expect(
      controller.packsFor(DivinationSystem.tarot).any((p) => p.id == 'soimoi'),
      isTrue,
    );
    await controller.setActivePack('soimoi');
    expect(controller.activePack.id, 'soimoi');
    expect(controller.activePack.isStorePack, isTrue);
    expect(controller.activePack.backStyle, CardBackStyle.cyber);
    expect(
      PackAssetStore.instance.imageProviderFor(record.storeKey, 'cards/17.jpg'),
      isNotNull,
    );

    // Uninstall reverts active pack cleanly to built-in default.
    await controller.unregisterInstalledPack(DivinationSystem.tarot, 'soimoi');
    expect(controller.activePack.id, 'rider_waite');
  });

  test('installs volumetric 3D rune set with blank stone sprites + palette', () async {
    final stoneBytes = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);
    final digest = _sha(stoneBytes);
    final manifest = {
      'schemaVersion': 1,
      'deckId': 'deck-birch',
      'system': 'runes',
      'version': '1.0.0',
      'minAppVersion': '0.0.0',
      'incomplete': false,
      'cover': {'path': 'cover.webp', 'sha256': digest},
      'previews': <Object>[],
      'cards': <String, Object>{},
      'stones': [
        for (var i = 0; i < 5; i++)
          {'path': 'stones/stone_$i.webp', 'sha256': digest},
      ],
      'style': {
        'stoneBaseArgb': 0xFF3A2B22,
        'glyphArgb': 0xFFE0F2FE,
        'stoneVariantCount': 5,
      },
    };
    final zip = _zipFiles({
      'cover.webp': stoneBytes,
      for (var i = 0; i < 5; i++) 'stones/stone_$i.webp': stoneBytes,
      'deck_manifest.json': utf8.encode(jsonEncode(manifest)),
    });
    final product = StoreProduct(
      id: 'deck-birch',
      slug: 'charred_birch',
      title: 'Charred Nordic Birch & Frost',
      tagline: 'Wooden runes',
      description: 'Free gift',
      system: DivinationSystem.runes,
      itemType: 'rune_set',
      badge: 'GIFT',
      featured: false,
      sortOrder: 10,
      visualConfig: const {},
      artist: 'Tarot Tree',
      publisher: 'Tarot Tree',
      license: 'Digital Edition',
      attribution: '',
      free: true,
      priceMinor: 0,
      currency: 'USD',
      owned: true,
    );
    final dl = StoreDownloadInfo(
      version: '1.0.0',
      minAppVersion: '0.0.0',
      incomplete: false,
      cardCount: 24,
      sizeBytes: zip.length,
      sha256: _sha(zip),
      url: 'https://example.test/birch.zip',
    );

    final record = await DeckPackageInstaller().verifyAndInstall(
      product: product,
      download: dl,
      zipBytes: zip,
    );
    final pack = record.toDeckPack() as RunePack;
    expect(pack.isStorePack, isTrue);
    expect(pack.stoneVariantCount, 5);
    expect(pack.stoneBaseArgb, 0xFF3A2B22);
    expect(pack.stoneBlankAsset(0), 'stones/stone_0.webp');
    expect(
      await PackAssetStore.instance.readBytes(pack.storeKey!, 'stones/stone_0.webp'),
      stoneBytes,
    );
  });

  test('rejects tampered SHA-256 and zip-slip paths', () async {
    final data = Uint8List.fromList([1, 2, 3]);
    final badZip = _zipFiles({'../escape.txt': data});
    final product = StoreProduct(
      id: 'd1',
      slug: 'bad',
      title: 'Bad',
      tagline: '',
      description: '',
      system: DivinationSystem.tarot,
      itemType: 'tarot_deck',
      badge: '',
      featured: false,
      sortOrder: 1,
      visualConfig: const {},
      artist: '',
      publisher: '',
      license: '',
      attribution: '',
      free: true,
      priceMinor: 0,
      currency: 'USD',
      owned: true,
    );
    await expectLater(
      DeckPackageInstaller().verifyAndInstall(
        product: product,
        download: StoreDownloadInfo(
          version: '1.0.0',
          minAppVersion: '0.0.0',
          incomplete: true,
          cardCount: 1,
          sizeBytes: badZip.length,
          sha256: '0' * 64,
          url: 'https://example.test/bad.zip',
        ),
        zipBytes: badZip,
      ),
      throwsA(isA<PackageInstallException>()),
    );
    await expectLater(
      DeckPackageInstaller().verifyAndInstall(
        product: product,
        download: StoreDownloadInfo(
          version: '1.0.0',
          minAppVersion: '0.0.0',
          incomplete: true,
          cardCount: 1,
          sizeBytes: badZip.length,
          sha256: _sha(badZip),
          url: 'https://example.test/bad.zip',
        ),
        zipBytes: badZip,
      ),
      throwsA(isA<PackageInstallException>()),
    );
  });
}
