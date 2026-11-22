import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindreader/core/l10n/app_strings.dart';
import 'package:mindreader/core/models/guide_event.dart';
import 'package:mindreader/core/models/guide_hint.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/state/guided_reading_controller.dart';
import 'package:mindreader/state/spread_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpreadController spread;
  late AppSettingsController settings;
  late GuidedReadingController guide;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    spread = SpreadController();
    settings = AppSettingsController();
    // Settle the fire-and-forget load() so it never notifies after tearDown
    // disposes the controller.
    await settings.initialLoad;
    guide = GuidedReadingController(spread: spread, settings: settings);
    await settings.setAid(ReadingAid.guide, true);
  });

  tearDown(() {
    guide.dispose();
    settings.dispose();
    spread.dispose();
  });

  test('no hint while the spread is inactive or guidance is off', () async {
    expect(guide.currentHint, isNull); // Step 1 picker — nothing active yet.

    spread.activateSpread();
    expect(guide.currentHint, isNotNull);

    await settings.setAid(ReadingAid.guide, false);
    expect(guide.currentHint, isNull);

    await settings.setAid(ReadingAid.guide, true);
    expect(guide.currentHint, isNotNull);
  });

  test('dealing hint points at the first empty slot', () {
    spread.activateSpread();
    final hint = guide.currentHint!;
    expect(hint.eventType, GuideEventType.dealingStarted);
    expect(hint.anchor, GuideHintAnchorKind.slot);
    expect(hint.slotIndex, 0);
    expect(hint.title, contains('1 of 3'));

    spread.dealNextCard();
    expect(guide.currentHint!.slotIndex, 1);
  });

  test('reveal hint recommends the centre of a Three-card spread first', () {
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
    }
    expect(spread.recommendedSlot, 1);
    expect(guide.currentHint!.eventType, GuideEventType.revealingStarted);
    expect(guide.currentHint!.slotIndex, 1);

    spread.flipSlot(2); // out-of-order: the centre is still recommended.
    expect(spread.recommendedSlot, 1);
    expect(guide.currentHint!.slotIndex, 1);

    spread.flipSlot(1);
    expect(spread.recommendedSlot, 0);
    expect(guide.currentHint!.slotIndex, 0);
  });

  test('completed hint stays visible while the spread is complete', () {
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
    }
    spread.flipSlot(0);
    spread.flipSlot(1);
    spread.flipSlot(2);
    expect(guide.currentHint!.eventType, GuideEventType.spreadCompleted);

    // A later state change within the same reading keeps the hint visible.
    spread.setReadingQuestion('does this help?');
    expect(guide.currentHint!.eventType, GuideEventType.spreadCompleted);
  });

  test('explicit relationship explanation outranks the reveal hint', () {
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
    }
    spread.flipSlot(0);
    spread.flipSlot(1);
    expect(guide.currentHint!.eventType, GuideEventType.revealingStarted);

    final relationship = spread.relationships.first; // (0,1), both face-up.
    guide.explainRelationship(relationship);
    expect(guide.currentHint!.eventType, GuideEventType.relationshipTapped);
    expect(guide.explainedRelationship, same(relationship));

    guide.clearRelationship();
    expect(guide.currentHint!.eventType, GuideEventType.revealingStarted);
  });

  test('RU localises the dealing hint title', () {
    settings.setLanguage(AppLanguage.ru);
    spread.activateSpread();
    expect(guide.currentHint!.title, contains('Выложите 1 из 3'));
  });

  test('relationship explanation is localized (RU)', () {
    settings.setLanguage(AppLanguage.ru);
    spread.activateSpread();
    for (var i = 0; i < 3; i++) {
      spread.dealNextCard();
    }
    spread.flipSlot(0);
    spread.flipSlot(1);
    final relationship = spread.relationships.first;
    guide.explainRelationship(relationship);
    expect(guide.currentHint!.body, contains('в этом методе'));
  });

  // ---- G1 memory: conceptual lessons (guided_seen_v1) --------------------

  test('concise detail carries no conceptual lesson', () async {
    expect(settings.guideDetail, GuideDetail.concise);
    spread.activateSpread();

    final hint = guide.currentHint!;
    expect(hint.lessonId, isNull);
    expect(hint.lesson, isNull);
  });

  test('thorough detail attaches the position lesson until it is read', () async {
    await settings.setGuideDetail(GuideDetail.thorough);
    spread.activateSpread();

    final hint = guide.currentHint!;
    expect(hint.eventType, GuideEventType.dealingStarted);
    expect(hint.lessonId, isNotNull);
    expect(hint.lesson, contains('essence of the matter'));

    await guide.learnCurrentLesson();
    expect(guide.currentHint!.lessonId, isNull);
    expect(guide.currentHint!.lesson, isNull);
  });

  test('a read lesson is not repeated in the next reading of the same spread', () async {
    await settings.setGuideDetail(GuideDetail.thorough);
    spread.activateSpread();
    await guide.learnCurrentLesson();

    spread.exitSpread();
    spread.activateSpread();
    expect(guide.currentHint!.lessonId, isNull);

    // …but another position of the same spread still teaches its own lesson.
    spread.dealNextCard();
    expect(guide.currentHint!.lesson, contains('hidden, feared'));
  });

  test('a lesson is scoped to its spread type', () async {
    await settings.setGuideDetail(GuideDetail.thorough);
    spread.activateSpread();
    await guide.learnCurrentLesson();

    spread.setSpreadType(SpreadType.seven);
    final hint = guide.currentHint!;
    expect(hint.lessonId, isNotNull);
    expect(hint.lesson, contains('roots of the situation'));
  });

  test('resetLearned brings the learned lessons back', () async {
    await settings.setGuideDetail(GuideDetail.thorough);
    spread.activateSpread();
    await guide.learnCurrentLesson();
    expect(guide.currentHint!.lessonId, isNull);

    await guide.resetLearned();
    expect(guide.currentHint!.lesson, contains('essence of the matter'));
  });

  test('learned lessons survive a controller restart', () async {
    await settings.setGuideDetail(GuideDetail.thorough);
    spread.activateSpread();
    await guide.learnCurrentLesson();

    final restarted = GuidedReadingController(
      spread: spread,
      settings: settings,
    );
    await restarted.initialLoad;
    expect(restarted.currentHint!.lessonId, isNull);
    restarted.dispose();
  });

  test('the detail level is restored from the preference store', () async {
    await settings.setGuideDetail(GuideDetail.thorough);

    final restored = AppSettingsController();
    await restored.initialLoad;
    expect(restored.guideDetail, GuideDetail.thorough);
    restored.dispose();
  });
}
