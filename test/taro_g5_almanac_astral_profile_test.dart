import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/data/zodiac_almanac_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/natal_chart.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/almanac/card_detail_sheet.dart';
import 'package:mindreader/features/almanac/zodiac_detail_sheet.dart';
import 'package:mindreader/features/astral/widgets/astral_gradient_button.dart';
import 'package:mindreader/features/astral/widgets/astral_house_selector.dart';
import 'package:mindreader/features/astral/widgets/astral_pro_paywall_sheet.dart';
import 'package:mindreader/features/astral/widgets/birth_data_form_sheet.dart';
import 'package:mindreader/features/profile/profile_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/astral_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/session_history_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';

void main() {
  group('G5 components: TaroGlassSnackbar & TaroGlassEmptyState', () {
    testWidgets('showTaroGlassSnackbar shows toast and triggers action', (
      tester,
    ) async {
      var actionTapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTaroGlassSnackbar(
                    context,
                    message: 'Backup imported cleanly.',
                    tone: TaroGlassSnackbarTone.success,
                    actionLabel: 'Undo',
                    onAction: () => actionTapped++,
                  ),
                  child: const Text('NOTIFY'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('NOTIFY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TaroGlassToast), findsOneWidget);
      expect(find.text('Backup imported cleanly.'), findsOneWidget);
      await tester.tap(find.text('UNDO'));
      await tester.pump();
      expect(actionTapped, 1);
    });

    testWidgets('TaroGlassEmptyState renders framed panel and primary action', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTaroTheme(),
          home: Scaffold(
            body: TaroGlassLayer(
              mode: TaroGlassMode.simple,
              child: TaroGlassEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'NO CHARTS',
                subtitle: 'Add birth details to compute your wheel.',
                actionLabel: 'Add Profile',
                framed: true,
                onAction: () => tapped++,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TaroGlassPanel), findsOneWidget);
      expect(find.byType(TaroGlassButton), findsOneWidget);
      await tester.tap(find.text('Add Profile'));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('G5 Almanac, Astral & Profile migration', () {
    testWidgets('Almanac CardDetailSheet & ZodiacDetailSheet use TaroGlassSheet + Panel', (
      tester,
    ) async {
      final decks = DeckPackController();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: decks,
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => CardDetailSheet.show(
                        context,
                        TarotDivinationCard(tarotDeck.first),
                      ),
                      child: const Text('CARD'),
                    ),
                    ElevatedButton(
                      onPressed: () => ZodiacDetailSheet.show(
                        context,
                        zodiacAlmanac.first,
                        onOpenHoroscope: (_) {},
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
      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.byType(TaroGlassPanel), findsOneWidget);
      expect(find.byType(TaroGlassSegmentedControl<bool>), findsOneWidget);
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('ZODIAC'));
      await tester.pumpAndSettle();
      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.byType(TaroGlassPanel), findsOneWidget);
      expect(find.byType(TaroGlassButton), findsOneWidget);
    });

    testWidgets('AstralGradientButton, AstralHouseSelector, BirthDataFormSheet & Paywall use Tarot Tree', (
      tester,
    ) async {
      final astral = AstralController();
      final settings = AppSettingsController();
      final history = SessionHistoryController();
      final profile = UserProfileController(history: history, astral: astral);
      var house = HouseSystem.placidus;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: astral),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: profile),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TaroGlassLayer(
                  mode: TaroGlassMode.simple,
                  child: Column(
                    children: [
                      AstralHouseSelector(
                        value: house,
                        onChanged: (v) => house = v,
                      ),
                      AstralGradientButton(
                        label: 'OPEN FORM',
                        onTap: () => BirthDataFormSheet.show(context),
                      ),
                      AstralGradientButton(
                        label: 'OPEN PAYWALL',
                        onTap: () => AstralProPaywallSheet.show(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TaroGlassSegmentedControl<HouseSystem>), findsOneWidget);
      expect(find.byType(TaroGlassButton), findsNWidgets(2));

      await tester.tap(find.text('OPEN FORM'));
      await tester.pumpAndSettle();
      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.byType(TaroGlassInput), findsNWidgets(2));
      expect(find.byType(TaroGlassToggle), findsOneWidget);
      Navigator.of(tester.element(find.byType(BirthDataFormSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN PAYWALL'));
      await tester.pumpAndSettle();
      expect(find.byType(TaroGlassSheet), findsOneWidget);
      expect(find.byType(TaroGlassPanel), findsOneWidget);
      expect(find.text('UNLOCK PRO'), findsOneWidget);
    });

    testWidgets('ProfileScreen mounts TaroDuskBackground, TaroGlassPanel cards and TaroGlassButtons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MindreaderApp());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('profile-avatar-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(TaroDuskBackground),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(TaroGlassPanel),
        ),
        findsNWidgets(5),
      );
      expect(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(TaroGlassButton),
        ),
        findsAtLeastNWidgets(3),
      );
    });
  });
}
