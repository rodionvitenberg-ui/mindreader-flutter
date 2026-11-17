import 'divination_system.dart';
import 'lenormand_card.dart';
import 'rune_stone.dart';
import 'tarot_card_model.dart';

/// One drawn divination piece on the Digital Table — the sealed union over
/// the three systems. Every consumer (threads, oracle, history, inspectors)
/// works against this single interface instead of system-specific types.
sealed class DivinationCard {
  const DivinationCard({required this.system});

  /// Which system this piece belongs to.
  final DivinationSystem system;

  /// Stable identity within its own system (0..77 tarot, 0..35 lenormand,
  /// 0..23 runes) — serialization key for history.
  int get id;

  String get name;

  /// Compact positional label: 'XIII' / 'Ace' for tarot, '9♥' for
  /// Lenormand, the glyph 'ᚠ' for runes.
  String get shortLabel;

  /// Category line: 'MAJOR ARCANA' / 'WANDS · FIRE', 'HEARTS · EMOTION',
  /// 'FREYR’S AETT'.
  String get categoryLabel;

  Element get element;
  List<String> get keywords;
  String get upright;

  /// Reversed/merkstave meaning — null when this piece NEVER reverses
  /// (all Lenormand cards, the 8 symmetrical runes).
  String? get reversed;

  /// The one sharp question / pair-whisper / invocation the oracle closes
  /// a reading with.
  String get reflection;

  /// True when a reversed (merkstave) meaning exists for this piece.
  bool get supportsReversal => reversed != null;
}

/// Tarot: wraps the existing 78-card [TarotCard] dataset untouched.
final class TarotDivinationCard extends DivinationCard {
  const TarotDivinationCard(this.card)
      : super(system: DivinationSystem.tarot);

  final TarotCard card;

  @override
  int get id => card.id;

  @override
  String get name => card.name;

  @override
  String get shortLabel => card.positionLabel;

  @override
  String get categoryLabel => card.arcana == Arcana.major
      ? 'MAJOR ARCANA'
      : '${card.suit!.label.toUpperCase()} · '
          '${card.element.label.toUpperCase()}';

  @override
  Element get element => card.element;

  @override
  List<String> get keywords => card.keywords;

  @override
  String get upright => card.upright;

  @override
  String? get reversed => card.reversed;

  @override
  String get reflection => card.socratic;
}

/// Lenormand: always upright, read in pairs.
final class LenormandDivinationCard extends DivinationCard {
  const LenormandDivinationCard(this.card)
      : super(system: DivinationSystem.lenormand);

  final LenormandCard card;

  @override
  int get id => card.id;

  @override
  String get name => card.name;

  @override
  String get shortLabel => card.insetLabel;

  @override
  String get categoryLabel => card.suitLine;

  @override
  Element get element => card.element;

  @override
  List<String> get keywords => card.keywords;

  @override
  String get upright => card.meaning;

  @override
  String? get reversed => null; // Lenormand never reads reversed.

  @override
  String get reflection =>
      'Which card beside ${card.name} is whispering its true story?';
}

/// Elder Futhark rune stone: merkstave exists only for non-symmetrical runes.
final class RuneDivinationCard extends DivinationCard {
  const RuneDivinationCard(this.stone)
      : super(system: DivinationSystem.runes);

  final RuneStone stone;

  @override
  int get id => stone.id;

  @override
  String get name => stone.name;

  @override
  String get shortLabel => stone.glyph;

  @override
  String get categoryLabel => '${stone.aett.title.toUpperCase()} · '
      '${stone.element.label.toUpperCase()}';

  @override
  Element get element => stone.element;

  @override
  List<String> get keywords => stone.keywords;

  @override
  String get upright => stone.upright;

  @override
  String? get reversed => stone.merkstave;

  @override
  String get reflection =>
      'Where in your life is the force of ${stone.name} (${stone.glyph}) '
      'asking to be named aloud?';
}
