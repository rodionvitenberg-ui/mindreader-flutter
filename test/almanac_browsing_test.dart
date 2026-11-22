import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindreader/core/data/deck_packs_registry.dart';
import 'package:mindreader/core/data/rune_packs_registry.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/deck_promo_service.dart';
import 'package:mindreader/features/almanac/almanac_screen.dart';
import 'package:mindreader/features/almanac/deck_cover.dart';
import 'package:mindreader/features/almanac/deck_shop_screen.dart';
import 'package:mindreader/features/digital_table/widgets/deck_picker_sheet.dart';
import 'package:mindreader/features/digital_table/widgets/rune_stone_3d_widget.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/table_test_helpers.dart';

void main() {
  Finder byKey(String key) => find.byKey(ValueKey(key));
  final shopLink = find.text('Deck shop →');
  final selector = byKey('almanac-pack-pill');
  final filters = byKey('almanac-filters');
  final scroll = byKey('almanac-scroll');
  final banner = byKey('deck-banner');

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
  ]) {
    testWidgets('banner collapses and filters dock under the deck at $size', (
      tester,
    ) async {
      await open(tester, size);
      final viewport = tester.getRect(scroll);
      final deckBounds = tester.getRect(selector);
      final expanded = tester.getRect(banner);
      expect(expanded.top, closeTo(deckBounds.bottom, 1));
      expect(tester.getRect(filters).top, closeTo(expanded.bottom, 1));
      expect(viewport.bottom - tester.getRect(filters).bottom, greaterThan(88));
      expect(find.text('Deck shop →').hitTestable(), findsOneWidget);

      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.bottom - 24),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(shopLink.hitTestable(), findsNothing);
      expect(tester.getRect(selector), deckBounds);
      expect(tester.getRect(filters).top, closeTo(deckBounds.bottom, 1));
      expect(
        viewport.bottom - tester.getRect(filters).bottom,
        greaterThan(viewport.height / 2),
        reason: 'The catalogue should occupy most of the available screen.',
      );
      final ctrl = tester.widget<CustomScrollView>(scroll).controller!;
      ctrl.jumpTo(0);
      await tester.pump();
      expect(tester.getRect(banner), expanded);
      expect(shopLink.hitTestable(), findsOneWidget);
    });
  }

  testWidgets(
    'a one-card result can hide and restore the banner with its search and filters intact',
    (tester) async {
      await open(tester, const Size(360, 640));
      await tester.tap(byKey('element-filter-water'));
      await tester.enterText(byKey('almanac-search'), 'priestess');
      tester.testTextInput.hide();
      await tester.pump();
      final viewport = tester.getRect(scroll);
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.bottom - 20),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(shopLink.hitTestable(), findsNothing);
      expect(
        tester.widget<TextField>(byKey('almanac-search')).controller!.text,
        'priestess',
      );
      expect(find.text('THE HIGH PRIESTESS'), findsWidgets);
      final ctrl = tester.widget<CustomScrollView>(scroll).controller!;
      ctrl.jumpTo(0);
      await tester.pump();
      expect(shopLink.hitTestable(), findsOneWidget);
      await tester.enterText(byKey('almanac-search'), '');
      await tester.pump();
      expect(find.text('THE FOOL'), findsNothing);
      expect(find.text('THE HIGH PRIESTESS'), findsWidgets);
    },
  );

  testWidgets(
    'deck selector previews the face of The Star and omits the Cover setting',
    (tester) async {
      await open(tester, const Size(390, 844));
      await tester.tap(selector);
      await tester.pumpAndSettle();

      final sheet = find.byType(DeckPickerSheet);
      expect(sheet, findsOneWidget);

      // No user Cover picker remains in the Deck Selector.
      expect(find.text('Cover'), findsNothing);
      expect(find.text('Заставка'), findsNothing);
      expect(find.bySemanticsLabel('Cover 1'), findsNothing);

      // Every visible tarot preview in the carousel renders The Star face-up
      // in that deck's own previewPack, showing the face illustration (17.jpg).
      final previews = tester.widgetList<TarotCard3DWidget>(
        find.descendant(of: sheet, matching: find.byType(TarotCard3DWidget)),
      );
      expect(previews, isNotEmpty);
      for (final card in previews) {
        expect(card.card.id, 17); // XVII · The Star
        expect(card.card.name, 'The Star');
        expect(card.state, SlotState.faceUp);
        expect(card.previewPack, isNotNull);
      }
      final starImages = tester
          .widgetList<Image>(
            find.descendant(of: sheet, matching: find.byType(Image)),
          )
          .map((img) => img.image)
          .whereType<AssetImage>()
          .where((asset) => asset.assetName.endsWith('/17.jpg'));
      expect(starImages, isNotEmpty);
    },
  );

  testWidgets(
    'backend-managed promo artwork URLs load, cache, and bind to built-in and shop packs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/store/promos/');
        return http.Response(
          jsonEncode({
            'count': 3,
            'next': null,
            'previous': null,
            'results': [
              {
                'system': 'tarot',
                'packId': 'rider_waite',
                'title': 'Rider-Waite',
                'deckId': null,
                'url': '/api/v1/store/promos/tarot/rider_waite/image/?v=abc123',
                'sha256': 'abc123',
                'updatedAt': '2026-11-22T07:00:00Z',
              },
              {
                'system': 'runes',
                'packId': 'nordic_bone',
                'title': 'Nordic Carved Bone & Gold',
                'deckId': null,
                'url': '/api/v1/store/promos/runes/nordic_bone/image/?v=def456',
                'sha256': 'def456',
                'updatedAt': '2026-11-22T07:00:00Z',
              },
              {
                'system': 'tarot',
                'packId': 'celestial_shop',
                'title': 'Celestial Shop Deck',
                'deckId': '11111111-1111-1111-1111-111111111111',
                'url': '/api/v1/store/promos/tarot/celestial_shop/image/?v=999',
                'sha256': '999',
                'updatedAt': '2026-11-22T07:00:00Z',
              },
            ],
          }),
          200,
        );
      });
      final service = DeckPromoService(
        baseUrl: 'https://api.tarottree.test',
        client: client,
      );

      final ctrl = DeckPackController(promoService: service);
      await ctrl.initialLoad;
      await ctrl.refreshPromos();

      expect(
        ctrl.promoImageUrlFor(DivinationSystem.tarot, deckPacksRegistry.first),
        'https://api.tarottree.test/api/v1/store/promos/tarot/rider_waite/image/?v=abc123',
      );
      expect(
        ctrl.promoImageUrlFor(DivinationSystem.runes, runePacksRegistry[1]),
        'https://api.tarottree.test/api/v1/store/promos/runes/nordic_bone/image/?v=def456',
      );
      // Future digital shop decks resolve by system + packId as well.
      expect(
        ctrl.promoImageUrlForId(DivinationSystem.tarot, 'celestial_shop'),
        'https://api.tarottree.test/api/v1/store/promos/tarot/celestial_shop/image/?v=999',
      );

      // Cached promo URLs survive a fresh offline controller.
      final offline = DeckPackController(
        promoService: DeckPromoService(baseUrl: ''),
      );
      await offline.initialLoad;
      expect(
        offline.promoImageUrlFor(
          DivinationSystem.tarot,
          deckPacksRegistry.first,
        ),
        'https://api.tarottree.test/api/v1/store/promos/tarot/rider_waite/image/?v=abc123',
      );
    },
  );

  testWidgets(
    'selecting a rune set updates the banner, catalogue and table artwork',
    (tester) async {
      await open(tester, const Size(390, 844));
      await tester.tap(byKey('almanac-system-runes'));
      await tester.pump();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView).last, const Offset(-250, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NORDIC CARVED BONE & GOLD'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final cover = tester.widget<DeckCover>(
        find.descendant(of: banner, matching: find.byType(DeckCover)),
      );
      expect(cover.pack.id, 'nordic_bone');
      expect(find.text('NORDIC CARVED BONE & GOLD'), findsOneWidget);
      void expectNordicStones(Finder parent) {
        final paints = tester.widgetList<CustomPaint>(
          find.descendant(of: parent, matching: find.byType(CustomPaint)),
        );
        final ids = paints
            .map((p) => p.painter)
            .whereType<RuneStonePainter>()
            .map((p) => p.pack.id)
            .toSet();
        expect(ids, {'nordic_bone'});
      }

      expectNordicStones(find.byType(SliverGrid));
      await tester.tap(find.text('TABLE'));
      await tester.pump();
      await activateSpread(tester, 'Odin’s Rune');
      expectNordicStones(byKey('overview-deck'));
    },
  );

  testWidgets(
    'Lenormand and runes open the in-app shop; Zodiac opens the reference directly',
    (tester) async {
      await open(tester, const Size(360, 640));
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      MethodCall? external;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        external = call;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      for (final system in [
        DivinationSystem.lenormand,
        DivinationSystem.runes,
      ]) {
        await tester.tap(byKey('almanac-system-${system.name}'));
        await tester.pump();
        final controller = tester
            .element(find.byType(AlmanacScreen))
            .read<DeckPackController>();
        final pack = controller.activeFor(system);
        expect(find.text(pack.name.toUpperCase()), findsOneWidget);
        external = null;
        await tester.tap(shopLink);
        await tester.pumpAndSettle();
        expect(find.byType(DeckShopScreen), findsOneWidget);
        expect(external, isNull);
        await tester.tap(byKey('shop-${pack.id}'));
        await tester.pumpAndSettle();
        expect(
          external?.arguments['url'],
          deckShopDestination(system, pack.id).toString(),
        );
        expect(external?.arguments['useWebView'], false);
        expect(external?.arguments['useSafariVC'], false);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(shopLink.hitTestable(), findsOneWidget);
      }
      await tester.tap(byKey('almanac-system-zodiac'));
      await tester.pump();
      expect(banner, findsNothing);
      expect(selector, findsNothing);
      expect(byKey('zodiac-tile-aries').hitTestable(), findsOneWidget);
    },
  );

  test(
    'checkout preserves the website route and identifies the selected pack',
    () {
      final uri = deckShopDestination(
        DivinationSystem.runes,
        'nordic_bone',
        checkout: 'https://shop.example/checkout?lang=ru',
      );
      expect(uri.path, '/checkout');
      expect(uri.queryParameters, {
        'lang': 'ru',
        'system': 'runes',
        'deck': 'nordic_bone',
      });
    },
  );
}
