import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../l10n/app_strings.dart';
import '../models/dealt_card_slot.dart';
import '../models/divination_system.dart';
import '../models/natal_chart.dart';
import '../models/oracle_action.dart';
import '../models/oracle_handoff.dart';
import '../models/spread_type.dart';
import '../models/tarot_card_model.dart';
import '../models/zodiac_forecast.dart';
import 'natal_calculator_service.dart';
import 'reading_relationships.dart';

/// How two adjacent face-up cards relate, elementally.
enum ThreadTone { harmony, conflict, neutral }

class ThreadInfo {
  final int from; // slot index
  final int to; // slot index
  final ThreadTone tone;
  const ThreadInfo({required this.from, required this.to, required this.tone});
}

ThreadTone _tone(ElementalInfluence influence) => switch (influence) {
  ElementalInfluence.reinforcing || ElementalInfluence.supportive => ThreadTone.harmony,
  ElementalInfluence.opposing => ThreadTone.conflict,
  ElementalInfluence.neutral => ThreadTone.neutral,
};

ThreadTone dignityBetweenElements(Element a, Element b) => _tone(influenceOf(a,b));

List<ThreadInfo> _readingThreads(List<DealtCardSlot> slots, List<ReadingRelationship>? relationships) =>
  relationships == null ? computeThreads(slots) : [
    for (final link in relationships)
      if (link.influence != null) ThreadInfo(from: link.from, to: link.to, tone: _tone(link.influence!)),
  ];

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
bool _isShadowRole(String role) {
  final lower = role.toLowerCase();
  final keywords = AppStrings.g('synthesis.shadowKeywords')
      .toLowerCase()
      .split('|');
  return keywords.any(lower.contains);
}

