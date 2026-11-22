import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/data/guide_content.dart';
import 'package:mindreader/core/data/guide_copy.dart';
import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

/// G4 acceptance: the mentor must have something to teach for EVERY preset
/// spread of EVERY system, in both languages, aligned with the slot count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectComplete({
    required DivinationSystem system,
    required String spreadKey,
    required int cardCount,
  }) {
    final purpose = guidePurposeLine(system, spreadKey);
    expect(purpose, isNotNull, reason: '$spreadKey has no purpose');
    expect(purpose!.en.trim(), isNotEmpty, reason: '$spreadKey EN purpose');
    expect(purpose.ru.trim(), isNotEmpty, reason: '$spreadKey RU purpose');

    for (var slot = 0; slot < cardCount; slot++) {
      final en = guideSlotLesson(
        system: system,
        spreadKey: spreadKey,
        slot: slot,
        lang: AppLanguage.en,
      );
      final ru = guideSlotLesson(
        system: system,
        spreadKey: spreadKey,
        slot: slot,
        lang: AppLanguage.ru,
      );
      expect(en, isNotNull, reason: '$system/$spreadKey slot $slot EN');
      expect(ru, isNotNull, reason: '$system/$spreadKey slot $slot RU');
      expect(en!.trim(), isNotEmpty, reason: '$system/$spreadKey slot $slot');
      expect(ru!.trim(), isNotEmpty, reason: '$system/$spreadKey slot $slot');
      expect(
        ru,
        isNot(en),
        reason: '$system/$spreadKey slot $slot was not translated',
      );
    }

    expect(
      guideSlotLesson(
        system: system,
        spreadKey: spreadKey,
        slot: cardCount,
        lang: AppLanguage.en,
      ),
      isNull,
      reason: '$spreadKey teaches a slot it does not have',
    );
  }

  test('every tarot spread has a purpose and a lesson per slot', () {
    for (final spread in SpreadType.values) {
      expectComplete(
        system: DivinationSystem.tarot,
        spreadKey: spread.name,
        cardCount: spread.cardCount,
      );
    }
  });

  test('every Lenormand spread has a purpose and a lesson per slot', () {
    for (final spread in LenormandSpread.values) {
      expectComplete(
        system: DivinationSystem.lenormand,
        spreadKey: spread.name,
        cardCount: spread.cardCount,
      );
    }
  });

  test('every rune cast has a purpose and a lesson per slot', () {
    for (final cast in RuneCast.values) {
      expectComplete(
        system: DivinationSystem.runes,
        spreadKey: cast.name,
        cardCount: cast.cardCount,
      );
    }
  });

  group('SpreadController exposes the localized lessons', () {
    late SpreadController spread;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      spread = SpreadController();
    });

    tearDown(() => spread.dispose());

    test('a Lenormand line teaches in EN and RU', () {
      spread.setSystem(DivinationSystem.lenormand);
      spread.setLenormandSpread(LenormandSpread.three);
      expect(
        spread.slotLesson(0, AppLanguage.en),
        guideSlotLesson(
          system: DivinationSystem.lenormand,
          spreadKey: LenormandSpread.three.name,
          slot: 0,
          lang: AppLanguage.en,
        ),
      );
      expect(
        RegExp(r'[А-Яа-я]').hasMatch(spread.slotLesson(0, AppLanguage.ru)!),
        isTrue,
      );
      expect(spread.slotLesson(0, AppLanguage.ru), contains('уже случилось'));
      expect(spread.guidePurpose(AppLanguage.ru), isNotNull);
    });

    test('a rune cast teaches in RU', () {
      spread.setSystem(DivinationSystem.runes);
      spread.setRuneCast(RuneCast.three);
      expect(
        spread.slotLesson(2, AppLanguage.ru),
        guideSlotLesson(
          system: DivinationSystem.runes,
          spreadKey: RuneCast.three.name,
          slot: 2,
          lang: AppLanguage.ru,
        ),
      );
      expect(spread.guidePurpose(AppLanguage.en), isNotNull);
    });
  });

  group('GuidedReadingController teaches every system', () {
    late SpreadController spread;
    late AppSettingsController settings;
    late GuidedReadingController guide;

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

    test('a Lenormand spread carries a lesson', () {
      spread.setSystem(DivinationSystem.lenormand);
      spread.setLenormandSpread(LenormandSpread.three);
      spread.activateSpread();
      expect(guide.currentHint!.lesson, isNotNull);
      expect(guide.currentHint!.lessonId, isNotNull);
    });

    test('a rune cast carries a lesson', () {
      spread.setSystem(DivinationSystem.runes);
      spread.setRuneCast(RuneCast.three);
      spread.activateSpread();
      expect(guide.currentHint!.lesson, isNotNull);
    });

    test('the RU lesson is Cyrillic', () {
      settings.setLanguage(AppLanguage.ru);
      spread.setSystem(DivinationSystem.runes);
      spread.setRuneCast(RuneCast.three);
      spread.activateSpread();
      expect(RegExp(r'[А-Яа-я]').hasMatch(guide.currentHint!.lesson!), isTrue);
    });

    test('a preset spread still teaches after a language switch', () {
      spread.setSystem(DivinationSystem.tarot);
      spread.activateSpread();
      final en = guide.currentHint!.lesson;
      settings.setLanguage(AppLanguage.ru);
      expect(guide.currentHint!.lesson, isNot(en));
    });
  });
  test('every system labels its reading method in both languages', () {
    for (final system in DivinationSystem.values) {
      for (final lang in AppLanguage.values) {
        expect(
          GuideCopy.methodNote(lang, system).trim(),
          isNotEmpty,
          reason: '$system in $lang',
        );
      }
    }
    expect(
      GuideCopy.methodNote(AppLanguage.ru, DivinationSystem.lenormand),
      contains('парами'),
    );
    expect(
      GuideCopy.methodNote(AppLanguage.en, DivinationSystem.runes),
      contains('merkstave'),
    );
  });


  test('reversals and merkstave are explained, never moralised', () {
    for (final lang in AppLanguage.values) {
      final tarot = GuideCopy.reversalNote(lang, DivinationSystem.tarot);
      final runes = GuideCopy.reversalNote(lang, DivinationSystem.runes);
      expect(tarot.trim(), isNotEmpty);
      expect(runes.trim(), isNotEmpty);
      expect(runes, isNot(tarot), reason: 'runes do not reverse');
    }
    expect(
      GuideCopy.reversalNote(AppLanguage.en, DivinationSystem.tarot),
      contains('not a'),
    );
    expect(
      GuideCopy.reversalNote(AppLanguage.ru, DivinationSystem.runes),
      contains('Меркставе'),
    );
  });
}
