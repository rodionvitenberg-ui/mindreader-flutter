/// Pre-draw intention prompts: the question asked for each slot of the
/// initial spread BEFORE the card is drawn, plus the quick context chips
/// and the endless-clarifier follow-up prompts. Pure Dart — no Flutter
/// imports.
class IntentionPrompt {
  const IntentionPrompt({required this.question, required this.chips});

  /// The slot-specific intention question.
  final String question;

  /// 3–4 zero-friction context pills for this slot.
  final List<String> chips;
}

const _sharedChips = [
  'Relationships & Feelings',
  'Career / Money Crossroads',
  'Inner Doubt',
  'Let the Deck Decide',
];

/// One prompt per slot position (the last one recycles for deep spreads).
const intentionPrompts = [
  IntentionPrompt(
    question: 'What is on your mind right now? Where is the tension?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'What hidden force or fear is influencing this?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'What direction are you seeking?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'Who or what stands in the doorway?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'What is ready to be released?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'What wants to grow into the light?',
    chips: _sharedChips,
  ),
  IntentionPrompt(
    question: 'What is the deeper lesson this cycle offers?',
    chips: _sharedChips,
  ),
];

/// The intention question for slot [slotIndex] (recycles for deeper slots).
IntentionPrompt intentionForSlot(int slotIndex) =>
    intentionPrompts[slotIndex % intentionPrompts.length];

/// Follow-up intention prompts offered after the synthesis — each one pulls
/// ONE clarifier card that expands the reading.
const clarifierFollowUps = [
  '+ Pull 1 Card: What is the hidden obstacle?',
  '+ Pull 1 Card: What concrete step should I take?',
];

/// Short form of the same prompts (the bar above the deck).
const clarifierFollowUpQuestions = [
  'What is the hidden obstacle?',
  'What concrete step should I take?',
];

/// The label of the third, free-form clarifier option.
const clarifierCustomLabel = '+ Ask my own question & pull a card...';

/// Quick one-line context chips floating above the Gemini input capsule on
/// the Digital Table (Sprint 2/3): one tap sends the chip into the ether.
const tableContextChips = [
  '✨ Relationships',
  '⚡ Crossroads',
  '🔮 Blind Draw',
];
