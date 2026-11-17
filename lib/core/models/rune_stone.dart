import 'tarot_card_model.dart';

/// The three Elder Futhark Aetts — each holds 8 runes.
enum RuneAett { freyr, hagal, tyr }

extension RuneAettX on RuneAett {
  String get label => switch (this) {
        RuneAett.freyr => 'Freyr',
        RuneAett.hagal => 'Hagal',
        RuneAett.tyr => 'Tyr',
      };

  String get title => switch (this) {
        RuneAett.freyr => 'Freyr’s Aett',
        RuneAett.hagal => 'Hagal’s Aett',
        RuneAett.tyr => 'Tyr’s Aett',
      };

  /// What the Aett governs: creation/fertility, disruption/winter, and
  /// order/justice respectively.
  String get theme => switch (this) {
        RuneAett.freyr => 'Growth & beginnings',
        RuneAett.hagal => 'Disruption & endurance',
        RuneAett.tyr => 'Justice & the human order',
      };
}

/// One Elder Futhark rune stone. Pure Dart — no Flutter imports.
///
/// Symmetrical runes (Gebo, Hagalaz, Isa, Jera, Eihwaz, Sowilo, Ingwaz,
/// Dagaz) look identical upside-down, so they NEVER carry a merkstave
/// (reversed) reading — `merkstave` stays null for them.
class RuneStone {
  const RuneStone({
    required this.id,
    required this.name,
    required this.glyph,
    required this.phonetic,
    required this.aett,
    required this.element,
    required this.keywords,
    required this.upright,
    required this.lore,
    this.merkstave,
  });

  /// 0..23 — canonical Elder Futhark order (Fehu .. Othala).
  final int id;
  final String name;
  final String glyph; // Unicode rune glyph, e.g. 'ᚠ'
  final String phonetic; // transliterated sound, e.g. 'F'
  final RuneAett aett;
  final Element element;
  final List<String> keywords;
  final String upright; // one-sentence upright meaning
  final String? merkstave; // null → symmetrical, never reversed
  final String lore; // one-sentence elder lore line

  /// True for the 8 palindromic runes whose glyph is its own mirror.
  bool get isSymmetrical => merkstave == null;

  bool get supportsReversal => merkstave != null;
}