/// The AI's 2-3 spread-specific follow-up Clarifier Questions shown at the
/// end of the synthesis (and after every Clarifier Reading until the
/// clarifier ceiling). Pure and deterministic: each question dynamically
/// references the ACTUAL cards and elemental tensions on the table.
List<String> buildClarifierSuggestions(
  List<DealtCardSlot> slots, {
  int hardMax = 15,
  List<ReadingRelationship>? relationships,
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
    AppStrings.g('synthesis.suggest.resistance', {
      'card': anchor.card!.name,
      'reversed': anchor.isReversed ? ' ${AppStrings.g('common.reversed')}' : '',
    }),
  );

  // 2. The elemental tension: a conflict thread between two concrete
  // cards, or the dominant element pressing on the reading.
  final conflict = [
    for (final t in _readingThreads(slots, relationships))
      if (t.tone == ThreadTone.conflict) t,
  ];
  if (conflict.isNotEmpty) {
    final t = conflict.first;
    suggestions.add(
      AppStrings.g('synthesis.suggest.tension', {
        'a': slots[t.from].card!.name,
        'b': slots[t.to].card!.name,
      }),
    );
  } else {
    final dominant = dominantElements(elementalBalance(slots));
    suggestions.add(
      dominant.isEmpty
          ? AppStrings.g('synthesis.suggest.balanced')
          : AppStrings.g('synthesis.suggest.rebalance', {
              'element': dominant.first.label.toLowerCase(),
            }),
    );
  }

  // 3. The last voice: the newest card keeps something unspoken.
  final last = faceUp.last;
  suggestions.add(
    AppStrings.g('synthesis.suggest.next', {
      'card': last.card!.name,
      'reversed': last.isReversed ? ' ${AppStrings.g('common.reversed')}' : '',
    }),
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
  b.writeln(AppStrings.g('synthesis.balance', {'parts': parts.join(' · ')}));
  if (dominant.isNotEmpty) {
    b.writeln(AppStrings.g('synthesis.dominant', {
      'elements': dominant.map((e) => e.label).join(' + '),
      'traits': dominant.map((e) => e.trait).join(' + '),
    }));
  }
  if (missing.isNotEmpty) {
    b.writeln(AppStrings.g('synthesis.missing', {
      'elements': missing.map((e) => e.label).join(' + '),
      'traits': missing.map((e) => e.trait).join(' + '),
    }));
  }
  final harmonies = threads.where((t) => t.tone == ThreadTone.harmony).length;
  final tensions = threads.where((t) => t.tone == ThreadTone.conflict).length;
  if (threads.isEmpty) return b.toString();
  b.writeln(AppStrings.g('synthesis.threads', {
    'harmonious': harmonies,
    'tensions': tensions,
    'closing': AppStrings.g(
      tensions > 0
          ? 'synthesis.threads.growth'
          : 'synthesis.threads.cooperation',
    ),
  }));
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
  if (!s.isReversed) return AppStrings.g('common.orientation.upright');
  return AppStrings.g(
    s.card?.system == DivinationSystem.runes
        ? 'common.orientation.merkstave'
        : 'common.orientation.reversed',
  );
}

/// Composes the Actionable Verdict from the last card + element context.
String _verdictText(List<DealtCardSlot> slots, Map<Element, int> balance) {
  final faceUp = slots.where((s) => s.card != null).toList();
  final last = faceUp.last;
  final c = last.card!;
  final missing = missingElements(balance);
  final b = StringBuffer();
  final action = c.reflection;
  b.writeln(AppStrings.g('synthesis.verdict', {
    'role': last.role,
    'card': c.name,
    'move': c.upright.split(' — ').last,
  }));
  if (missing.isNotEmpty) {
    b.writeln(AppStrings.g('synthesis.ground', {
      'element': missing.first.label.toLowerCase(),
      'trait': missing.first.trait.toLowerCase(),
    }));
  }
  b.writeln(AppStrings.g('synthesis.todayStep', {'step': action}));
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
    List<ReadingRelationship>? relationships,
}) {
  final faceUp = slots.where((s) => s.card != null).toList();
  if (faceUp.isEmpty) {
    return AppStrings.g('synthesis.flipOne');
  }

  final hasQuestionPairs =
      positionQuestions != null && positionQuestions.isNotEmpty;

  final b = StringBuffer();
  if (profileContext != null && profileContext.isNotEmpty) {
    b.writeln(AppStrings.g('synthesis.profileContext', {'profile': profileContext}));
  }
  if (contextChip != null && contextChip.isNotEmpty) {
    b.writeln(AppStrings.g('synthesis.lens', {'chip': contextChip}));
  }
  b.writeln(AppStrings.g('synthesis.header', {
    'spread': spreadLabel,
    'focus': focusLine,
  }));
  b.writeln();

  for (final s in faceUp) {
    final c = s.card!;
    final held = slotContexts?[s.index];
    if (held != null && held.isNotEmpty) {
      b.writeln(AppStrings.g('synthesis.held', {'held': held}));
    }
    final orientation =
        c.system == DivinationSystem.lenormand ? '' : ' (${orientationWord(s)})';
    if (hasQuestionPairs && s.index < positionQuestions.length) {
      final q = positionQuestions[s.index];
      b.writeln(AppStrings.g('synthesis.questionLine', {
        'n': s.index + 1,
        'question': q,
        'card': c.name,
        'orientation': orientation,
        'meaning': meaningFor(s),
      }));
    } else {
      b.writeln(AppStrings.g('synthesis.slotLine', {
        'role': s.role,
        'card': c.name,
        'orientation': orientation,
        'meaning': meaningFor(s),
      }));
    }
  }

  if (hasQuestionPairs && faceUp.length > 1) {
    final first = faceUp.first.card!;
    final last = faceUp.last.card!;
    b.writeln();
    b.writeln(AppStrings.g('synthesis.overallThread', {
      'count': faceUp.length,
      'first': first.name,
      'last': last.name,
    }));
  }

  final threads = _readingThreads(slots, relationships);
  final harmonies = threads.where((t) => t.tone == ThreadTone.harmony).length;
  final tensions = threads.where((t) => t.tone == ThreadTone.conflict).length;
  b.writeln();
  if (relationships != null) {
    final roles = {for (final slot in faceUp) slot.index: slot.role};
    for (final link in relationships) {
      b.writeln('${roles[link.from]} / ${roles[link.to]} — ${link.explanation}');
    }
  } else if (threads.isEmpty) {
    b.writeln(AppStrings.g('synthesis.standAlone'));
  } else {
    b.writeln(AppStrings.g('synthesis.between', {
      'harmonious': harmonies,
      'tensions': tensions,
    }));
    b.writeln(AppStrings.g(
      tensions > 0 ? 'synthesis.friction' : 'synthesis.cooperate',
    ));
  }

  b.writeln();
  b.writeln(AppStrings.g('synthesis.questionToSit', {
    'question': faceUp.first.card!.reflection,
  }));
  return b.toString();
}


