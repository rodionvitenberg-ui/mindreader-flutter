import '../l10n/app_strings.dart';

/// Pre-draw intention prompts: the question asked for each slot of the
/// initial spread BEFORE the card is drawn, plus the quick context chips
/// and the endless-clarifier follow-up prompts. Pure Dart — no Flutter
/// imports.
class IntentionPrompt {
  const IntentionPrompt({required this.questionKey, required this.chipKeys});

  /// Dictionary key of the slot-specific intention question.
  final String questionKey;

  /// Dictionary keys of the 3–4 zero-friction context pills for this slot.
  final List<String> chipKeys;

  String get question => AppStrings.g(questionKey);
  List<String> get chips => [for (final key in chipKeys) AppStrings.g(key)];
}

const _sharedChipKeys = [
  'intention.chip.relationships',
  'intention.chip.career',
  'intention.chip.doubt',
  'intention.chip.deck',
];

/// One prompt per slot position (the last one recycles for deep spreads).
const intentionPrompts = [
  IntentionPrompt(questionKey: 'intention.slot.0', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.1', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.2', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.3', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.4', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.5', chipKeys: _sharedChipKeys),
  IntentionPrompt(questionKey: 'intention.slot.6', chipKeys: _sharedChipKeys),
];

/// The intention question for slot [slotIndex] (recycles for deeper slots).
IntentionPrompt intentionForSlot(int slotIndex) =>
    intentionPrompts[slotIndex % intentionPrompts.length];

/// Follow-up intention prompts offered after the synthesis — each one pulls
/// ONE clarifier card that expands the reading.
List<String> get clarifierFollowUps => [
  AppStrings.g('intention.clarifier.hidden'),
  AppStrings.g('intention.clarifier.step'),
];

/// Short form of the same prompts (the bar above the deck).
List<String> get clarifierFollowUpQuestions => [
  AppStrings.g('intention.question.hidden'),
  AppStrings.g('intention.question.step'),
];

/// The label of the third, free-form clarifier option.
String get clarifierCustomLabel => AppStrings.g('intention.custom');

/// Quick one-line context chips floating above the Gemini input capsule on
/// the Digital Table (Sprint 2/3): one tap sends the chip into the ether.
List<String> get tableContextChips => [
  AppStrings.g('table.chip.relationships'),
  AppStrings.g('table.chip.crossroads'),
  AppStrings.g('table.chip.blindDraw'),
];
