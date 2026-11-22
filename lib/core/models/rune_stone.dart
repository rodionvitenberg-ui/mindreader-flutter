import '../l10n/app_strings.dart';
import 'tarot_card_model.dart';

/// The three Elder Futhark Aetts — each holds 8 runes.
enum RuneAett { freyr, hagal, tyr }

extension RuneAettX on RuneAett {
  String get label => AppStrings.g('content.aett.$name.label');

  String get title => AppStrings.g('content.aett.$name.title');

  /// What the Aett governs: creation/fertility, disruption/winter, and
  /// order/justice respectively.
  String get theme => AppStrings.g('content.aett.$name.theme');
}

/// One Elder Futhark rune stone. Pure Dart — no Flutter imports.
///
/// Symmetrical runes (Gebo, Hagalaz, Isa, Jera, Eihwaz, Sowilo, Ingwaz,
/// Dagaz) look identical upside-down, so they NEVER carry a merkstave
/// (reversed) reading — `merkstaveKey` stays null for them.
class RuneStone {
  const RuneStone({
    required this.id,
    required this.nameKey,
    required this.glyph,
    required this.phonetic,
    required this.aett,
    required this.element,
    required this.keywordKeys,
    required this.uprightKey,
    required this.loreKey,
    this.merkstaveKey,
  });

  /// 0..23 — canonical Elder Futhark order (Fehu .. Othala).
  final int id;
  final String nameKey;
  final String glyph; // Unicode rune glyph, e.g. 'ᚠ'
  final String phonetic; // transliterated sound, e.g. 'F'
  final RuneAett aett;
  final Element element;
  final List<String> keywordKeys;
  final String uprightKey; // one-sentence upright meaning key
  final String? merkstaveKey; // null → symmetrical, never reversed
  final String loreKey; // one-sentence elder lore line key

  String get name => AppStrings.g(nameKey);
  List<String> get keywords => [
    for (final key in keywordKeys) AppStrings.g(key),
  ];
  String get upright => AppStrings.g(uprightKey);
  String? get merkstave =>
      merkstaveKey == null ? null : AppStrings.g(merkstaveKey!);
  String get lore => AppStrings.g(loreKey);

  /// True for the 8 palindromic runes whose glyph is its own mirror.
  bool get isSymmetrical => merkstaveKey == null;

  bool get supportsReversal => merkstaveKey != null;
}
