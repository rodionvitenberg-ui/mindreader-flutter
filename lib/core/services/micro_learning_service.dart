import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../data/lenormand_data.dart';
import '../data/runes_data.dart';
import '../data/tarot_deck_data.dart';
import '../l10n/app_strings.dart';
import '../models/divination_card.dart';
import '../models/divination_system.dart';
import '../models/tarot_card_model.dart';
import 'reading_relationships.dart';

/// Drill modes for offline 2-minute micro-learning (zero API calls).
enum DrillMode { mixed, cardMeaning, elementMatch, twoCardPair }

/// One curated 2-card Tarot combination loaded from `assets/data/tarot_pair_drills.json`.
class TarotPairDrill {
  const TarotPairDrill({
    required this.id,
    required this.cardA,
    required this.cardB,
    required this.meaningKey,
  });

  final String id;
  final int cardA;
  final int cardB;
  final String meaningKey;

  static List<TarotPairDrill> parseJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final list = decoded['pairs'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic> &&
            item['id'] is String &&
            item['a'] is int &&
            item['b'] is int &&
            item['meaningKey'] is String)
          TarotPairDrill(
            id: item['id'] as String,
            cardA: item['a'] as int,
            cardB: item['b'] as int,
            meaningKey: item['meaningKey'] as String,
          ),
    ];
  }
}

/// One self-contained offline quiz question rendered on the training table.
class MicroLearningQuestion {
  const MicroLearningQuestion({
    required this.mode,
    required this.system,
    required this.cards,
    required this.reversedFlags,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.elementOptions,
  });

  final DrillMode mode;
  final DivinationSystem system;
  final List<DivinationCard> cards;
  final List<bool> reversedFlags;
  final String prompt;
  final List<String> options;
  final List<Element>? elementOptions;
  final int correctIndex;
  final String explanation;

  String get primaryCardKey => '${system.name}:${cards.first.id}';
}

/// Pure offline generator for 2-minute micro-learning drills (6 questions per
/// session). Uses only local card datasets + `assets/data/tarot_pair_drills.json`.
class MicroLearningService {
  MicroLearningService._();

  static const String pairDrillsAssetPath = 'assets/data/tarot_pair_drills.json';
  static List<TarotPairDrill>? _cachedPairs;

  static Future<List<TarotPairDrill>> loadTarotPairs() async {
    if (_cachedPairs != null) return _cachedPairs!;
    try {
      final raw = await rootBundle.loadString(pairDrillsAssetPath);
      _cachedPairs = TarotPairDrill.parseJson(raw);
      return _cachedPairs!;
    } catch (_) {
      return const [];
    }
  }

  static List<DivinationCard> _deckFor(DivinationSystem system) => switch (system) {
    DivinationSystem.tarot => [for (final c in tarotDeck) TarotDivinationCard(c)],
    DivinationSystem.lenormand => [
      for (final c in lenormandDeck) LenormandDivinationCard(c),
    ],
    DivinationSystem.runes => [
      for (final r in elderFuthark) RuneDivinationCard(r),
    ],
  };

