import '../models/dealt_card_slot.dart';
import '../models/spread_type.dart';
import '../models/tarot_card_model.dart';

/// How two adjacent face-up cards relate, elementally.
enum ThreadTone { harmony, conflict, neutral }

class ThreadInfo {
  final int from; // slot index
  final int to; // slot index
  final ThreadTone tone;
  const ThreadInfo({required this.from, required this.to, required this.tone});
}

/// Harmony: same element, or Water+Earth synergy.
/// Conflict: Fire+Water, Air+Fire tension.
/// NOTE: plain Set equality in Dart is identity-based, so pairs are compared
/// explicitly instead of via `Set<Set<Element>>.contains()`.
bool _isPair(Element a, Element b, Element x, Element y) =>
    (a == x && b == y) || (a == y && b == x);

/// Pure elemental dignity between two cards.
ThreadTone dignityBetween(TarotCard a, TarotCard b) {
  if (a.element == b.element) return ThreadTone.harmony;
  if (_isPair(a.element, b.element, Element.water, Element.earth)) {
    return ThreadTone.harmony;
  }
  if (_isPair(a.element, b.element, Element.fire, Element.water) ||
      _isPair(a.element, b.element, Element.air, Element.fire)) {
    return ThreadTone.conflict;
  }
  return ThreadTone.neutral;
}

/// Threads connect each pair of ADJACENT slots that are both face-up.
List<ThreadInfo> computeThreads(List<DealtCardSlot> slots) {
  final threads = <ThreadInfo>[];
  for (var i = 0; i < slots.length - 1; i++) {
    final a = slots[i];
    final b = slots[i + 1];
    final bothUp = a.state == SlotState.faceUp && b.state == SlotState.faceUp;
    if (bothUp && a.card != null && b.card != null) {
      threads.add(ThreadInfo(from: i, to: i + 1, tone: dignityBetween(a.card!, b.card!)));
    }
  }
  return threads;
}

/// Local-first cohesive synthesis: weaves each card's meaning into its slot
/// role and reads the elemental tensions — no generic dictionary lists.
/// The UI reveals the text with a typewriter effect (streaming feel, offline).
String synthesizeSpread(
  List<DealtCardSlot> slots,
  SpreadType type, {
  String? contextChip,
}) {
  final faceUp = slots.where((s) => s.card != null).toList();
  if (faceUp.isEmpty) {
    return 'Flip at least one card to begin the synthesis.';
  }

  final b = StringBuffer();
  if (contextChip != null && contextChip.isNotEmpty) {
    b.writeln('Lens: $contextChip.');
  }
  b.writeln(type.focusLine);
  b.writeln();

  for (final s in faceUp) {
    final c = s.card!;
    final meaning = s.isReversed ? c.reversed : c.upright;
    b.writeln(
      '${s.role} — ${c.name} (${s.isReversed ? 'reversed' : 'upright'}): $meaning',
    );
  }

  final threads = computeThreads(slots);
  final harmonies = threads.where((t) => t.tone == ThreadTone.harmony).length;
  final tensions = threads.where((t) => t.tone == ThreadTone.conflict).length;
  b.writeln();
  if (threads.isEmpty) {
    b.writeln('The cards stand alone for now — a single clear signal rather than a chorus.');
  } else {
    b.writeln(
      'Between the cards: $harmonies harmonious exchanges, $tensions elemental tensions.',
    );
    b.writeln(tensions > 0
        ? 'The friction is not a flaw — it marks exactly where the reading is asking you to grow.'
        : 'The elements cooperate; the spread moves with you rather than against you.');
  }

  b.writeln();
  b.writeln('The question to sit with: ${faceUp.first.card!.socratic}');
  return b.toString();
}
