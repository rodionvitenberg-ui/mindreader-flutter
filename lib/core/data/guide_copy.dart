import '../l10n/app_strings.dart';
import '../models/divination_system.dart';

/// Localized copy for the Guided Reading mentor.
///
/// Every sentence lives in the shared dictionaries; this class only chooses
/// the key and fills its placeholders, so all six languages stay in sync.
class GuideCopy {
  const GuideCopy._();

  static String _t(AppLanguage lang, String key, [Map<String, Object?>? p]) =>
      AppStrings.t(lang, 'guide.$key', p);

  /// `Deal 2 of 3 · Shadow` ([slot] is 1-based).
  static String dealTitle(
    AppLanguage lang, {
    required int slot,
    required int total,
    required String role,
  }) => _t(lang, 'dealTitle', {'slot': slot, 'total': total, 'role': role});

  /// `Try revealing 2 · Shadow` (1-based).
  static String revealTitle(
    AppLanguage lang, {
    required int slot,
    required String role,
  }) => _t(lang, 'revealTitle', {'slot': slot, 'role': role});

  static String completeTitle(AppLanguage lang) => _t(lang, 'completeTitle');

  /// How to physically deal the next card/stone, depending on the view and
  /// divination system.
  static String dealTip(
    AppLanguage lang, {
    required bool overview,
    required bool runes,
  }) {
    if (!overview) return _t(lang, 'dealTip.stack');
    return _t(lang, runes ? 'dealTip.runes' : 'dealTip.cards');
  }

  static String revealBody(AppLanguage lang) => _t(lang, 'revealBody');

  static String completeBody(AppLanguage lang) => _t(lang, 'completeBody');

  static String slotQuestion(AppLanguage lang, {required String role}) =>
      _t(lang, 'slotQuestion', {'role': role});

  static String elementNote(AppLanguage lang) => _t(lang, 'elementNote');

  static String goldenDawnNote(AppLanguage lang) => _t(lang, 'goldenDawnNote');

  /// How the active system is conventionally read — labelled on purpose, so a
  /// teaching never pretends to be tradition-neutral (G4).
  static String methodNote(AppLanguage lang, DivinationSystem system) =>
      switch (system) {
        DivinationSystem.tarot => goldenDawnNote(lang),
        DivinationSystem.lenormand => _t(lang, 'method.lenormand'),
        DivinationSystem.runes => _t(lang, 'method.runes'),
      };

  /// How a reversal is meant to be read — Tarot turns the card, runes fall
  /// merkstave, and neither is a "bad card" (G4).
  static String reversalNote(AppLanguage lang, DivinationSystem system) =>
      switch (system) {
        DivinationSystem.runes => _t(lang, 'reversal.runes'),
        _ => _t(lang, 'reversal.default'),
      };

  static String relationshipTitle(
    AppLanguage lang, {
    required bool elemental,
  }) => _t(
    lang,
    elemental ? 'relationship.elemental' : 'relationship.positional',
  );

  static String turnOff(AppLanguage lang) => _t(lang, 'turnOff');

  /// Returns from an explicit link explanation to the table's own hint.
  static String backToSpread(AppLanguage lang) => _t(lang, 'backToSpread');

  /// The explicit-request label of the Oracle option (G4) — the Oracle is
  /// never asked automatically.
  static String askOracle(AppLanguage lang) => _t(lang, 'askOracle');

  static String oracleThinking(AppLanguage lang) =>
      _t(lang, 'oracle.thinking');

  static String oracleLabel(AppLanguage lang) => _t(lang, 'oracle.label');
}
