import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/backend_auth_service.dart';
import 'package:mindreader/core/services/pack_asset_store.dart';
import 'package:mindreader/core/services/store_api_service.dart';
import 'package:mindreader/features/almanac/deck_shop_screen.dart';
import 'package:mindreader/features/profile/widgets/profile_account_card.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/backend_auth_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/store_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _birchZipBytes() {
  final stone = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);
  final sha = sha256.convert(stone).toString();
  final manifest = {
    'schemaVersion': 1,
    'deckId': 'deck-birch',
    'system': 'runes',
    'version': '1.0.0',
    'minAppVersion': '0.0.0',
    'incomplete': false,
    'cover': {'path': 'cover.webp', 'sha256': sha},
    'previews': <Object>[],
    'cards': <String, Object>{},
    'stones': [
      for (var i = 0; i < 5; i++) {'path': 'stones/stone_$i.webp', 'sha256': sha},
    ],
  };
  final archive = Archive()
    ..addFile(ArchiveFile('cover.webp', stone.length, stone))
    ..addFile(ArchiveFile('deck_manifest.json', utf8.encode(jsonEncode(manifest)).length, utf8.encode(jsonEncode(manifest))));
  for (var i = 0; i < 5; i++) {
    archive.addFile(ArchiveFile('stones/stone_$i.webp', stone.length, stone));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackAssetStore.setForTesting(InMemoryPackAssetStore());
  });

  MockClient buildMockBackend({required Uint8List birchZip}) {
    final birchSha = sha256.convert(birchZip).toString();
    var ownsBirch = false;
    var verified = false;

    Map<String, dynamic> soimoiJson() => {
          'id': 'deck-soimoi',
          'slug': 'soimoi',
          'title': 'SOMOI Tarot',
          'tagline': 'Japanese-style deck',
          'description': '78 cards',
          'system': 'tarot',
          'itemType': 'tarot_deck',
          'badge': 'FEATURED',
          'featured': true,
          'sortOrder': 1,
          'visualConfig': {'isIllustrated': true},
          'artist': 'Mike Koz',
          'publisher': 'koz.tv',
          'license': 'CC BY 4.0',
          'attribution': '',
          'commercialRights': true,
          'free': false,
          'priceMinor': 499,
          'currency': 'USD',
          'published': true,
          'owned': false,
          'promoImageUrl': null,
          'coverUrl': null,
          'version': {
            'version': '1.0.0',
            'minAppVersion': '0.0.0',
            'incomplete': false,
            'cardCount': 78,
            'sizeBytes': 3800000,
            'sha256': 'a' * 64,
          },
        };

    Map<String, dynamic> birchJson() => {
          'id': 'deck-birch',
          'slug': 'charred_birch',
          'title': 'Charred Nordic Birch & Frost',
          'tagline': 'Wooden runes gift',
          'description': '24 runes',
          'system': 'runes',
          'itemType': 'rune_set',
          'badge': 'GIFT',
          'featured': false,
          'sortOrder': 10,
          'visualConfig': {'stoneBaseArgb': 0xFF3A2B22},
          'artist': 'Tarot Tree',
          'publisher': 'Tarot Tree',
          'license': 'Digital Edition',
          'attribution': '',
          'commercialRights': true,
          'free': true,
          'priceMinor': 0,
          'currency': 'USD',
          'published': true,
          'owned': ownsBirch,
          'promoImageUrl': null,
          'coverUrl': null,
          'version': {
            'version': '1.0.0',
            'minAppVersion': '0.0.0',
            'incomplete': false,
            'cardCount': 24,
            'sizeBytes': birchZip.length,
            'sha256': birchSha,
          },
        };

    return MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/auth/guest/') {
        return http.Response(
          jsonEncode({
            'id': 'guest-1',
            'verified': false,
            'email': null,
            'token': 'guest-tok',
            'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          }),
          201,
        );
      }
      if (path == '/api/v1/auth/register/') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        verified = true;
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'verified': true,
            'email': body['email'],
            'name': body['name'],
            'emailConfirmed': false,
            'token': 'verified-tok',
            'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          }),
          201,
        );
      }
      if (path == '/api/v1/auth/login/') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        verified = true;
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'verified': true,
            'email': body['email'],
            'name': 'Reader',
            'emailConfirmed': false,
            'token': 'verified-tok',
            'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          }),
          200,
        );
      }
      if (path == '/api/v1/auth/email/start/') {
        return http.Response(jsonEncode({'devCode': 'DEV12345'}), 202);
      }
      if (path == '/api/v1/auth/email/verify/') {
        verified = true;
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'verified': true,
            'email': 'reader@example.org',
            'name': 'Reader',
            'emailConfirmed': true,
            'token': 'verified-tok',
            'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          }),
          200,
        );
      }
      if (path == '/api/v1/auth/handoff/') {
        return http.Response(
          jsonEncode({
            'code': 'handoff-one-time-xyz',
            'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          }),
          201,
        );
      }
      if (path == '/api/v1/store/decks/') {
        return http.Response(
          jsonEncode({'count': 2, 'next': null, 'previous': null, 'results': [soimoiJson(), birchJson()]}),
          200,
        );
      }
      if (path == '/api/v1/store/library/') {
        return http.Response(
          jsonEncode({
            'count': ownsBirch ? 1 : 0,
            'next': null,
            'previous': null,
            'results': [if (ownsBirch) birchJson()],
          }),
          200,
        );
      }
      if (path == '/api/v1/store/decks/deck-birch/acquire-free/') {
        ownsBirch = true;
        return http.Response(jsonEncode({'owned': true}), 200);
      }
      if (path == '/api/v1/store/decks/deck-birch/download/') {
        return http.Response(
          jsonEncode({
            'version': '1.0.0',
            'minAppVersion': '0.0.0',
            'incomplete': false,
            'cardCount': 24,
            'sizeBytes': birchZip.length,
            'sha256': birchSha,
            'url': '/api/v1/store/decks/deck-birch/packages/1.0.0/',
          }),
          200,
        );
      }
      if (path == '/api/v1/store/decks/deck-birch/packages/1.0.0/') {
        return http.Response.bytes(birchZip, 200);
      }
      if (path == '/api/v1/auth/logout/') {
        verified = false;
        return http.Response('', 204);
      }
      return http.Response('{"detail":"Not found ($path)"}', verified ? 404 : 404);
    });
  }

  testWidgets(
    'Shop hides built-in decks, claims free wooden runes gift, keeps it in list with OWNED badge',
    (tester) async {
      final zip = _birchZipBytes();
      final client = buildMockBackend(birchZip: zip);
      final auth = BackendAuthController(
        service: BackendAuthService(baseUrl: 'https://api.example.test', client: client),
      );
      final decks = DeckPackController();
      final store = StoreController(
        auth: auth,
        deckPacks: decks,
        api: StoreApiService(baseUrl: 'https://api.example.test', client: client),
        promoShopBaseUrl: 'https://soshallitbe.cyou',
      );
      final settings = AppSettingsController();
      await Future.wait([auth.initialLoad, decks.initialLoad, store.initialLoad, settings.initialLoad]);

      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: decks),
            ChangeNotifierProvider.value(value: store),
          ],
          child: const MaterialApp(
            home: DeckShopScreen(system: DivinationSystem.tarot),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Store displays ONLY backend items — built-in decks must NEVER appear.
      expect(find.text('SOMOI Tarot'), findsOneWidget);
      expect(find.text('Charred Nordic Birch & Frost'), findsOneWidget);
      expect(find.text('Rider-Waite'), findsNothing);
      expect(find.text('Nordic Carved Bone & Gold'), findsNothing);

      // Initially wooden runes show price/gift CTA and NO owned badge.
      expect(find.byKey(const ValueKey('shop-buy-charred_birch')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-owned-badge-charred_birch')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('shop-buy-charred_birch')));
      await tester.pumpAndSettle();

      // Item stays in the shop, price & buy button disappear, OWNED badge appears!
      expect(find.text('Charred Nordic Birch & Frost'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-buy-charred_birch')), findsNothing);
      expect(find.byKey(const ValueKey('shop-price-charred_birch')), findsNothing);
      expect(find.byKey(const ValueKey('shop-owned-badge-charred_birch')), findsOneWidget);
      expect(decks.isInstalled(DivinationSystem.runes, 'charred_birch'), isTrue);
    },
  );

  testWidgets('ProfileAccountCard registers with password, offers optional email verify and builds handoff URL', (tester) async {
    final zip = _birchZipBytes();
    final client = buildMockBackend(birchZip: zip);
    final auth = BackendAuthController(
      service: BackendAuthService(baseUrl: 'https://api.example.test', client: client),
    );
    final decks = DeckPackController();
    final store = StoreController(
      auth: auth,
      deckPacks: decks,
      api: StoreApiService(baseUrl: 'https://api.example.test', client: client),
      promoShopBaseUrl: 'https://soshallitbe.cyou',
    );
    final settings = AppSettingsController();
    await Future.wait([auth.initialLoad, decks.initialLoad, store.initialLoad, settings.initialLoad]);
    await store.refresh();

    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: decks),
          ChangeNotifierProvider.value(value: store),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ProfileAccountCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-account-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-account-register')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-account-register')));
    await tester.pumpAndSettle();

    // Typo suggestion works and can be applied in one tap.
    await tester.enterText(find.byKey(const ValueKey('auth-email-input')), 'reader@gamil.com');
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-email-typo-fix')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email-notice')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('auth-name-input')), 'Reader');
    await tester.enterText(find.byKey(const ValueKey('auth-email-input')), 'reader@example.org');
    await tester.enterText(find.byKey(const ValueKey('auth-password-input')), 'secret1234');
    await tester.enterText(find.byKey(const ValueKey('auth-confirm-password-input')), 'secret1234');
    await tester.tap(find.byKey(const ValueKey('auth-register-submit')));
    await tester.pumpAndSettle();

    expect(auth.isVerified, isTrue);
    expect(auth.isEmailConfirmed, isFalse);
    expect(find.text('reader@example.org'), findsOneWidget);
    // Post-factum optional verification button is visible until confirmed.
    expect(find.byKey(const ValueKey('profile-verify-email')), findsOneWidget);

    // Verified account builds a handoff checkout URL pointing to promo website /shop/.
    final soimoi = store.allProducts.firstWhere((p) => p.slug == 'soimoi');
    final uri = await store.buildWebCheckoutUri(soimoi, returnUrl: 'https://app.soshallitbe.cyou');
    expect(uri.host, 'soshallitbe.cyou');
    expect(uri.path, '/shop/');
    expect(uri.queryParameters['deck'], 'soimoi');
    expect(uri.queryParameters['handoff'], 'handoff-one-time-xyz');
    expect(uri.queryParameters['return'], 'https://app.soshallitbe.cyou');
  });
}
