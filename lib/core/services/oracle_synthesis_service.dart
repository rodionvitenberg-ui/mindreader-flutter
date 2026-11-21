import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/dealt_card_slot.dart';
import '../models/divination_system.dart';
import '../models/natal_chart.dart';
import '../models/oracle_action.dart';
import '../models/oracle_handoff.dart';
import '../models/spread_type.dart';
import '../models/tarot_card_model.dart';
import '../models/zodiac_forecast.dart';
import 'natal_calculator_service.dart';

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

/// Pure elemental dignity between two elements — the shared core behind
/// every system's Fate Threads.
ThreadTone dignityBetweenElements(Element a, Element b) {
  if (a == b) return ThreadTone.harmony;
  if (_isPair(a, b, Element.water, Element.earth)) {
    return ThreadTone.harmony;
  }
  if (_isPair(a, b, Element.fire, Element.water) ||
      _isPair(a, b, Element.air, Element.fire)) {
    return ThreadTone.conflict;
  }
  return ThreadTone.neutral;
}

/// Pure elemental dignity between two tarot cards (compat signature).
ThreadTone dignityBetween(TarotCard a, TarotCard b) =>
    dignityBetweenElements(a.element, b.element);

/// Threads connect each pair of ADJACENT slots that are both face-up.
List<ThreadInfo> computeThreads(List<DealtCardSlot> slots) {
  final threads = <ThreadInfo>[];
  for (var i = 0; i < slots.length - 1; i++) {
    final a = slots[i];
    final b = slots[i + 1];
    final bothUp = a.state == SlotState.faceUp && b.state == SlotState.faceUp;
    if (bothUp && a.card != null && b.card != null) {
      threads.add(ThreadInfo(
        from: i,
        to: i + 1,
        tone: dignityBetweenElements(a.card!.element, b.card!.element),
      ));
    }
  }
  return threads;
}

/// The three-part structured synthesis rendered in the on-table panel.
class StructuredSynthesis {
  const StructuredSynthesis({
    required this.narrative,
    required this.elementalAlchemy,
    required this.verdict,
    required this.followUp,
  });

  /// 1. Core Narrative Synthesis — the user's pre-draw answers woven with
  /// the cards.
  final String narrative;

  /// 2. Elemental Alchemy — dominance, absence, and the thread dynamics.
  final String elementalAlchemy;

  /// 3. Actionable Verdict — one concrete step to take.
  final String verdict;

  /// The Socratic question to sit with.
  final String followUp;
}

/// Counts the elements among the dealt cards (Fire, Water, Air, Earth).
Map<Element, int> elementalBalance(List<DealtCardSlot> slots) {
  final counts = {
    Element.fire: 0,
    Element.water: 0,
    Element.air: 0,
    Element.earth: 0,
  };
  for (final s in slots) {
    final c = s.card;
    if (c != null) counts[c.element] = counts[c.element]! + 1;
  }
  return counts;
}

/// The element(s) with the highest count (empty when nothing is dealt).
List<Element> dominantElements(Map<Element, int> balance) {
  if (balance.isEmpty) return const [];
  var max = 0;
  for (final v in balance.values) {
    if (v > max) max = v;
  }
  if (max == 0) return const [];
  return [for (final e in Element.values) if (balance[e] == max) e];
}

/// The elements with zero cards on the table.
List<Element> missingElements(Map<Element, int> balance) => [
      for (final e in Element.values)
        if (balance[e] == 0) e,
    ];

/// True when the slot role is the spread's "shadowy" position — the slot
/// most likely to speak about resistance, blocks and hidden forces.
bool _isShadowRole(String role) =>
    role.contains('Hidden') ||
    role.contains('Shadow') ||
    role.contains('Block') ||
    role.contains('Obstacle') ||
    role.contains('Bridges');

/// The AI's 2-3 spread-specific follow-up Clarifier Questions shown at the
/// end of the synthesis (and after every Clarifier Reading until the
/// clarifier ceiling). Pure and deterministic: each question dynamically
/// references the ACTUAL cards and elemental tensions on the table.
List<String> buildClarifierSuggestions(
  List<DealtCardSlot> slots, {
  int hardMax = 15,
}) {
  final faceUp = [for (final s in slots) if (s.card != null) s];
  if (faceUp.isEmpty) return const [];
  if (faceUp.length >= hardMax) return const [];

  final suggestions = <String>[];

  // 1. The sharp boundary: a reversed card (or the spread's shadow slot)
  // carries the resistance to question.
  final reversed = [for (final s in faceUp) if (s.isReversed) s];
  final shadow = [for (final s in faceUp) if (_isShadowRole(s.role)) s];
  final anchor = reversed.isNotEmpty
      ? reversed.first
      : (shadow.isNotEmpty ? shadow.first : faceUp.first);
  suggestions.add(
    "What is hidden behind ${anchor.card!.name}"
    '${anchor.isReversed ? ' (Reversed)' : ''}\'s resistance?',
  );

  // 2. The elemental tension: a conflict thread between two concrete
  // cards, or the dominant element pressing on the reading.
  final conflict = [
    for (final t in computeThreads(slots))
      if (t.tone == ThreadTone.conflict) t,
  ];
  if (conflict.isNotEmpty) {
    final t = conflict.first;
    suggestions.add(
      'What concrete action resolves the elemental tension between '
      '${slots[t.from].card!.name} and ${slots[t.to].card!.name}?',
    );
  } else {
    final dominant = dominantElements(elementalBalance(slots));
    suggestions.add(
      dominant.isEmpty
          ? 'What concrete action steadies the balanced elements on the table?'
          : 'What concrete action rebalances the '
              '${dominant.first.label.toLowerCase()} weight of this reading?',
    );
  }

  // 3. The last voice: the newest card keeps something unspoken.
  final last = faceUp.last;
  suggestions.add(
    'What is ${last.card!.name}${last.isReversed ? ' (Reversed)' : ''} '
    'not yet telling you about the next step?',
  );
  return suggestions;
}