/// Remote synthesis with the same dual AI pipeline as vision:
///
/// Thrown when the Django backend enforces a daily Free/PRO Oracle AI quota (HTTP 429).
class OracleQuotaExceededException implements Exception {
  const OracleQuotaExceededException({
    required this.message,
    this.limit,
    this.resetAt,
  });

  final String message;
  final int? limit;
  final DateTime? resetAt;

  @override
  String toString() => 'OracleQuotaExceededException($message)';
}

/// Resolves `(backendBaseUrl, bearerToken)` for server-proxied AI requests.
typedef BackendAuthResolver = Future<(String?, String?)> Function();

/// 0. SERVER PROXY (preferred) — Django `/api/v1/oracle/complete/`, which keeps
///    all AI keys 100% off the client/PWA and enforces Free/PRO daily quotas.
/// 1. PRIMARY — local/tunneled worker (`PRIMARY_WORKER_URL`, 3500 ms timeout).
/// 2. FALLBACK — direct cloud endpoint (non-Web dev builds only when keys are supplied).
/// 3. OFFLINE SAFETY NET — the deterministic local [synthesizeSpread]
///    engine, so the reading sheet never fails without network.
class OracleSynthesisService {
  OracleSynthesisService({
    http.Client? client,
    BackendAuthResolver? backendAuthResolver,
  })  : _client = client ?? http.Client(),
        backendAuthResolverOverride = backendAuthResolver;

  static BackendAuthResolver? _globalBackendAuthResolver;

  /// Registers the app-wide Django auth resolver once at startup so every
  /// Oracle call routes through the server proxy without exposing API keys.
  static void registerBackendAuth(BackendAuthResolver? resolver) {
    _globalBackendAuthResolver = resolver;
  }

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

  static const serverTimeout = Duration(seconds: 26);
  static const primaryTimeout = Duration(milliseconds: 3500);
  static const cloudTimeout = Duration(seconds: 20);

  final http.Client _client;
  final BackendAuthResolver? backendAuthResolverOverride;

  BackendAuthResolver? get _effectiveBackendAuth =>
      backendAuthResolverOverride ?? _globalBackendAuthResolver;

  bool get hasBackendProxy => _effectiveBackendAuth != null;
  bool get hasPrimary => !kIsWeb && primaryWorkerUrl.isNotEmpty;
  bool get hasCloud => !kIsWeb && cloudUrl.isNotEmpty && cloudKey.isNotEmpty;
  bool get hasAnyRemote => hasBackendProxy || hasPrimary || hasCloud;

