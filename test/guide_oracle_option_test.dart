import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/data/guide_copy.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/dealt_card_slot.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/core/services/oracle_synthesis_service.dart';
import 'package:mindreader/core/services/reading_relationships.dart';
import 'package:mindreader/features/digital_table/digital_table_screen.dart';
import 'package:mindreader/main.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

import 'helpers/table_test_helpers.dart';

/// G4 — the Oracle option of Guided Reading: a deep explanation happens ONLY
/// on the reader's explicit request, and it still answers offline from the
/// authored cards and a Socratic question.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TarotCard cardWith(Element element) =>
      tarotDeck.firstWhere((c) => c.element == element);

  DealtCardSlot faceUp(int index, TarotCard card, String role) {
    final slot = DealtCardSlot(index: index, role: role);
    slot.placeCardFaceUp(TarotDivinationCard(card), false);
    return slot;
  }

  group('explainGuideMoment answers offline', () {
    test('names the cards, their roles and the focus card question', () async {
      final service = OracleSynthesisService();
      final fire = cardWith(Element.fire);
      final water = cardWith(Element.water);
      final text = await service.explainGuideMoment(
        moment: 'Spread complete',
        focus: 'Read the whole story.',
        slots: [faceUp(0, fire, 'State'), faceUp(1, water, 'Shadow')],
        focusSlot: 1,
      );

      expect(service.hasPrimary || service.hasCloud, isFalse);
      expect(text, contains('State'));
      expect(text, contains(fire.name));
      expect(text, contains(water.name));
      expect(text, contains(water.socratic));
      expect(text, contains('Sit with this question'));
      // Prompt-speak never leaks into a reader-facing answer.
      expect(text, isNot(contains('mindreader.quest oracle')));
    });

    test('an empty table answers honestly instead of inventing cards', () async {
      final text = await OracleSynthesisService().explainGuideMoment(
        moment: 'Deal 1 of 3',
        focus: 'Read the whole story.',
        slots: const [],
      );
      expect(text, AppStrings.t(AppLanguage.en, 'guide.oracle.empty'));
    });

    test('an explicit link is read as one thread', () async {
      final slots = [
        faceUp(0, cardWith(Element.fire), 'State'),
        faceUp(1, cardWith(Element.water), 'Shadow'),
      ];
      final link = readingRelationships(
        system: DivinationSystem.tarot,
        type: SpreadType.three,
        custom: null,
        slots: slots,
      ).first;
      final text = await OracleSynthesisService().explainGuideMoment(
        moment: 'Elemental link',
        focus: 'Read the whole story.',
        slots: slots,
        link: link,
      );
      expect(text, contains(link.explanation));
    });

    test('the answer follows the reader language', () async {
      AppStrings.setCurrent(AppLanguage.ru);
      addTearDown(() => AppStrings.setCurrent(AppLanguage.en));
      final text = await OracleSynthesisService().explainGuideMoment(
        moment: 'Расклад собран',
        focus: 'Прочтите историю целиком.',
        slots: [faceUp(0, cardWith(Element.fire), 'Суть')],
      );
      expect(RegExp(r'[А-Яа-я]').hasMatch(text), isTrue);
    });
  });

  test('the Oracle option copy exists in every language', () {
    for (final lang in AppLanguage.values) {
      expect(GuideCopy.askOracle(lang).trim(), isNotEmpty, reason: '$lang');
      expect(GuideCopy.oracleLabel(lang).trim(), isNotEmpty, reason: '$lang');
      expect(GuideCopy.oracleThinking(lang).trim(), isNotEmpty, reason: '$lang');
    }
  });

  Future<void> openGuideSheet(
    WidgetTester tester, {
    AppLanguage? language,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await activateSpread(tester, 'Three Cards');
    final ctx = tester.element(find.byType(DigitalTableScreen));
    final ctrl = ctx.read<SpreadController>();
    final settings = ctx.read<AppSettingsController>();
    if (language != null) settings.setLanguage(language);
    await settings.setAid(ReadingAid.guide, true);
    await settings.setGuideDetail(GuideDetail.thorough);
    ctrl.loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: [
        for (final element in [Element.fire, Element.water, Element.air])
          TarotDivinationCard(
            tarotDeck.firstWhere((c) => c.element == element),
          ),
      ],
      reversed: const [false, false, false],
      spreadType: SpreadType.three,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final bar = find.byKey(const ValueKey('reading-guide'));
    await tester.ensureVisible(bar);
    await tester.pump();
    await tester.tap(bar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the guide never asks the Oracle on its own', (tester) async {
    await openGuideSheet(tester);
    final ask = find.byKey(const ValueKey('guide-ask-oracle'));
    expect(ask, findsOneWidget);
    expect(find.text('Ask the Oracle'), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-oracle-answer')), findsNothing);

    await tester.ensureVisible(ask);
    await tester.pump();
    await tester.tap(ask);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('guide-oracle-answer')), findsOneWidget);
    expect(find.text('THE ORACLE'), findsOneWidget);
    expect(find.textContaining('Sit with this question'), findsOneWidget);
  });

  testWidgets('the Oracle answer is localized', (tester) async {
    await openGuideSheet(tester, language: AppLanguage.ru);
    final ask = find.byKey(const ValueKey('guide-ask-oracle'));
    await tester.ensureVisible(ask);
    await tester.pump();
    await tester.tap(ask);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final answer = tester.widget<Text>(
      find.byKey(const ValueKey('guide-oracle-answer')),
    );
    expect(RegExp(r'[А-Яа-я]').hasMatch(answer.data!), isTrue);
  });
}