/// Composes the Elemental Alchemy section from the balance + threads.
String _alchemyText(List<DealtCardSlot> slots, List<ThreadInfo> threads) {
  final balance = elementalBalance(slots);
  final dominant = dominantElements(balance);
  final missing = missingElements(balance);
  final b = StringBuffer();
  final parts = [
    for (final e in Element.values)
      '${e.label} ${e.glyph} ×${balance[e] ?? 0}',
  ];
  b.writeln('Balance: ${parts.join(' · ')}.');
  if (dominant.isNotEmpty) {
    b.writeln('${dominant.map((e) => e.label).join(' + ')} dominates — '
        '${dominant.map((e) => e.trait).join(' and ')} lead the reading.');
  }
  if (missing.isNotEmpty) {
    b.writeln('${missing.map((e) => e.label).join(' and ')} is absent — '
        'the table is asking where that ${missing.map((e) => e.trait).join(' and ')} went.');
  }
  final harmonies = threads.where((t) => t.tone == ThreadTone.harmony).length;
  final tensions = threads.where((t) => t.tone == ThreadTone.conflict).length;
  b.writeln('Threads: $harmonies harmonious, $tensions tensed — '
      '${tensions > 0 ? 'the friction marks the growth point of this reading.' : 'the strings hum in cooperation.'}');
  return b.toString();
}

/// The meaning that applies to this slot right now: the reversed reading
/// when the card is reversed AND the system supports it, upright otherwise
/// (Lenormand always upright, symmetrical runes always upright).
String meaningFor(DealtCardSlot s) {
  final c = s.card;
  if (c == null) return '';
  return s.isReversed && c.reversed != null ? c.reversed! : c.upright;
}

/// The orientation word per slot: 'reversed' / 'upright' / 'merkstave'.
String orientationWord(DealtCardSlot s) {
  if (!s.isReversed) return 'upright';
  return s.card?.system == DivinationSystem.runes ? 'merkstave' : 'reversed';
}

/// Composes the Actionable Verdict from the last card + element context.
String _verdictText(List<DealtCardSlot> slots, Map<Element, int> balance) {
  final faceUp = slots.where((s) => s.card != null).toList();
  final last = faceUp.last;
  final c = last.card!;
  final missing = missingElements(balance);
  final b = StringBuffer();
  final action = c.reflection;
  b.writeln(
    '${last.role}: ${c.name} points at one move — ${c.upright.split(' — ').last}.',
  );
  if (missing.isNotEmpty) {
    b.writeln('Ground it with the missing ${missing.first.label.toLowerCase()} '
        '(${missing.first.trait.toLowerCase()}) and the path stays honest.');
  }
  b.writeln('The step to take today: $action');
  return b.toString();
}

/// Local-first cohesive synthesis: weaves each card's meaning into its slot
/// role and reads the elemental tensions — no generic dictionary lists.
/// The UI reveals the text with a typewriter effect (streaming feel, offline).
///
/// [slotContexts] maps slot index → the user's pre-draw intention (chip
/// and/or typed/spoken note); each entry is woven into the narrative.
String synthesizeSpread(
  List<DealtCardSlot> slots,
  SpreadType type, {
  String? contextChip,
  Map<int, String>? slotContexts,
}) {
  return synthesizeSpreadFor(
    slots,
    system: DivinationSystem.tarot,
    spreadLabel: type.label,
    focusLine: type.focusLine,
    contextChip: contextChip,
    slotContexts: slotContexts,
  );
}

