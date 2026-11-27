import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/deck_packs_registry.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/almanac/deck_cover.dart';
import 'package:mindreader/features/digital_table/oracle_chat_pane.dart';
import 'package:mindreader/features/digital_table/widgets/oracle_card_rail.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/deck_pack_controller.dart';
import 'package:mindreader/state/oracle_session_controller.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/user_profile_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all 6 languages define daily ritual, weekday, lunar, and news keys', () {
    const keys = [
      'ritual.section.daily',
      'ritual.daysLabel',
      'ritual.weekday.1',
      'ritual.weekday.2',
      'ritual.weekday.3',
      'ritual.weekday.4',
      'ritual.weekday.5',
      'ritual.weekday.6',
      'ritual.weekday.7',
      'ritual.section.lunar',
      'ritual.lunar.subtitle',
      'ritual.lunar.newMoon',
      'ritual.lunar.fullMoon',
      'ritual.lunar.nextDate',
      'ritual.section.news',
      'ritual.news.toggle',
      'ritual.news.subtitle',
      'ritual.news.subscribed',
      'ritual.news.unsubscribed',
    ];

    for (final lang in AppLanguage.values) {
      for (final key in keys) {
        final value = AppStrings.t(lang, key, {'date': '01.12.2026'});
        expect(value, isNot(equals(key)), reason: '$lang missing $key');
        expect(value.trim(), isNotEmpty, reason: '$lang empty $key');
      }
    }
  });

  test('History NEW SPREAD button uses strictly one active language in all 6 locales', () {
    final cyrillic = RegExp(r'[А-Яа-яЁё]');
    for (final lang in AppLanguage.values) {
      final label = AppStrings.t(lang, 'ui.spread_history_pane.new_spread');
      expect(label, isNot(contains('·')), reason: '$lang still has bilingual separator');
      if (lang == AppLanguage.ru) {
        expect(cyrillic.hasMatch(label), isTrue);
      } else {
        expect(cyrillic.hasMatch(label), isFalse, reason: '$lang leaked Cyrillic: $label');
      }
    }
  });

  testWidgets('Almanac DeckCover keeps the top of The Star card inside banner bounds', (
    tester,
  ) async {
    final pack = deckPacksRegistry.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTaroTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: 150,
              child: DeckCover(pack: pack),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bannerRect = tester.getRect(find.byType(DeckCover));
    final starCard = find.byType(FittedBox);
    expect(starCard, findsOneWidget);
    final cardRect = tester.getRect(starCard);
    expect(cardRect.top, greaterThanOrEqualTo(bannerRect.top));
  });

  testWidgets(
    'Oracle chat uses matching backdrops, fits bottom pill without ellipsis, and hides card rail scrollbar',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final spread = SpreadController()..setSpreadType(SpreadType.three);
      spread.activateSpread();
      for (var i = 0; i < spread.spreadCardCount; i++) {
        spread.dealNextCard();
        spread.flipSlot(i);
      }
      final session = OracleSessionController();
      session.initial = const StructuredSynthesis(
        narrative: 'Clear insight over the forest backdrop.',
        elementalAlchemy: 'Air and water align.',
        verdict: 'Move deliberately.',
        followUp: 'What deserves your attention first?',
      );
      session.addOracleMessage('Follow-up guidance from the Oracle.');
      final capsule = TextEditingController();
      addTearDown(capsule.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: spread),
            ChangeNotifierProvider.value(value: session),
            ChangeNotifierProvider(create: (_) => OracleVoiceService()),
            ChangeNotifierProvider(create: (_) => DeckPackController()),
            ChangeNotifierProvider(create: (_) => AppSettingsController()),
            ChangeNotifierProvider(create: (_) => UserProfileController()),
          ],
          child: MaterialApp(
            theme: buildTaroTheme(),
            home: Scaffold(
              body: OracleChatPane(
                session: session,
                inConversation: true,
                showReadingCards: true,
                readingKey: 'test-reading',
                composer: null,
                capsuleText: capsule,
                onBackToTable: () {},
                onSynthesize: () {},
                onClarifierQuestion: (_) => true,
                onFocusInput: () {},
                onScanClarifier: () {},
                onResumeCamera: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Synthesis & Oracle responses share the exact _SuggestionCard backdrop.
      final expectedColor = TaroColors.surface.withValues(alpha: 0.82);
      final expectedBorder = Border.all(
        color: TaroColors.lavender.withValues(alpha: 0.36),
      );

      final synthBox = tester.widget<Container>(
        find.byKey(const ValueKey('oracle-synthesis-backdrop')),
      );
      final synthDec = synthBox.decoration! as BoxDecoration;
      expect(synthDec.color, expectedColor);
      expect(synthDec.borderRadius, BorderRadius.circular(16));
      expect(synthDec.border, expectedBorder);

      final responseBox = tester.widget<Container>(
        find.byKey(const ValueKey('oracle-response-backdrop')),
      );
      final responseDec = responseBox.decoration! as BoxDecoration;
      expect(responseDec.color, expectedColor);
      expect(responseDec.borderRadius, BorderRadius.circular(16));
      expect(responseDec.border, expectedBorder);

      // 2. Bottom left pill scales via FittedBox instead of ellipsizing.
      final leftChipText = find.text(
        AppStrings.g('ui.oracle_chat_pane.1_card_for_my_question'),
      );
      expect(leftChipText, findsOneWidget);
      expect(
        find.ancestor(of: leftChipText, matching: find.byType(FittedBox)),
        findsOneWidget,
      );

      // 3. Expanding the vertical card rail shows no Scrollbar while remaining scrollable.
      await tester.tap(find.byKey(const ValueKey('oracle-rail-toggle')));
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('oracle-card-rail'));
      expect(rail, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OracleMessageViewport),
          matching: find.byType(Scrollbar),
        ),
        findsNothing,
      );
      final scrollConfig = tester.widget<ScrollConfiguration>(
        find.ancestor(of: rail, matching: find.byType(ScrollConfiguration)).first,
      );
      expect(scrollConfig.behavior.buildScrollbar(
        tester.element(rail),
        const SizedBox(),
        ScrollableDetails.vertical(),
      ), isA<SizedBox>());
    },
  );

  test('SeerEyeIcon SVG asset is simplified to just eye outline and iris circle', () {
    final svg = File('assets/icons/seer_eye.svg').readAsStringSync();
    expect(svg, contains('<path'));
    expect(svg, contains('<circle'));
    expect(svg, isNot(contains('<line')));
  });
}
