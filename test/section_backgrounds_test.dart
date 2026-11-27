import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/data/zodiac_almanac_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/almanac/card_detail_sheet.dart';
import 'package:mindreader/features/almanac/deck_shop_screen.dart';
import 'package:mindreader/features/almanac/zodiac_detail_sheet.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/backend_auth_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/store_controller.dart';
import 'package:provider/provider.dart';

void main() {
  TaroDuskBackground shellBackground(WidgetTester tester) =>
      tester.widget<TaroDuskBackground>(find.byType(TaroDuskBackground));

  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'assigns forest to Table & non-Zodiac Almanac, dusk to Zodiac, oak to Astral & Rituals',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();

      // Digital Table (default tab 1) and all its horizontal panes use forest.
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Swipe to Oracle Chat pane -> still forest.
      await tester.drag(find.byType(PageView).first, const Offset(-320, 0));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Swipe to Spread History pane -> still forest.
      await tester.drag(find.byType(PageView).first, const Offset(-320, 0));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Switch to Almanac tab (Tarot by default) -> forest.
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Almanac Lenormand -> forest.
      await tester.tap(find.byKey(const ValueKey('almanac-system-lenormand')));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Almanac Runes -> forest.
      await tester.tap(find.byKey(const ValueKey('almanac-system-runes')));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);

      // Almanac Zodiac -> no forest image (sky atlas keeps dusk backdrop).
      await tester.tap(find.byKey(const ValueKey('almanac-system-zodiac')));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, isNull);

      // Switch to Astral tab -> oak.
      await tester.tap(find.byType(AstralZodiacIcon));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.oak);

      // Switch to Rituals tab -> oak.
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.oak);

      // Returning to Almanac while Zodiac is still active keeps Zodiac dusk.
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, isNull);

      // Switching back to Tarot restores forest.
      await tester.tap(find.byKey(const ValueKey('almanac-system-tarot')));
      await pumpTransition(tester);
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);
    },
  );

  testWidgets(
    'Almanac sub-screens use forest for CardDetailSheet & DeckShopScreen, dusk for ZodiacDetailSheet',
    (tester) async {
      final packs = DeckPackController();
      final auth = BackendAuthController();
      final store = StoreController(auth: auth, deckPacks: packs);
      final settings = AppSettingsController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: packs),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => CardDetailSheet.show(
                        context,
                        TarotDivinationCard(tarotDeck.first),
                      ),
                      child: const Text('CARD'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const DeckShopScreen(
                            system: DivinationSystem.tarot,
                          ),
                        ),
                      ),
                      child: const Text('SHOP'),
                    ),
                    TextButton(
                      onPressed: () => ZodiacDetailSheet.show(
                        context,
                        zodiacAlmanac.first,
                      ),
                      child: const Text('ZODIAC'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('CARD'));
      await tester.pumpAndSettle();
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('SHOP'));
      await tester.pumpAndSettle();
      expect(shellBackground(tester).imageAsset, TaroBackgroundAssets.forest);
      Navigator.of(tester.element(find.byType(DeckShopScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('ZODIAC'));
      await tester.pumpAndSettle();
      expect(shellBackground(tester).imageAsset, isNull);
    },
  );
}
