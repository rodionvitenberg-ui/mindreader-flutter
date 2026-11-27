import '../../core/data/lenormand_data.dart';
import '../../core/data/runes_data.dart';
import '../../core/data/tarot_deck_data.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart'
    show StructuredSynthesis;
import '../../state/oracle_session_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../digital_table/spread_history_pane.dart' show spreadTitleForSnapshot;

/// Atmospheric backdrop style for the 9:16 editorial story card.
enum ShareCardAtmosphere { forest, oak, obsidian }

/// One card or rune displayed on the share card.
class ShareCardItem {
  const ShareCardItem({
    required this.card,
    required this.isReversed,
    required this.role,
  });

  final DivinationCard card;
  final bool isReversed;
  final String role;
}

/// Immutable data driving the 9:16 editorial Story card ([ShareCardCanvas]).
class ShareCardPayload {
  const ShareCardPayload({
    required this.title,
    required this.dateLabel,
    required this.moonGlyph,
    required this.moonPhaseName,
    required this.system,
    required this.cards,
    required this.phraseOptions,
    this.subtitle,
    this.defaultAtmosphere = ShareCardAtmosphere.forest,
  });

  final String title;
  final String? subtitle;
  final String dateLabel;
  final String moonGlyph;
  final String moonPhaseName;
  final DivinationSystem system;
  final List<ShareCardItem> cards;
  final List<String> phraseOptions;
  final ShareCardAtmosphere defaultAtmosphere;

  /// Up to 3 focal cards for the 9:16 hero composition (first, center, last
  /// when a spread has 4+ cards so the narrative arc is preserved).
  List<ShareCardItem> get heroCards {
    if (cards.length <= 3) return cards;
    return [cards.first, cards[cards.length ~/ 2], cards.last];
  }

  int get overflowCount => cards.length > 3 ? cards.length - 3 : 0;

  ShareCardItem? get leadCard =>
      cards.isEmpty ? null : cards[cards.length == 3 ? 1 : 0];

  static String _formatDate(DateTime date, AppLanguage lang) {
    final month = AppStrings.t(lang, 'common.month.${date.month}');
    return '$month ${date.day}, ${date.year}';
  }

  static String _distillLine(String raw, {int maxChars = 152}) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    // Prefer ending on the first strong sentence boundary within maxChars.
    final sentenceEnd = RegExp(r'[.!?…]');
    for (final m in sentenceEnd.allMatches(clean)) {
      if (m.end >= 42 && m.end <= maxChars) {
        return clean.substring(0, m.end).trim();
      }
    }
    final cut = clean.lastIndexOf(' ', maxChars - 1);
    final end = cut > 40 ? cut : maxChars - 1;
    return '${clean.substring(0, end).trimRight()}…';
  }

  static List<String> _buildPhrases({
    required List<ShareCardItem> cards,
    StructuredSynthesis? synthesis,
  }) {
    final phrases = <String>[];
    void addCandidate(String? text) {
      if (text == null) return;
      final distilled = _distillLine(text);
      if (distilled.isNotEmpty && !phrases.contains(distilled)) {
        phrases.add(distilled);
      }
    }

    if (synthesis != null) {
      addCandidate(synthesis.verdict);
      addCandidate(synthesis.followUp);
    }

    if (cards.isNotEmpty) {
      final lead = cards[cards.length == 3 ? 1 : 0];
      addCandidate(lead.card.reflection);
      addCandidate(
        lead.isReversed
            ? (lead.card.reversed ?? lead.card.upright)
            : lead.card.upright,
      );
      if (cards.length > 1) {
        final anchor = cards.last;
        addCandidate(anchor.card.reflection);
      }
    }

    if (phrases.isEmpty) {
      phrases.add('Tarot Tree · soshallitbe.cyou');
    }
    return phrases.take(4).toList();
  }

  /// Builds a Story payload directly from the live Digital Table & Oracle session.
  factory ShareCardPayload.fromTable({
    required SpreadController ctrl,
    OracleSessionController? session,
    required AppLanguage lang,
    DateTime? now,
    ShareCardAtmosphere atmosphere = ShareCardAtmosphere.forest,
  }) {
    final at = now ?? DateTime.now();
    final moon = NatalCalculatorService.computeMoonPhase(at);
    final items = <ShareCardItem>[
      for (final slot in ctrl.slots)
        if (slot.card != null && slot.state == SlotState.faceUp)
          ShareCardItem(
            card: slot.card!,
            isReversed: slot.isReversed,
            role: slot.role,
          ),
    ];
    final synthesis = session?.initial;
    final question = ctrl.readingQuestion.trim();
    return ShareCardPayload(
      title: ctrl.spreadLabel,
      subtitle: question.isNotEmpty ? question : null,
      dateLabel: _formatDate(at, lang),
      moonGlyph: moon.glyph,
      moonPhaseName: moon.name,
      system: ctrl.system,
      cards: items,
      phraseOptions: _buildPhrases(cards: items, synthesis: synthesis),
      defaultAtmosphere: atmosphere,
    );
  }

  /// Builds a Story payload from a saved [SpreadSessionSnapshot] in History.
  factory ShareCardPayload.fromSnapshot({
    required SpreadSessionSnapshot snapshot,
    required AppLanguage lang,
  }) {
    final at = DateTime.tryParse(snapshot.timestamp) ?? DateTime.now();
    final moon = NatalCalculatorService.computeMoonPhase(at);
    final items = <ShareCardItem>[];
    for (final c in snapshot.cards) {
      if (c.faceDown) continue;
      final DivinationCard? resolved = switch (snapshot.system) {
        DivinationSystem.tarot =>
          c.cardId >= 0 && c.cardId < tarotDeck.length
              ? TarotDivinationCard(tarotDeck[c.cardId])
              : null,
        DivinationSystem.lenormand =>
          c.cardId >= 0 && c.cardId < lenormandDeck.length
              ? LenormandDivinationCard(lenormandDeck[c.cardId])
              : null,
        DivinationSystem.runes =>
          c.cardId >= 0 && c.cardId < elderFuthark.length
              ? RuneDivinationCard(elderFuthark[c.cardId])
              : null,
      };
      if (resolved != null) {
        items.add(
          ShareCardItem(card: resolved, isReversed: c.reversed, role: c.role),
        );
      }
    }
    final question = snapshot.readingQuestion.trim();
    return ShareCardPayload(
      title: spreadTitleForSnapshot(snapshot),
      subtitle: question.isNotEmpty ? question : null,
      dateLabel: _formatDate(at, lang),
      moonGlyph: moon.glyph,
      moonPhaseName: moon.name,
      system: snapshot.system,
      cards: items,
      phraseOptions: _buildPhrases(
        cards: items,
        synthesis: snapshot.synthesis,
      ),
    );
  }

  /// Builds a Story payload for the 30-second Daily Card ritual.
  factory ShareCardPayload.fromDailyCard({
    required TarotCard card,
    required bool isReversed,
    required AppLanguage lang,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final moon = NatalCalculatorService.computeMoonPhase(at);
    final item = ShareCardItem(
      card: TarotDivinationCard(card),
      isReversed: isReversed,
      role: AppStrings.t(lang, 'share.dailyCard'),
    );
    return ShareCardPayload(
      title: AppStrings.t(lang, 'share.dailyCard'),
      dateLabel: _formatDate(at, lang),
      moonGlyph: moon.glyph,
      moonPhaseName: moon.name,
      system: DivinationSystem.tarot,
      cards: [item],
      phraseOptions: _buildPhrases(cards: [item]),
      defaultAtmosphere: ShareCardAtmosphere.oak,
    );
  }
}