/// The system-aware synthesis core — the tarot wrapper above delegates
/// here, Lenormand and Rune casts call it directly.
String synthesizeSpreadFor(
  List<DealtCardSlot> slots, {
  required DivinationSystem system,
  required String spreadLabel,
  required String focusLine,
  String? contextChip,
  Map<int, String>? slotContexts,
  String? profileContext,
  List<String>? positionQuestions,
}) {
  final faceUp = slots.where((s) => s.card != null).toList();
  if (faceUp.isEmpty) {
    return 'Flip at least one card to begin the synthesis.';
  }

  final hasQuestionPairs =
      positionQuestions != null && positionQuestions.isNotEmpty;

  final b = StringBuffer();
  if (profileContext != null && profileContext.isNotEmpty) {
    b.writeln('Who this reading is for: $profileContext.');
  }
  if (contextChip != null && contextChip.isNotEmpty) {
    b.writeln('Lens: $contextChip.');
  }
  b.writeln('$spreadLabel — $focusLine');
  b.writeln();

  for (final s in faceUp) {
    final c = s.card!;
    final held = slotContexts?[s.index];
    if (held != null && held.isNotEmpty) {
      b.writeln('You held before drawing: $held.');
    }
    final orientation =
        c.system == DivinationSystem.lenormand ? '' : ' (${orientationWord(s)})';
    if (hasQuestionPairs && s.index < positionQuestions.length) {
      final q = positionQuestions[s.index];
      b.writeln(
        '${s.index + 1}. Question: $q — ${c.name}$orientation: ${meaningFor(s)}',
      );
    } else {
      b.writeln('${s.role} — ${c.name}$orientation: ${meaningFor(s)}');
    }
  }

  if (hasQuestionPairs && faceUp.length > 1) {
    final first = faceUp.first.card!;
    final last = faceUp.last.card!;
    b.writeln();
    b.writeln(
      'Overall thread: across these ${faceUp.length} question–card pairs, '
      'the reading moves from ${first.name} toward ${last.name}, linking each '
      'answer into one connected arc.',
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
  b.writeln('The question to sit with: ${faceUp.first.card!.reflection}');
  return b.toString();
}


/// Remote synthesis with the same dual AI pipeline as vision:
///
/// 1. PRIMARY — local/tunneled RTX 3080 worker (chat endpoint,
///    `PRIMARY_WORKER_URL`, 3500 ms timeout).
/// 2. FALLBACK — Gemini Flash cloud (`ORACLE_API_URL` / Gemini key).
/// 3. OFFLINE SAFETY NET — the deterministic local [synthesizeSpread]
///    engine, so the reading sheet never fails without network.
class OracleSynthesisService {
  OracleSynthesisService({http.Client? client})
      : _client = client ?? http.Client();

  static const primaryWorkerUrl = String.fromEnvironment('PRIMARY_WORKER_URL');
  static const primaryWorkerKey = String.fromEnvironment('PRIMARY_WORKER_KEY');
  static const primaryChatModel = String.fromEnvironment(
    'PRIMARY_WORKER_CHAT_MODEL',
    defaultValue: 'llama3.1',
  );
  static const cloudUrl = String.fromEnvironment(
    'ORACLE_API_URL',
    defaultValue:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
  );
  static const cloudModel = String.fromEnvironment(
    'ORACLE_API_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static String get cloudKey {
    const gemini = String.fromEnvironment('GEMINI_API_KEY');
    if (gemini.isNotEmpty) return gemini;
    return String.fromEnvironment('VISION_API_KEY');
  }

  static const primaryTimeout = Duration(milliseconds: 3500);
  static const cloudTimeout = Duration(seconds: 20);

  final http.Client _client;

  bool get hasPrimary => primaryWorkerUrl.isNotEmpty;
  bool get hasCloud => cloudUrl.isNotEmpty && cloudKey.isNotEmpty;

  /// The Oracle's voice (4.8): calm, restrained, contextual and symbolic —
  /// grounded psychology, never kitsch or mysticism, and NEVER categorical
  /// medical / financial / legal predictions. Spoken answers stay shorter than
  /// written ones. Shared by every prompt builder so the tone is one place.
  static const oraclePersona = 'You are the mindreader.quest oracle: calm, '
      'restrained, contextual and symbolic. You speak in grounded psychological '
      'language — reflective insight, never fortune-teller kitsch, never '
      'mysticism, never hard predictions. You NEVER give categorical medical, '
      'financial or legal predictions or advice. When an answer will be spoken '
      'aloud, keep it shorter than a written answer — concise enough to be read '
      'in one breath.';

  /// Cohesive spread synthesis: worker → Gemini Flash → local engine.
  /// Never throws; the local synthesis is the guaranteed result.
  /// [type] is the tarot template; Lenormand/Rune casts pass [spreadLabel]
  /// + [focusLine] + [system] instead.
  Future<String> synthesize({
    required List<DealtCardSlot> slots,
    SpreadType? type,
    String? spreadLabel,
    String? focusLine,
    DivinationSystem system = DivinationSystem.tarot,
    String? contextChip,
    Map<int, String>? slotContexts,
    String? profileContext,
    List<String>? positionQuestions,
  }) async {
    final resolvedLabel =
        spreadLabel ?? (type ?? SpreadType.three).label;
    final resolvedFocus =
        focusLine ?? (type ?? SpreadType.three).focusLine;
    final fallback = synthesizeSpreadFor(
      slots,
      system: system,
      spreadLabel: resolvedLabel,
      focusLine: resolvedFocus,
      contextChip: contextChip,
      slotContexts: slotContexts,
      profileContext: profileContext,
      positionQuestions: positionQuestions,
    );
    final prompt = buildSynthesisPrompt(
      slots: slots,
      system: system,
      spreadLabel: resolvedLabel,
      focusLine: resolvedFocus,
      contextChip: contextChip,
      slotContexts: slotContexts,
      profileContext: profileContext,
      positionQuestions: positionQuestions,
    );
    if (prompt == null) return fallback;

    if (hasPrimary) {
      try {
        final text = await _chat(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryChatModel,
          timeout: primaryTimeout,
          prompt: prompt,
        );
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('oracle: primary worker unreachable '
            '(${e.runtimeType}), falling back to cloud');
      }
    }
    if (hasCloud) {
      try {
        final text = await _chat(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          prompt: prompt,
        );
        if (text.isNotEmpty) return text;
      } catch (e) {
        debugPrint('oracle: cloud endpoint failed '
            '(${e.runtimeType}), local synthesis');
      }
    }
    return fallback;
  }

  /// The ceremonial SYNTHESIZE READING pipeline: the narrative runs through
  /// the dual AI chain (worker → cloud → local), while the Elemental
  /// Alchemy and Actionable Verdict sections are always composed locally
  /// from the pure domain data — deterministic and offline-proof.
  Future<StructuredSynthesis> synthesizeStructured({
    required List<DealtCardSlot> slots,
    SpreadType? type,
    String? spreadLabel,
    String? focusLine,
    DivinationSystem system = DivinationSystem.tarot,
    String? contextChip,
    Map<int, String>? slotContexts,
    String? profileContext,
    List<String>? positionQuestions,
  }) async {
    final narrative = await synthesize(
      slots: slots,
      type: type,
      spreadLabel: spreadLabel,
      focusLine: focusLine,
      system: system,
      contextChip: contextChip,
      slotContexts: slotContexts,
      profileContext: profileContext,
      positionQuestions: positionQuestions,
    );
    final faceUp = slots.where((s) => s.card != null).toList();
    final threads = computeThreads(slots);
    final balance = elementalBalance(slots);
    return StructuredSynthesis(
      narrative: narrative,
      elementalAlchemy: _alchemyText(slots, threads),
      verdict: _verdictText(slots, balance),
      followUp: faceUp.last.card!.reflection,
    );
  }

  /// A single "Clarifier Expansion" chapter: answers the follow-up
  /// [question] with the newly pulled clarifier card in the light of the
  /// cards already on the table. Same dual pipeline, local fallback.
  Future<String> synthesizeClarifier({
    required String question,
    required DealtCardSlot newSlot,
    required List<DealtCardSlot> previous,
    String? profileContext,
  }) async {
    final c = newSlot.card;
    if (c == null) return '';
    final fallback = _clarifierFallback(question, newSlot, previous);
    if (!hasPrimary && !hasCloud) return fallback;
    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('The reader already has this reading on the table:');
    for (final s in previous) {
      final pc = s.card;
      if (pc == null) continue;
      b.writeln('- ${s.role}: ${pc.name} '
          '(${orientationWord(s)}), '
          'element ${pc.element.label}');
    }
    if (profileContext != null && profileContext.isNotEmpty) {
      b.writeln('Reader context: $profileContext.');
    }
    b.writeln('The reader now asks a follow-up question: $question');
    b.writeln('They pulled one clarifier ${c.system.unit}: ${c.name} '
        '(${orientationWord(newSlot)}), '
        'element ${c.element.label}. '
        '${meaningFor(newSlot)}');
    b.writeln('Write ONE short paragraph (3-5 sentences) that answers the '
        'follow-up question through this ${c.system.unit} IN THE CONTEXT of '
        'the cards already on the table, and close with one concrete step. '
        'Plain text only: no markdown, no lists.');
    try {
      if (hasPrimary) {
        final text = await _chat(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryChatModel,
          timeout: primaryTimeout,
          prompt: b.toString(),
        );
        if (text.isNotEmpty) return text;
      }
      if (hasCloud) {
        final text = await _chat(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          prompt: b.toString(),
        );
        if (text.isNotEmpty) return text;
      }
    } catch (e) {
      debugPrint('oracle: clarifier endpoints failed '
          '(${e.runtimeType}), local synthesis');
    }
    return fallback;
  }

  /// Offline clarifier chapter: the question + the card + the context of
  /// the previous cards, closed with the card's own reflection question.
  String _clarifierFallback(
    String question,
    DealtCardSlot newSlot,
    List<DealtCardSlot> previous,
  ) {
    final c = newSlot.card!;
    final b = StringBuffer();
    b.writeln('You asked: $question');
    b.writeln(
      '${c.name} (${orientationWord(newSlot)}) answers '
      'with: ${meaningFor(newSlot)}',
    );
    final prevNames = [
      for (final s in previous)
        if (s.card != null) s.card!.name,
    ];
    if (prevNames.isNotEmpty) {
      b.writeln('Read beside ${prevNames.join(', ')} already on the table, '
          'this ${c.system.unit} tightens the reading rather than replacing it.');
    }
    b.writeln('The step to take: ${c.reflection}');
    return b.toString();
  }
  /// Builds the LLM prompt for a spread synthesis. When [positionQuestions] is
  /// provided (Custom Spread), every slot is sent as an explicit numbered
  /// `Question — Card` pair and the Oracle is instructed to connect all pairs
  /// into one cohesive reading.
  static String? buildSynthesisPrompt({
    required List<DealtCardSlot> slots,
    required DivinationSystem system,
    required String spreadLabel,
    required String focusLine,
    String? contextChip,
    Map<int, String>? slotContexts,
    String? profileContext,
    List<String>? positionQuestions,
  }) {
    final faceUp = slots.where((s) => s.card != null).toList();
    if (faceUp.isEmpty) return null;
    final hasQuestionPairs =
        positionQuestions != null && positionQuestions.isNotEmpty;
    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('Spread: $spreadLabel (${faceUp.length} ${system.unit}s). '
        '$focusLine');
    if (profileContext != null && profileContext.isNotEmpty) {
      b.writeln('Who this reading is for (local profile, never stored '
          'server-side): $profileContext.');
    }
    if (contextChip != null && contextChip.isNotEmpty) {
      b.writeln('Reader lens: $contextChip.');
    }
    if (system == DivinationSystem.lenormand) {
      b.writeln('Lenormand cards are ALWAYS upright and are read in '
          'pairs — weigh each card against the ones sitting beside it.');
    }
    if (system == DivinationSystem.runes) {
      b.writeln('Runes land upright or merkstave (reversed); symmetrical '
          'runes stay upright. Read them by their Aett and element.');
    }
    if (hasQuestionPairs) {
      b.writeln('Question–card pairs in position order:');
      for (final s in faceUp) {
        final c = s.card!;
        final held = slotContexts?[s.index];
        if (held != null && held.isNotEmpty) {
          b.writeln('  Reader note on position ${s.index + 1}: $held.');
        }
        final q = s.index < positionQuestions.length
            ? positionQuestions[s.index]
            : s.role;
        b.writeln(
          '${s.index + 1}. Question: "$q" — Card: ${c.name} '
          '(${orientationWord(s)}), element ${c.element.label}. '
          '${meaningFor(s)}',
        );
      }
      b.writeln('Answer each question–card pair in order and weave all pairs '
          'together into one cohesive overall reading that highlights how the '
          'answers connect, names elemental harmonies and tensions, and closes '
          'with one sharp Socratic question. Plain text only: no markdown, '
          'no lists, no headers.');
    } else {
      b.writeln('Cards in reading order:');
      for (final s in faceUp) {
        final c = s.card!;
        final held = slotContexts?[s.index];
        if (held != null && held.isNotEmpty) {
          b.writeln('  The reader held in mind before drawing: $held.');
        }
        b.writeln('- ${s.role}: ${c.name} '
            '(${orientationWord(s)}), '
            'element ${c.element.label}. '
            '${meaningFor(s)}');
      }
      b.writeln('Write a cohesive synthesis of 2-3 short paragraphs that '
          'weaves each card\'s meaning into its slot role AND weaves in what '
          'the reader held in mind, names the elemental harmonies and '
          'tensions, and closes with one sharp Socratic question. '
          'Plain text only: no markdown, no lists, no headers.');
    }
    return b.toString();
  }

  /// A free-form conversational turn of the Oracle AI Chat (Pane 1):
  /// answers [question] in the light of the current table and the ongoing
  /// [history]. Same dual pipeline, deterministic local fallback.
  Future<String> answerChat({
    required String question,
    required List<DealtCardSlot> slots,
    SpreadType? type,
    String? spreadLabel,
    required List<ChatMessage> history,
    String? profileContext,
  }) async {
    final fallback = _chatFallback(question, slots);
    if (!hasPrimary && !hasCloud) return fallback;
    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('Spread: ${spreadLabel ?? (type ?? SpreadType.three).label}.');
    for (final s in slots) {
      final c = s.card;
      if (c == null) continue;
      b.writeln('- ${s.role}: ${c.name} '
          '(${orientationWord(s)})');
    }
    if (history.isNotEmpty) {
      b.writeln('Dialog so far:');
      for (final m in history) {
        b.writeln('  ${m.role}: ${m.text.replaceAll('\n', ' ')}');
      }
    }
    if (profileContext != null && profileContext.isNotEmpty) {
      b.writeln('Reader context: $profileContext.');
    }
    b.writeln('The reader asks: $question');
    b.writeln('Answer in 2-4 short sentences grounded in the cards on the '
        'table. Plain text only: no markdown, no lists.');
    try {
      if (hasPrimary) {
        final text = await _chat(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryChatModel,
          timeout: primaryTimeout,
          prompt: b.toString(),
        );
        if (text.isNotEmpty) return text;
      }
      if (hasCloud) {
        final text = await _chat(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          prompt: b.toString(),
        );
        if (text.isNotEmpty) return text;
      }
    } catch (e) {
      debugPrint(
          'oracle: chat endpoints failed (${e.runtimeType}), local answer');
    }
    return fallback;
  }

  /// A Live Oracle FREEFORM turn (4.5): interprets the freely-laid cards in
  /// the light of the reader's [intention] and returns a validated
  /// [OracleActionCommand] (text + an optional requested action). Same dual
  /// pipeline (worker → cloud → local); the local fallback is deterministic
  /// and always [OracleAction.respond] — it never requests a state change.
  Future<OracleActionCommand> interpretFreeform({
    required String intention,
    required List<DealtCardSlot> slots,
    DivinationSystem system = DivinationSystem.tarot,
    List<ChatMessage> history = const [],
    String? profileContext,
  }) async {
    final fallbackText = _freeformFallback(intention, slots);
    if (!hasPrimary && !hasCloud) {
      return OracleActionCommand(
        action: OracleAction.respond,
        text: fallbackText,
      );
    }

    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('This is a LIVE ORACLE freeform session: the reader laid cards '
        'freely, without a fixed spread.');
    if (intention.trim().isNotEmpty) {
      b.writeln('The reader\'s intention: ${intention.trim()}.');
    }
    final faceUp = slots.where((s) => s.card != null).toList();
    if (faceUp.isEmpty) {
      b.writeln('No cards have been laid yet.');
    } else {
      b.writeln('Cards laid so far, in order:');
      for (final s in faceUp) {
        final c = s.card!;
        b.writeln('- ${s.index + 1}. ${c.name} (${orientationWord(s)}), '
            'element ${c.element.label}. ${meaningFor(s)}');
      }
    }
    if (history.isNotEmpty) {
      b.writeln('Dialog so far:');
      for (final m in history) {
        b.writeln('  ${m.role}: ${m.text.replaceAll('\n', ' ')}');
      }
    }
    if (profileContext != null && profileContext.isNotEmpty) {
      b.writeln('Reader context: $profileContext.');
    }
    b.writeln('Interpret these cards in the light of the intention. Then '
        'request ONE next step by replying as strict JSON only: '
        '{"action": "<respond|suggestSpread|requestNextCard|'
        'requestClarifier|requestReveal|askQuestion|summarizeSpread|'
        'completeReading>", "text": "<your spoken answer>"}. '
        'You may only REQUEST; you must never invent cards, change a card\'s '
        'identity or orientation, or bypass limits, PRO or history. When no '
        'action is needed, use "respond".');

    try {
      if (hasPrimary) {
        final raw = await _chat(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryChatModel,
          timeout: primaryTimeout,
          prompt: b.toString(),
        );
        if (raw.isNotEmpty) return parseOracleActionResponse(raw);
      }
      if (hasCloud) {
        final raw = await _chat(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          prompt: b.toString(),
        );
        if (raw.isNotEmpty) return parseOracleActionResponse(raw);
      }
    } catch (e) {
      debugPrint(
          'oracle: freeform endpoints failed (${e.runtimeType}), local reading');
    }
    return OracleActionCommand(action: OracleAction.respond, text: fallbackText);
  }

  /// Offline freeform reading: the intention + the dominant element axis +
  /// the loudest card's reflection. Deterministic and action-free.
  String _freeformFallback(String intention, List<DealtCardSlot> slots) {
    final faceUp = [for (final s in slots) if (s.card != null) s];
    if (faceUp.isEmpty) {
      return 'State your intention, lay a few cards freely — no spread is '
          'required — and I will read them as they fall.';
    }
    final balance = elementalBalance(slots);
    final dominant = dominantElements(balance);
    final last = faceUp.last.card!;
    final axis = dominant.isEmpty
        ? 'the elements are balanced'
        : '${dominant.map((e) => e.trait.toLowerCase()).join(' and ')} '
            'keeps leading the reading';
    final intent = intention.trim().isEmpty
        ? ''
        : 'Holding your intention — ${intention.trim()} — ';
    return '$intent$axis. '
        '${last.name} stays the loudest voice here: ${last.reflection}';
  }

  /// Offline conversational answer: the dominant element axis + the
  /// loudest card's reflection question, closed toward the reader's question.
  String _chatFallback(String question, List<DealtCardSlot> slots) {
    final faceUp = [for (final s in slots) if (s.card != null) s];
    if (faceUp.isEmpty) {
      return 'The table is still empty — deal and flip your spread first, '
          'then bring your question back to me.';
    }
    final balance = elementalBalance(slots);
    final dominant = dominantElements(balance);
    final last = faceUp.last.card!;
    final axis = dominant.isEmpty
        ? 'the elements are balanced'
        : '${dominant.map((e) => e.trait.toLowerCase()).join(' and ')} '
            'keeps leading the reading';
    return 'Sitting with your question, $axis. '
        '${last.name} stays the loudest voice on the table: ${last.reflection}';
  }

  /// OpenAI/Ollama-compatible chat request. No keys or prompts are logged.
  Future<String> _chat({
    required String url,
    required String key,
    required String model,
    required Duration timeout,
    required String prompt,
  }) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (key.isNotEmpty) 'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'stream': false,
            'temperature': 0.7,
            'messages': [
              {
                'role': 'system',
                'content': oraclePersona,
              },
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('oracle endpoint responded ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    final content = (choices.first as Map)['message']['content'] as String;
    return content.replaceAll('```', '').trim();
  }

  // ---------------------------------------------------------------------
  // ASTRAL handoff — natal / synastry psychological readings
  // ---------------------------------------------------------------------

  static NatalPlanetPosition _find(NatalChart chart, PlanetId planet) =>
      chart.planets.firstWhere((p) => p.planet == planet);

  static String _describe(NatalPlanetPosition p) =>
      '${p.planet.title} ${p.sign.glyph} ${p.sign.title} ${p.formattedDegree}'
      '${p.house == null ? '' : ' in house ${p.house}'}';

  static String _mainPlacements(NatalChart chart) => [
    _describe(_find(chart, PlanetId.sun)),
    if (chart.timeKnown)
      _describe(_find(chart, PlanetId.moon))
    else if (!chart.moonSignUncertain)
      'Moon in ${_find(chart, PlanetId.moon).sign.title}'
    else
      'Moon sign uncertain',
    if (chart.timeKnown) _describe(_find(chart, PlanetId.ascendant)),
  ].join(' · ');

  static Element _dominantElementOf(NatalChart chart) {
    final counts = {for (final e in Element.values) e: 0};
    for (final p in chart.planets) {
      if (p.planet.isBody &&
          (!chart.moonSignUncertain || p.planet != PlanetId.moon)) {
        counts[p.sign.element] = counts[p.sign.element]! + 1;
      }
    }
    var best = Element.fire;
    for (final e in Element.values) {
      if (counts[e]! > counts[best]!) best = e;
    }
    return best;
  }

  /// A structured, reader-facing summary of a natal chart and today's sky —
  /// used both as the user message and as the AI prompt for the handoff.
  static String buildNatalPrompt(
    NatalChart chart,
    DailyHoroscopeReport? horoscope, {
    bool includeProfileNames = true,
  }) {
    final sharp = chart.aspects.firstOrNull;
    final buf = StringBuffer()
      ..writeln(
        'Natal profile: ${includeProfileNames ? chart.profileName : 'A'}.',
      )
      ..writeln(
        '${chart.timeKnown ? 'Big Three' : 'Birth time unknown; available placements'}: '
        '${_mainPlacements(chart)}.',
      )
      ..writeln('Dominant element: ${_dominantElementOf(chart).label}.');
    if (chart.timeKnown) {
      buf.writeln('House system: ${chart.houseSystem.label}.');
    }
    if (sharp != null) {
      buf.writeln(
        'Sharpest natal aspect: ${sharp.bodyA.title} ${sharp.type.glyph} '
        '${sharp.bodyB.title} (orb ${sharp.orb.toStringAsFixed(1)}°).',
      );
    }
    if (horoscope != null) {
      buf.writeln('${horoscope.overallTheme} ${_moonLocation(horoscope)}.');
      for (final t in horoscope.transits.take(3)) {
        buf.writeln('- ${t.transitLabel} · orb ${t.orb.toStringAsFixed(1)}°.');
      }
    }
    return buf.toString().trim();
  }

  /// A structured daily-horoscope summary for the active natal profile —
  /// today's sky, the three focus spheres and the loudest live transits.
  static String buildHoroscopePrompt(
    NatalChart chart,
    DailyHoroscopeReport report, {
    bool includeProfileNames = true,
    DailyTransitItem? transit,
  }) {
    final buf = StringBuffer();
    final d = report.date.toLocal();
    buf.writeln(
      'Daily horoscope for ${includeProfileNames ? chart.profileName : 'profile A'} — '
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}.',
    );
    buf.writeln(
      '${report.moonPhaseGlyph} ${report.moonPhaseName} · '
      '${(report.moonIllumination * 100).round()}% illuminated · '
      '${_moonLocation(report)}.',
    );
    buf.writeln('Energy: ${report.energyScore}/100. ${report.overallTheme}');
    for (final f in report.focusSpheres) {
      buf.writeln('${f.title}: ${f.text}');
    }
    if (!chart.timeKnown) {
      buf.writeln('Birth time unknown. Do not infer houses or angles.');
    }
    if (transit != null) {
      final timing = [
        if (transit.closestAt != null)
          'closest at ${transit.closestAt!.toUtc()}',
        if (transit.activeFrom != null)
          'active from ${transit.activeFrom!.toUtc()}',
        if (transit.activeUntil != null)
          'active until ${transit.activeUntil!.toUtc()}',
      ];
      buf.writeln(
        'Selected transit: ${transit.transitLabel}, '
        'orb ${transit.orb.toStringAsFixed(2)}°; ${timing.join(', ')}.',
      );
    }
    for (final t in report.transits.take(4)) {
      buf.writeln('- ${t.transitLabel} · orb ${t.orb.toStringAsFixed(1)}°.');
    }
    return buf.toString().trim();
  }

  static String _moonLocation(DailyHoroscopeReport report) =>
      'Moon${report.transitingMoonHouse == null ? '' : ' in house ${report.transitingMoonHouse}'}'
      ' (${report.transitingMoonSign.title})';

  /// A structured quick-sign forecast prompt — no natal chart required.
  static String buildZodiacForecastPrompt(
    ZodiacSign sign,
    ZodiacSignForecast forecast,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      'Daily horoscope for ${sign.title} ${sign.glyph} (no natal chart, calculated at ${forecast.date.toUtc()}).',
    );
    buf.writeln(
      '${forecast.moonPhaseGlyph} ${forecast.moonPhaseName} · '
      '${(forecast.moonIllumination * 100).round()}% illuminated · '
      'Moon in ${forecast.transitingMoonSign.title}, solar house '
      '${forecast.solarMoonHouse}.',
    );
    buf.writeln(
      'Energy: ${forecast.energyScore}/100. ${forecast.overallTheme}',
    );
    for (final f in forecast.focusSpheres) {
      buf.writeln('${f.title}: ${f.text}');
    }
    return buf.toString().trim();
  }

  /// A structured synastry summary for the compare-two-charts handoff.
  static String buildSynastryPrompt(
    NatalChart a,
    NatalChart b, {
    bool includeProfileNames = true,
  }) {
    final nameA = includeProfileNames ? a.profileName : 'Profile A';
    final nameB = includeProfileNames ? b.profileName : 'Profile B';
    final buf = StringBuffer()
      ..writeln('Synastry: $nameA × $nameB.')
      ..writeln('$nameA: ${_mainPlacements(a)}.')
      ..writeln('$nameB: ${_mainPlacements(b)}.');
    if (!a.timeKnown || !b.timeKnown) {
      buf.writeln(
        'Birth time is unknown for at least one chart. Do not infer missing angles or houses.',
      );
    }
    final aspects = NatalCalculatorService.computeSynastryAspects(a, b);
    buf.writeln('Tightest cross-chart aspects:');
    for (final aspect in aspects.take(5)) {
      buf.writeln(
        '- $nameA ${aspect.bodyA.title} ${aspect.type.glyph} '
        '$nameB ${aspect.bodyB.title} '
        '(orb ${aspect.orb.toStringAsFixed(1)}°).',
      );
    }
    return buf.toString().trim();
  }

  /// Uses calculated placements and neutral labels for the network request.
  static String astralOracleContext(OracleHandoff handoff) {
    final chart = handoff.chart;
    final other = handoff.otherChart;
    final horoscope = handoff.horoscope;
    final forecast = handoff.zodiacForecast;
    if (forecast != null) {
      return buildZodiacForecastPrompt(forecast.sign, forecast);
    }
    if (chart == null) return '';
    if (other != null) {
      return buildSynastryPrompt(chart, other, includeProfileNames: false);
    }
    if (handoff.kind == OracleHandoffKind.horoscope && horoscope != null) {
      return buildHoroscopePrompt(
        chart,
        horoscope,
        includeProfileNames: false,
        transit: handoff.transit,
      );
    }
    return buildNatalPrompt(chart, horoscope, includeProfileNames: false);
  }

  Future<String> answerAstral({
    required OracleHandoff? context,
    String? question,
    required List<ChatMessage> history,
  }) {
    final details = context == null ? '' : astralOracleContext(context);
    return synthesizeNatalReading(
      prompt: [if (details.isNotEmpty) details, ?question].join('\n\n'),
      chart: context?.chart,
      otherChart: context?.otherChart,
      horoscope: context?.horoscope,
      zodiacForecast: context?.zodiacForecast,
      transit: context?.transit,
      history: [
        for (final message in history)
          if (message.role == 'user' && message.text != question) message,
      ],
    );
  }

  /// Deep psychological natal or synastry reading for the ASTRAL to Oracle
  /// handoff. Same dual pipeline (worker, cloud, local) with a deterministic
  /// offline fallback composed from the chart and today's transits.
  Future<String> synthesizeNatalReading({
    required String prompt,
    NatalChart? chart,
    NatalChart? otherChart,
    DailyHoroscopeReport? horoscope,
    ZodiacSign? zodiacSign,
    ZodiacSignForecast? zodiacForecast,
    DailyTransitItem? transit,
    required List<ChatMessage> history,
  }) async {
    final fallback = _natalReadingFallback(
      chart,
      otherChart,
      horoscope,
      zodiacForecast,
      transit,
    );
    if (!hasPrimary && !hasCloud) return fallback;
    final buf = StringBuffer();
    buf.writeln(
      'You are the mindreader.quest oracle: grounded, psychological, modern. '
      'No kitsch, no mysticism.',
    );
    buf.writeln(
      chart == null && zodiacForecast != null
          ? 'The reader brings a daily zodiac forecast without a birth chart.'
          : 'The reader brings their natal astrology data.',
    );
    buf.writeln(prompt);
    if (history.isNotEmpty) {
      buf.writeln('Dialog so far:');
      for (final m in history) {
        buf.writeln('  ${m.role}: ${m.text}');
      }
    }
    buf.writeln(
      'Give a deep, non-fatalistic psychological reading of the chart and '
      'transits. Answer in 3-5 short sentences. Plain text only: no markdown, '
      'no lists.',
    );
    try {
      if (hasPrimary) {
        final text = await _chat(
          url: primaryWorkerUrl,
          key: primaryWorkerKey,
          model: primaryChatModel,
          timeout: primaryTimeout,
          prompt: buf.toString(),
        );
        if (text.isNotEmpty) return text;
      }
      if (hasCloud) {
        final text = await _chat(
          url: cloudUrl,
          key: cloudKey,
          model: cloudModel,
          timeout: cloudTimeout,
          prompt: buf.toString(),
        );
        if (text.isNotEmpty) return text;
      }
    } catch (e) {
      debugPrint(
        'oracle: natal endpoints failed (${e.runtimeType}), local reading',
      );
    }
    return fallback;
  }

  /// Offline natal or synastry reading: the Big Three, the sharpest aspect
  /// and today's loudest transit, closed into grounded guidance.
  String _natalReadingFallback(
    NatalChart? chart,
    NatalChart? otherChart,
    DailyHoroscopeReport? horoscope,
    ZodiacSignForecast? zodiacForecast,
    DailyTransitItem? transit,
  ) {
    if (chart == null && zodiacForecast != null) {
      final sphere = zodiacForecast.focusSpheres.isEmpty
          ? null
          : zodiacForecast.focusSpheres.first;
      return 'Reading ${zodiacForecast.sign.title} '
          '${zodiacForecast.sign.glyph}: '
          '${zodiacForecast.overallTheme} '
          'Energy reads ${zodiacForecast.energyScore}/100. '
          '${sphere == null ? '' : '${sphere.title}: ${sphere.text}'}';
    }
    if (chart != null && otherChart != null) {
      final aspects = NatalCalculatorService.computeSynastryAspects(
        chart,
        otherChart,
      );
      final sharp = aspects.isEmpty ? null : aspects.first;
      final moonA = _find(chart, PlanetId.moon);
      final moonB = _find(otherChart, PlanetId.moon);
      final shared = chart.moonSignUncertain || otherChart.moonSignUncertain
          ? 'one or both Moon signs are uncertain'
          : moonA.sign.element == moonB.sign.element
          ? 'your Moons share the ${moonA.sign.element.label} element, so '
                'emotional rhythms tend to match'
          : 'your Moons sit in ${moonA.sign.title} and ${moonB.sign.title}, '
                'so emotional languages differ and need translation';
      final sharpLine = sharp == null
          ? 'no very tight cross-chart aspect stands out — the bond is built '
                'from temperament, not friction'
          : '${chart.profileName} ${sharp.bodyA.title} ${sharp.type.glyph} '
                '${otherChart.profileName} ${sharp.bodyB.title} is the '
                'sharpest point of contact: ${sharp.type.dynamicLine}.';
      return 'Comparing your charts: $shared. $sharpLine '
          'Work with the harmony where it flows and name the friction where '
          'it asks to be named.';
    }
    if (chart == null) return 'Bring your natal chart and I will read it.';
    final sun = _find(chart, PlanetId.sun);
    final moon = _find(chart, PlanetId.moon);
    final sharp = chart.aspects.firstOrNull;
    final base =
        'Reading the chart of ${chart.profileName}: a ${sun.sign.title} Sun, '
        '${chart.moonSignUncertain ? 'an uncertain Moon sign' : 'a ${moon.sign.title} Moon'}'
        '${chart.timeKnown ? ' and a ${_find(chart, PlanetId.ascendant).sign.title} Ascendant' : ''}.';
    final aspectLine = sharp == null
        ? ''
        : ' The sharpest natal aspect is ${sharp.bodyA.title} '
              '${sharp.type.glyph} ${sharp.bodyB.title}: '
              '${sharp.type.dynamicLine}.';
    final focus = transit ?? horoscope?.transits.firstOrNull;
    final transitLine = focus == null
        ? ''
        : ' ${focus.transitLabel} (${focus.orb.toStringAsFixed(1)}°). ${focus.advice}';
    return '$base$aspectLine$transitLine';
  }
}
