import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/data/guide_content.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/guide_event.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

/// G4.2 acceptance: when two cards pull in different directions the mentor
/// teaches the tension once, and the "tradition vs modern school" note is a
/// second, separate lesson — both remembered in `guided_seen_v1`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpreadController spread;
  late AppSettingsController settings;
  late GuidedReadingController guide;

  TarotCard cardWith(Element element, {int skip = 0}) =>
      tarotDeck.where((c) => c.element == element).elementAt(skip);

  /// Deals a face-up Tarot spread on the Active Table (a scanned reading).
  void laySpread(List<Element> elements) {
    spread.loadScannedSpread(
      system: DivinationSystem.tarot,
      cards: [
        for (var i = 0; i < elements.length; i++)
          TarotDivinationCard(cardWith(elements[i], skip: i)),
      ],
      reversed: List<bool>.filled(elements.length, false),
      spreadType: spreadTypeForCount(elements.length),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    spread = SpreadController();
    settings = AppSettingsController();
    await settings.initialLoad;
    guide = GuidedReadingController(spread: spread, settings: settings);
    await settings.setAid(ReadingAid.guide, true);
    await settings.setGuideDetail(GuideDetail.thorough);
  });

  tearDown(() {
    guide.dispose();
    settings.dispose();
    spread.dispose();
  });

  test('opposing elements teach the tension once the spread is complete', () {
    laySpread([Element.fire, Element.water, Element.air]);

    final hint = guide.currentHint!;
    expect(hint.eventType, GuideEventType.spreadCompleted);
    expect(hint.lessonId, 'conflict:tarot');
    expect(hint.lesson!.trim(), isNotEmpty);
  });

  test('the school lesson follows the conflict lesson, never before it', () async {
    laySpread([Element.fire, Element.water, Element.air]);
    expect(guide.currentHint!.lessonId, 'conflict:tarot');

    await guide.learnCurrentLesson();
    expect(guide.currentHint!.lessonId, 'school:tarot');

    await guide.learnCurrentLesson();
    expect(guide.currentHint!.lessonId, isNull);
    expect(guide.currentHint!.lesson, isNull);
  });

  test('harmonious elements teach the school lesson only', () async {
    laySpread([Element.fire, Element.air, Element.fire]);

    expect(guide.currentHint!.lessonId, 'school:tarot');
    await guide.learnCurrentLesson();
    expect(guide.currentHint!.lessonId, isNull);
  });

  test('the read conflict lesson never returns in the next reading', () async {
    laySpread([Element.fire, Element.water, Element.air]);
    await guide.learnCurrentLesson();
    await guide.learnCurrentLesson();

    spread.exitSpread();
    laySpread([Element.fire, Element.water, Element.air]);
    expect(guide.currentHint!.lessonId, isNull);
  });

  test('concise guidance teaches no link lessons', () async {
    await settings.setGuideDetail(GuideDetail.concise);
    laySpread([Element.fire, Element.water, Element.air]);

    expect(guide.currentHint!.lessonId, isNull);
    expect(guide.currentHint!.lesson, isNull);
  });

  test('a single card has no link to teach', () {
    laySpread([Element.fire]);
    expect(guide.currentHint!.eventType, GuideEventType.spreadCompleted);
    expect(guide.currentHint!.lessonId, isNull);
  });

  test('positional links teach nothing about dignities', () {
    spread.setSpreadType(SpreadType.celticCross);
    spread.activateSpread();
    for (var i = 0; i < spread.spreadCardCount; i++) {
      spread.dealNextCard();
      spread.flipSlot(i);
    }
    expect(guide.currentHint!.eventType, GuideEventType.spreadCompleted);
    expect(spread.relationships, isNotEmpty);
    expect(guide.currentHint!.lessonId, isNull);
  });

  test('a tapped contradictory link carries the conflict lesson', () {
    laySpread([Element.fire, Element.water, Element.air]);
    final link = spread.relationships.firstWhere((r) => r.isContradictory);

    guide.explainRelationship(link);
    expect(guide.currentHint!.eventType, GuideEventType.relationshipTapped);
    expect(guide.currentHint!.lessonId, 'conflict:tarot');
  });

  test('a tapped harmonious link teaches the school lesson', () {
    laySpread([Element.fire, Element.air, Element.fire]);
    final link = spread.relationships.firstWhere((r) => !r.isContradictory);

    guide.explainRelationship(link);
    expect(guide.currentHint!.lessonId, 'school:tarot');
  });

  test('Lenormand and runes have no authored link lessons', () {
    spread.setSystem(DivinationSystem.lenormand);
    spread.setLenormandSpread(LenormandSpread.three);
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
      spread.flipSlot(i);
    }
    expect(guide.currentHint!.lessonId, isNull);

    spread.setSystem(DivinationSystem.runes);
    spread.setRuneCast(RuneCast.three);
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
      spread.flipSlot(i);
    }
    expect(guide.currentHint!.lessonId, isNull);
  });

  test('the link lessons are localized in every language', () {
    for (final lang in AppLanguage.values) {
      final conflict = guideConflictLesson(DivinationSystem.tarot);
      final school = guideSchoolLesson(DivinationSystem.tarot);
      expect(conflict, isNotNull, reason: 'conflict $lang');
      expect(school, isNotNull, reason: 'school $lang');
      expect(conflict!.forLanguage(lang).trim(), isNotEmpty);
      expect(school!.forLanguage(lang).trim(), isNotEmpty);
      if (lang == AppLanguage.en) continue;
      expect(
        conflict.forLanguage(lang),
        isNot(conflict.forLanguage(AppLanguage.en)),
        reason: 'conflict $lang was not translated',
      );
      expect(
        school.forLanguage(lang),
        isNot(school.forLanguage(AppLanguage.en)),
        reason: 'school $lang was not translated',
      );
    }
    expect(guideConflictLesson(DivinationSystem.lenormand), isNull);
    expect(guideConflictLesson(DivinationSystem.runes), isNull);
    expect(guideSchoolLesson(DivinationSystem.lenormand), isNull);
    expect(guideSchoolLesson(DivinationSystem.runes), isNull);
  });

  test('the conflict lesson is rendered in the active language', () {
    laySpread([Element.fire, Element.water, Element.air]);
    settings.setLanguage(AppLanguage.ru);
    expect(RegExp(r'[А-Яа-я]').hasMatch(guide.currentHint!.lesson!), isTrue);
  });
}