  /// Generates [count] offline questions for [system] and [mode].
  static List<MicroLearningQuestion> generateSession({
    required DivinationSystem system,
    required DrillMode mode,
    required AppLanguage lang,
    List<TarotPairDrill> tarotPairs = const [],
    int count = 6,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final deck = _deckFor(system);
    final questions = <MicroLearningQuestion>[];
    final usedPrimaryIds = <int>{};

    for (var i = 0; i < count; i++) {
      final effectiveMode = _resolveQuestionMode(
        requested: mode,
        system: system,
        index: i,
      );
      final q = switch (effectiveMode) {
        DrillMode.cardMeaning => _buildMeaningQuestion(
          system: system,
          deck: deck,
          lang: lang,
          random: random,
          usedIds: usedPrimaryIds,
        ),
        DrillMode.elementMatch => _buildElementQuestion(
          system: system,
          deck: deck,
          lang: lang,
          random: random,
          usedIds: usedPrimaryIds,
        ),
        DrillMode.twoCardPair || DrillMode.mixed => _buildPairQuestion(
          system: system,
          deck: deck,
          lang: lang,
          tarotPairs: tarotPairs,
          random: random,
          preferDignity: i.isOdd,
        ),
      };
      questions.add(q);
    }
    return questions;
  }

  static DrillMode _resolveQuestionMode({
    required DrillMode requested,
    required DivinationSystem system,
    required int index,
  }) {
    if (requested == DrillMode.elementMatch &&
        system == DivinationSystem.lenormand) {
      // Lenormand uses playing-card suits & pairs, not the 4 elements.
      return index.isEven ? DrillMode.cardMeaning : DrillMode.twoCardPair;
    }
    if (requested != DrillMode.mixed) return requested;
    if (system == DivinationSystem.lenormand) {
      return index.isEven ? DrillMode.cardMeaning : DrillMode.twoCardPair;
    }
    return switch (index % 3) {
      0 => DrillMode.cardMeaning,
      1 => DrillMode.elementMatch,
      _ => DrillMode.twoCardPair,
    };
  }

  static DivinationCard _pickUnused(
    List<DivinationCard> deck,
    Random random,
    Set<int> usedIds,
  ) {
    final pool = [
      for (final c in deck)
        if (!usedIds.contains(c.id)) c,
    ];
    final list = pool.isNotEmpty ? pool : deck;
    final picked = list[random.nextInt(list.length)];
    usedIds.add(picked.id);
    return picked;
  }

  static String _cardSummary(DivinationCard card, {required bool reversed}) {
    if (reversed && card.reversed != null) return card.reversed!;
    return card.upright;
  }

  static MicroLearningQuestion _buildMeaningQuestion({
    required DivinationSystem system,
    required List<DivinationCard> deck,
    required AppLanguage lang,
    required Random random,
    required Set<int> usedIds,
  }) {
    final target = _pickUnused(deck, random, usedIds);
    final isReversed = target.supportsReversal && random.nextInt(4) == 0;
    final correctText = _cardSummary(target, reversed: isReversed);

    final distractorPool = [
      for (final c in deck)
        if (c.id != target.id) c,
    ]..shuffle(random);

    final options = <String>[correctText];
    for (final d in distractorPool) {
      final candidate = _cardSummary(
        d,
        reversed: isReversed && d.supportsReversal,
      );
      if (candidate != correctText && !options.contains(candidate)) {
        options.add(candidate);
        if (options.length == 4) break;
      }
    }
    options.shuffle(random);

    return MicroLearningQuestion(
      mode: DrillMode.cardMeaning,
      system: system,
      cards: [target],
      reversedFlags: [isReversed],
      prompt: AppStrings.t(
        lang,
        isReversed
            ? 'training.prompt.meaningReversed'
            : 'training.prompt.meaningUpright',
      ),
      options: options,
      correctIndex: options.indexOf(correctText),
      explanation: '${target.name}: ${target.keywords.join(' · ')}',
    );
  }

  static MicroLearningQuestion _buildElementQuestion({
    required DivinationSystem system,
    required List<DivinationCard> deck,
    required AppLanguage lang,
    required Random random,
    required Set<int> usedIds,
  }) {
    final target = _pickUnused(deck, random, usedIds);
    final elements = List<Element>.from(Element.values);
    final options = [
      for (final e in elements) AppStrings.t(lang, 'almanac.${e.name}'),
    ];
    final correctIndex = elements.indexOf(target.element);
    return MicroLearningQuestion(
      mode: DrillMode.elementMatch,
      system: system,
      cards: [target],
      reversedFlags: const [false],
      prompt: AppStrings.t(lang, 'training.prompt.element'),
      options: options,
      elementOptions: elements,
      correctIndex: correctIndex,
      explanation: '${target.name} · ${target.categoryLabel}',
    );
  }

  static MicroLearningQuestion _buildPairQuestion({
    required DivinationSystem system,
    required List<DivinationCard> deck,
    required AppLanguage lang,
    required List<TarotPairDrill> tarotPairs,
    required Random random,
    required bool preferDignity,
  }) {
    // 1. Tarot curated JSON pair meaning drill
    if (system == DivinationSystem.tarot &&
        tarotPairs.length >= 4 &&
        !preferDignity) {
      final pair = tarotPairs[random.nextInt(tarotPairs.length)];
      final cardA = TarotDivinationCard(tarotDeck[pair.cardA]);
      final cardB = TarotDivinationCard(tarotDeck[pair.cardB]);
      final correct = AppStrings.t(lang, pair.meaningKey);
      final others = [
        for (final p in tarotPairs)
          if (p.id != pair.id) AppStrings.t(lang, p.meaningKey),
      ]..shuffle(random);
      final options = <String>[correct, ...others.take(3)]..shuffle(random);
      return MicroLearningQuestion(
        mode: DrillMode.twoCardPair,
        system: system,
        cards: [cardA, cardB],
        reversedFlags: const [false, false],
        prompt: AppStrings.t(lang, 'training.prompt.pairMeaning'),
        options: options,
        correctIndex: options.indexOf(correct),
        explanation: '${cardA.name} + ${cardB.name}',
      );
    }

    // 2. Lenormand authentic traditional pair combinations
    if (system == DivinationSystem.lenormand) {
      final authored = <({
        LenormandDivinationCard a,
        LenormandDivinationCard b,
        String line,
      })>[];
      for (final ca in deck.cast<LenormandDivinationCard>()) {
        for (final cb in deck.cast<LenormandDivinationCard>()) {
          if (ca.id == cb.id) continue;
          final combo = lenormandCombination(ca, cb);
          if (combo != null && combo.trim().isNotEmpty) {
            authored.add((a: ca, b: cb, line: combo));
          }
        }
      }
      if (authored.length >= 4) {
        final target = authored[random.nextInt(authored.length)];
        final others = [
          for (final item in authored)
            if (item.line != target.line) item.line,
        ]..shuffle(random);
        final options = <String>[target.line];
        for (final o in others) {
          if (!options.contains(o)) options.add(o);
          if (options.length == 4) break;
        }
        options.shuffle(random);
        return MicroLearningQuestion(
          mode: DrillMode.twoCardPair,
          system: system,
          cards: [target.a, target.b],
          reversedFlags: const [false, false],
          prompt: AppStrings.t(lang, 'training.prompt.pairMeaning'),
          options: options,
          correctIndex: options.indexOf(target.line),
          explanation: '${target.a.name} + ${target.b.name}',
        );
      }
    }

    // 3. Golden Dawn elemental dignity / elemental interplay for 2 cards/runes
    final a = deck[random.nextInt(deck.length)];
    var b = deck[random.nextInt(deck.length)];
    if (b.id == a.id && deck.length > 1) {
      b = deck[(deck.indexOf(a) + 1) % deck.length];
    }
    final influence = influenceOf(a.element, b.element);
    final allInfluences = ElementalInfluence.values;
    final options = [
      for (final inf in allInfluences)
        AppStrings.t(lang, 'training.dignity.${inf.name}'),
    ];
    return MicroLearningQuestion(
      mode: DrillMode.twoCardPair,
      system: system,
      cards: [a, b],
      reversedFlags: const [false, false],
      prompt: AppStrings.t(lang, 'training.prompt.pairDignity'),
      options: options,
      correctIndex: allInfluences.indexOf(influence),
      explanation:
          '${AppStrings.t(lang, 'almanac.${a.element.name}')} + ${AppStrings.t(lang, 'almanac.${b.element.name}')}',
    );
  }
}