  /// The Oracle's voice (4.8): calm, restrained, contextual and symbolic —
  /// grounded psychology, never kitsch or mysticism, and NEVER categorical
  /// medical / financial / legal predictions. Spoken answers stay shorter than
  /// written ones. Shared by every prompt builder so the tone is one place.
  static const oraclePersona = 'You are the Tarot Tree oracle: calm, '
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
    List<ReadingRelationship>? relationships,
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
      relationships: relationships,
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
      relationships: relationships,
    );
    if (prompt == null) return fallback;
    return _completeWithFallback(
      prompt: prompt,
      kind: 'synthesis',
      fallback: fallback,
    );
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
    List<ReadingRelationship>? relationships,
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
      relationships: relationships,
    );
    final faceUp = slots.where((s) => s.card != null).toList();
    final threads = _readingThreads(slots, relationships);
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
    if (!hasAnyRemote) return fallback;
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
    return _completeWithFallback(
      prompt: b.toString(),
      kind: 'clarifier',
      fallback: fallback,
    );
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
    b.writeln(AppStrings.g('synthesis.youAsked', {'question': question}));
    b.writeln(AppStrings.g('synthesis.clarifierAnswers', {
      'card': c.name,
      'orientation': orientationWord(newSlot),
      'meaning': meaningFor(newSlot),
    }));
    final prevNames = [
      for (final s in previous)
        if (s.card != null) s.card!.name,
    ];
    if (prevNames.isNotEmpty) {
      b.writeln(AppStrings.g('synthesis.clarifierBeside', {
        'cards': prevNames.join(', '),
        'unit': c.system.unit,
      }));
    }
    b.writeln(AppStrings.g('synthesis.stepToTake', {'step': c.reflection}));
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
    List<ReadingRelationship>? relationships,
  }) {
    final faceUp = slots.where((s) => s.card != null).toList();
    if (faceUp.isEmpty) return null;
    final hasQuestionPairs =
        positionQuestions != null && positionQuestions.isNotEmpty;
    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('Spread: $spreadLabel (${faceUp.length} ${system.unit}s). '
        '$focusLine');
    if (relationships != null) {
      b.writeln('Applicable relationships (one-based positions): ${jsonEncode(relationships.map((link) => link.toJson()).toList())}. Use only these position pairs for relationship analysis.');
    }
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
          'answers connect, uses applicable relationships, and closes '
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
          'the reader held in mind, uses applicable relationships, and '
          'closes with one sharp Socratic question. '
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
    if (!hasAnyRemote) return fallback;
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
    return _completeWithFallback(
      prompt: b.toString(),
      kind: 'chat',
      fallback: fallback,
    );
  }

  /// G4 — ONE deeper explanation of the mentor moment the reader explicitly
  /// asked about ("Ask the Oracle"). It is never called automatically: the
  /// guide sheet's button is the only entry point. Offline it answers from the
  /// authored cards, the active link and a Socratic question, so the option
  /// works with no model configured.
  Future<String> explainGuideMoment({
    required String moment,
    required String focus,
    required List<DealtCardSlot> slots,
    ReadingRelationship? link,
    int? focusSlot,
  }) async {
    final faceUp = [
      for (final s in slots)
        if (s.state == SlotState.faceUp && s.card != null) s,
    ];
    final fallback = _guideMomentFallback(
      focus: focus,
      slots: faceUp,
      link: link,
      focusSlot: focusSlot,
    );
    if (!hasAnyRemote) return fallback;

    final b = StringBuffer();
    b.writeln(oraclePersona);
    b.writeln('Guided Reading moment: $moment.');
    b.writeln('Spread focus: $focus');
    for (final s in faceUp) {
      final c = s.card!;
      b.writeln('- ${s.role}: ${c.name} (${orientationWord(s)}).');
    }
    if (link != null) {
      b.writeln(
        'The reader just touched the link ${link.fromName} + ${link.toName} '
        '(${link.method}'
        '${link.influence == null ? '' : ', ${link.influence!.name}'}).',
      );
    }
    b.writeln(
      'Explain this moment in 3-5 short sentences: what these cards say '
      'together for the focus of this spread, then one concrete question the '
      'reader can sit with. Plain text only: no markdown, no lists.',
    );
    return _completeWithFallback(
      prompt: b.toString(),
      kind: 'guide',
      fallback: fallback,
    );
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
    if (!hasAnyRemote) {
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

    final raw = await _completeRemote(prompt: b.toString(), kind: 'freeform');
    if (raw != null && raw.isNotEmpty) return parseOracleActionResponse(raw);
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

  /// Localized offline answer for the guide's Oracle option: the focus line,
  /// the face-up cards with their roles, the touched link (if any) and the
  /// focus card's Socratic question — the mentor's voice, never prompt-speak.
  String _guideMomentFallback({
    required String focus,
    required List<DealtCardSlot> slots,
    ReadingRelationship? link,
    int? focusSlot,
  }) {
    if (slots.isEmpty) return AppStrings.g('guide.oracle.empty');
    final cards = slots
        .map(
          (s) => AppStrings.g('guide.oracle.card', {
            'role': s.role,
            'card': s.card!.name,
            'orientation': orientationWord(s),
          }),
        )
        .join('; ');
    final focusCard = slots.firstWhere(
      (s) => s.index == focusSlot,
      orElse: () => slots.last,
    );
    return [
      AppStrings.g('guide.oracle.fallback', {'focus': focus, 'cards': cards}),
      if (link != null)
        AppStrings.g('guide.oracle.link', {'link': link.explanation}),
      AppStrings.g('guide.oracle.question', {
        'question': focusCard.card!.reflection,
      }),
    ].join('\n\n');
  }

  /// Unified completion pipeline: Django server proxy -> local worker -> direct cloud.
  /// Propagates [OracleQuotaExceededException] so the UI can present the PRO sheet.
  Future<String?> _completeRemote({
    required String prompt,
    required String kind,
    String? systemPrompt,
  }) async {
    if (hasBackendProxy) {
      final serverText = await _completeViaBackend(
        prompt: prompt,
        kind: kind,
        systemPrompt: systemPrompt,
      );
      if (serverText != null && serverText.isNotEmpty) return serverText;
    }
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
        debugPrint(
          'oracle: primary worker unreachable (${e.runtimeType}), falling back',
        );
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
        debugPrint(
          'oracle: cloud endpoint failed (${e.runtimeType}), falling back',
        );
      }
    }
    return null;
  }

  Future<String> _completeWithFallback({
    required String prompt,
    required String kind,
    required String fallback,
    String? systemPrompt,
  }) async {
    final text = await _completeRemote(
      prompt: prompt,
      kind: kind,
      systemPrompt: systemPrompt,
    );
    return (text != null && text.isNotEmpty) ? text : fallback;
  }

  /// Route 0 (preferred): Django `/api/v1/oracle/complete/` proxy.
  Future<String?> _completeViaBackend({
    required String prompt,
    required String kind,
    String? systemPrompt,
  }) async {
    final resolver = _effectiveBackendAuth;
    if (resolver == null) return null;
    try {
      final (baseUrl, token) = await resolver();
      final cleanBase = baseUrl?.trim() ?? '';
      final cleanToken = token?.trim() ?? '';
      if (cleanBase.isEmpty || cleanToken.isEmpty) return null;

      final uri = Uri.parse(cleanBase).resolve('/api/v1/oracle/complete/');
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $cleanToken',
            },
            body: jsonEncode({
              'prompt': prompt,
              'kind': kind,
              if (systemPrompt != null && systemPrompt.isNotEmpty)
                'systemPrompt': systemPrompt,
            }),
          )
          .timeout(serverTimeout);

      if (response.statusCode == 429) {
        Map<String, dynamic>? body;
        try {
          final parsed = jsonDecode(utf8.decode(response.bodyBytes));
          if (parsed is Map<String, dynamic>) body = parsed;
        } catch (_) {}
        if (body?['code'] == 'quota_exceeded') {
          throw OracleQuotaExceededException(
            message: (body?['detail'] as String?) ?? 'Daily Oracle quota reached.',
            limit: body?['limit'] is int ? body!['limit'] as int : null,
            resetAt: body?['resetAt'] is String
                ? DateTime.tryParse(body!['resetAt'] as String)
                : null,
          );
        }
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('oracle: backend proxy responded ${response.statusCode}');
        return null;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic> && data['text'] is String) {
        return (data['text'] as String).replaceAll('```', '').trim();
      }
      return null;
    } on OracleQuotaExceededException {
      rethrow;
    } catch (e) {
      debugPrint(
        'oracle: backend proxy unavailable (${e.runtimeType}), falling back',
      );
      return null;
    }
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

  static String _describe(NatalPlanetPosition p) => AppStrings.g(
    'astral.summary.describe',
    {
      'planet': p.planet.title,
      'glyph': p.sign.glyph,
      'sign': p.sign.title,
      'degree': p.formattedDegree,
      'house': p.house == null
          ? ''
          : AppStrings.g('astral.summary.inHouse', {'house': p.house}),
    },
  );

  static String _mainPlacements(NatalChart chart) => [
    _describe(_find(chart, PlanetId.sun)),
    if (chart.timeKnown)
      _describe(_find(chart, PlanetId.moon))
    else if (!chart.moonSignUncertain)
      AppStrings.g('astral.summary.moonIn', {
        'sign': _find(chart, PlanetId.moon).sign.title,
      })
    else
      AppStrings.g('astral.summary.moonUncertain'),
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
  /// shown as the user's message and reused as the AI prompt.
  static String buildNatalPrompt(
    NatalChart chart,
    DailyHoroscopeReport? horoscope, {
    bool includeProfileNames = true,
  }) {
    final sharp = chart.aspects.firstOrNull;
    final buf = StringBuffer()
      ..writeln(AppStrings.g('astral.summary.natalProfile', {
        'name': includeProfileNames ? chart.profileName : 'A',
      }))
      ..writeln(
        chart.timeKnown
            ? AppStrings.g('astral.summary.bigThree', {
                'placements': _mainPlacements(chart),
              })
            : AppStrings.g('astral.summary.availablePlacements', {
                'placements': _mainPlacements(chart),
              }),
      )
      ..writeln(AppStrings.g('astral.summary.dominantElement', {
        'element': _dominantElementOf(chart).label,
      }));
    if (chart.timeKnown) {
      buf.writeln(AppStrings.g('astral.summary.houseSystem', {
        'system': chart.houseSystem.label,
      }));
    }
    if (sharp != null) {
      buf.writeln(AppStrings.g('astral.summary.sharpestAspect', {
        'a': sharp.bodyA.title,
        'glyph': sharp.type.glyph,
        'b': sharp.bodyB.title,
        'orb': sharp.orb.toStringAsFixed(1),
      }));
    }
    if (horoscope != null) {
      buf.writeln(AppStrings.g('astral.summary.themeMoon', {
        'theme': horoscope.overallTheme,
        'moon': _moonLocation(horoscope),
      }));
      for (final t in horoscope.transits.take(3)) {
        buf.writeln(AppStrings.g('astral.summary.transitBullet', {
          'label': t.transitLabel,
          'orb': t.orb.toStringAsFixed(1),
        }));
      }
    }
    return buf.toString().trim();
  }

  /// A structured daily-horoscope summary for the active natal profile.
  static String buildHoroscopePrompt(
    NatalChart chart,
    DailyHoroscopeReport report, {
    bool includeProfileNames = true,
    DailyTransitItem? transit,
  }) {
    final buf = StringBuffer();
    final d = report.date.toLocal();
    final date =
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
    buf.writeln(AppStrings.g('astral.summary.horoscopeTitle', {
      'name': includeProfileNames ? chart.profileName : 'A',
      'date': date,
    }));
    buf.writeln(AppStrings.g('astral.summary.moonLine', {
      'glyph': report.moonPhaseGlyph,
      'phase': report.moonPhaseName,
      'illumination': (report.moonIllumination * 100).round(),
      'moon': _moonLocation(report),
    }));
    buf.writeln(AppStrings.g('astral.summary.energy', {
      'score': report.energyScore,
      'theme': report.overallTheme,
    }));
    for (final f in report.focusSpheres) {
      buf.writeln(AppStrings.g('astral.summary.sphere', {
        'title': f.title,
        'text': f.text,
      }));
    }
    if (!chart.timeKnown) {
      buf.writeln(AppStrings.g('astral.summary.birthTimeUnknown'));
    }
    if (transit != null) {
      final timing = [
        if (transit.closestAt != null)
          AppStrings.g('astral.summary.closestAt', {
            'date': transit.closestAt!.toUtc(),
          }),
        if (transit.activeFrom != null)
          AppStrings.g('astral.summary.activeFrom', {
            'date': transit.activeFrom!.toUtc(),
          }),
        if (transit.activeUntil != null)
          AppStrings.g('astral.summary.activeUntil', {
            'date': transit.activeUntil!.toUtc(),
          }),
      ];
      buf.writeln(AppStrings.g('astral.summary.selectedTransit', {
        'label': transit.transitLabel,
        'orb': transit.orb.toStringAsFixed(2),
        'timing': timing.join(', '),
      }));
    }
    for (final t in report.transits.take(4)) {
      buf.writeln(AppStrings.g('astral.summary.transitBullet', {
        'label': t.transitLabel,
        'orb': t.orb.toStringAsFixed(1),
      }));
    }
    return buf.toString().trim();
  }

  static String _moonLocation(DailyHoroscopeReport report) =>
      AppStrings.g('astral.summary.moonLocation', {
        'house': report.transitingMoonHouse == null
            ? ''
            : AppStrings.g('astral.summary.inHouse', {
                'house': report.transitingMoonHouse,
              }),
        'sign': report.transitingMoonSign.title,
      });

  /// A structured quick-sign forecast prompt — no natal chart required.
  static String buildZodiacForecastPrompt(
    ZodiacSign sign,
    ZodiacSignForecast forecast,
  ) {
    final buf = StringBuffer();
    buf.writeln(AppStrings.g('astral.summary.zodiacTitle', {
      'sign': sign.title,
      'glyph': sign.glyph,
      'date': forecast.date.toUtc(),
    }));
    buf.writeln(AppStrings.g('astral.summary.moonLine', {
      'glyph': forecast.moonPhaseGlyph,
      'phase': forecast.moonPhaseName,
      'illumination': (forecast.moonIllumination * 100).round(),
      'moon': AppStrings.g('astral.summary.zodiacMoonInline', {
        'sign': forecast.transitingMoonSign.title,
        'house': forecast.solarMoonHouse,
      }),
    }));
    buf.writeln(AppStrings.g('astral.summary.energy', {
      'score': forecast.energyScore,
      'theme': forecast.overallTheme,
    }));
    for (final f in forecast.focusSpheres) {
      buf.writeln(AppStrings.g('astral.summary.sphere', {
        'title': f.title,
        'text': f.text,
      }));
    }
    return buf.toString().trim();
  }

  /// A structured synastry summary for the compare-two-charts handoff.
  static String buildSynastryPrompt(
    NatalChart a,
    NatalChart b, {
    bool includeProfileNames = true,
  }) {
    final nameA = includeProfileNames
        ? a.profileName
        : AppStrings.g('astral.summary.profileA');
    final nameB = includeProfileNames
        ? b.profileName
        : AppStrings.g('astral.summary.profileB');
    final buf = StringBuffer()
      ..writeln(AppStrings.g('astral.summary.synastry', {
        'a': nameA,
        'b': nameB,
      }))
      ..writeln(AppStrings.g('astral.summary.placements', {
        'name': nameA,
        'placements': _mainPlacements(a),
      }))
      ..writeln(AppStrings.g('astral.summary.placements', {
        'name': nameB,
        'placements': _mainPlacements(b),
      }));
    if (!a.timeKnown || !b.timeKnown) {
      buf.writeln(AppStrings.g('astral.summary.birthTimeUnknownSynastry'));
    }
    final aspects = NatalCalculatorService.computeSynastryAspects(a, b);
    buf.writeln(AppStrings.g('astral.summary.tightestAspects'));
    for (final aspect in aspects.take(5)) {
      buf.writeln(AppStrings.g('astral.summary.aspectLine', {
        'a': nameA,
        'bodyA': aspect.bodyA.title,
        'glyph': aspect.type.glyph,
        'b': nameB,
        'bodyB': aspect.bodyB.title,
        'orb': aspect.orb.toStringAsFixed(1),
      }));
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
    if (!hasAnyRemote) return fallback;
    final buf = StringBuffer();
    buf.writeln(
      'You are the Tarot Tree oracle: grounded, psychological, modern. '
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
    return _completeWithFallback(
      prompt: buf.toString(),
      kind: 'astral',
      fallback: fallback,
    );
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
      return AppStrings.g('astral.fallback.zodiac', {
        'sign': zodiacForecast.sign.title,
        'glyph': zodiacForecast.sign.glyph,
        'theme': zodiacForecast.overallTheme,
        'score': zodiacForecast.energyScore,
        'sphere': sphere == null
            ? ''
            : AppStrings.g('astral.fallback.zodiacSphere', {
                'title': sphere.title,
                'text': sphere.text,
              }),
      });
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
          ? AppStrings.g('astral.fallback.moonsUncertain')
          : moonA.sign.element == moonB.sign.element
          ? AppStrings.g('astral.fallback.moonsSame', {
              'element': moonA.sign.element.label,
            })
          : AppStrings.g('astral.fallback.moonsDifferent', {
              'a': moonA.sign.title,
              'b': moonB.sign.title,
            });
      final sharpLine = sharp == null
          ? AppStrings.g('astral.fallback.noSharpAspect')
          : AppStrings.g('astral.fallback.sharpPoint', {
              'a': chart.profileName,
              'bodyA': sharp.bodyA.title,
              'glyph': sharp.type.glyph,
              'b': otherChart.profileName,
              'bodyB': sharp.bodyB.title,
              'line': sharp.type.dynamicLine,
            });
      return AppStrings.g('astral.fallback.synastry', {
        'shared': shared,
        'sharp': sharpLine,
      });
    }
    if (chart == null) return AppStrings.g('astral.fallback.needChart');
    final sun = _find(chart, PlanetId.sun);
    final moon = _find(chart, PlanetId.moon);
    final sharp = chart.aspects.firstOrNull;
    final base = AppStrings.g('astral.fallback.chart', {
      'name': chart.profileName,
      'sun': sun.sign.title,
      'moon': chart.moonSignUncertain
          ? AppStrings.g('astral.fallback.moonUncertain')
          : AppStrings.g('astral.fallback.moon', {'moon': moon.sign.title}),
      'asc': chart.timeKnown
          ? AppStrings.g('astral.fallback.ascendant', {
              'asc': _find(chart, PlanetId.ascendant).sign.title,
            })
          : '',
    });
    final aspectLine = sharp == null
        ? ''
        : AppStrings.g('astral.fallback.sharpNatal', {
            'a': sharp.bodyA.title,
            'glyph': sharp.type.glyph,
            'b': sharp.bodyB.title,
            'line': sharp.type.dynamicLine,
          });
    final focus = transit ?? horoscope?.transits.firstOrNull;
    final transitLine = focus == null
        ? ''
        : AppStrings.g('astral.fallback.transit', {
            'label': focus.transitLabel,
            'orb': focus.orb.toStringAsFixed(1),
            'advice': focus.advice,
          });
    return '$base$aspectLine$transitLine';
  }
}
