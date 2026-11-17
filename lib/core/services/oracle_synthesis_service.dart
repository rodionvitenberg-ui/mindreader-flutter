import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

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

/// Composes the Actionable Verdict from the last card + element context.
String _verdictText(List<DealtCardSlot> slots, Map<Element, int> balance) {
  final faceUp = slots.where((s) => s.card != null).toList();
  final last = faceUp.last;
  final c = last.card!;
  final missing = missingElements(balance);
  final b = StringBuffer();
  final action = c.socratic;
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
    final held = slotContexts?[s.index];
    if (held != null && held.isNotEmpty) {
      b.writeln('You held before drawing: $held.');
    }
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

  /// Cohesive spread synthesis: worker → Gemini Flash → local engine.
  /// Never throws; the local synthesis is the guaranteed result.
  Future<String> synthesize({
    required List<DealtCardSlot> slots,
    required SpreadType type,
    String? contextChip,
    Map<int, String>? slotContexts,
  }) async {
    final fallback = synthesizeSpread(
      slots,
      type,
      contextChip: contextChip,
      slotContexts: slotContexts,
    );
    final prompt = _buildPrompt(slots, type, contextChip, slotContexts);
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
    required SpreadType type,
    String? contextChip,
    Map<int, String>? slotContexts,
  }) async {
    final narrative = await synthesize(
      slots: slots,
      type: type,
      contextChip: contextChip,
      slotContexts: slotContexts,
    );
    final faceUp = slots.where((s) => s.card != null).toList();
    final threads = computeThreads(slots);
    final balance = elementalBalance(slots);
    return StructuredSynthesis(
      narrative: narrative,
      elementalAlchemy: _alchemyText(slots, threads),
      verdict: _verdictText(slots, balance),
      followUp: faceUp.last.card!.socratic,
    );
  }

  /// A single "Clarifier Expansion" chapter: answers the follow-up
  /// [question] with the newly pulled clarifier card in the light of the
  /// cards already on the table. Same dual pipeline, local fallback.
  Future<String> synthesizeClarifier({
    required String question,
    required DealtCardSlot newSlot,
    required List<DealtCardSlot> previous,
  }) async {
    final c = newSlot.card;
    if (c == null) return '';
    final fallback = _clarifierFallback(question, newSlot, previous);
    if (!hasPrimary && !hasCloud) return fallback;
    final b = StringBuffer();
    b.writeln('You are the mindreader.quest oracle: grounded, psychological, '
        'modern. No kitsch, no mysticism.');
    b.writeln('The reader already has this reading on the table:');
    for (final s in previous) {
      final pc = s.card;
      if (pc == null) continue;
      b.writeln('- ${s.role}: ${pc.name} '
          '${s.isReversed ? '(reversed)' : '(upright)'}, '
          'element ${pc.element.label}');
    }
    b.writeln('The reader now asks a follow-up question: $question');
    b.writeln('They pulled one clarifier card: ${c.name} '
        '${newSlot.isReversed ? '(reversed)' : '(upright)'}, '
        'element ${c.element.label}. '
        '${newSlot.isReversed ? c.reversed : c.upright}');
    b.writeln('Write ONE short paragraph (3-5 sentences) that answers the '
        'follow-up question through this card IN THE CONTEXT of the cards '
        'already on the table, and close with one concrete step. '
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
  /// the previous cards, closed with the card's own Socratic question.
  String _clarifierFallback(
    String question,
    DealtCardSlot newSlot,
    List<DealtCardSlot> previous,
  ) {
    final c = newSlot.card!;
    final b = StringBuffer();
    b.writeln('You asked: $question');
    b.writeln(
      '${c.name} (${newSlot.isReversed ? 'reversed' : 'upright'}) answers '
      'with: ${newSlot.isReversed ? c.reversed : c.upright}',
    );
    final prevNames = [
      for (final s in previous)
        if (s.card != null) s.card!.name,
    ];
    if (prevNames.isNotEmpty) {
      b.writeln('Read beside ${prevNames.join(', ')} already on the table, '
          'this card tightens the reading rather than replacing it.');
    }
    b.writeln('The step to take: ${c.socratic}');
    return b.toString();
  }
  static String? _buildPrompt(
    List<DealtCardSlot> slots,
    SpreadType type,
    String? contextChip,
    Map<int, String>? slotContexts,
  ) {
    final faceUp = slots.where((s) => s.card != null).toList();
    if (faceUp.isEmpty) return null;
    final b = StringBuffer();
    b.writeln('You are the mindreader.quest oracle: grounded, psychological, '
        'modern. No fortune-teller kitsch, no mysticism, no predictions — '
        'reflective insight only.');
    b.writeln('Spread: ${type.label} (${type.cardCount} cards). '
        '${type.focusLine}');
    if (contextChip != null && contextChip.isNotEmpty) {
      b.writeln('Reader lens: $contextChip.');
    }
    b.writeln('Cards in reading order:');
    for (final s in faceUp) {
      final c = s.card!;
      final held = slotContexts?[s.index];
      if (held != null && held.isNotEmpty) {
        b.writeln('  The reader held in mind before drawing: $held.');
      }
      b.writeln('- ${s.role}: ${c.name} '
          '${s.isReversed ? '(reversed)' : '(upright)'}, '
          'element ${c.element.label}. '
          '${s.isReversed ? c.reversed : c.upright}');
    }
    b.writeln('Write a cohesive synthesis of 2-3 short paragraphs that '
        'weaves each card\'s meaning into its slot role AND weaves in what '
        'the reader held in mind, names the elemental harmonies and '
        'tensions, and closes with one sharp Socratic question. '
        'Plain text only: no markdown, no lists, no headers.');
    return b.toString();
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
                'content': 'You are a grounded psychological tarot oracle.',
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
}
