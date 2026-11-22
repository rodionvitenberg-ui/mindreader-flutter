import '../l10n/app_strings.dart';
import '../models/divination_system.dart';
import '../models/lenormand_spread.dart';
import '../models/rune_cast.dart';
import '../models/spread_type.dart';
import 'vision/vision_engine.dart' show NormalizedPoint, NormalizedRect;

/// Phase 2 — turns a physical scan into a candidate spread (or Freeform).
///
/// Count ≠ position assignment: the service matches the detected/confirmed
/// card COUNT against the canonical spread catalogs ([SpreadType],
/// [LenormandSpread], [RuneCast]) and returns the compatible templates; it
/// never assigns a card to a specific slot (the user does that in the
/// Recognition Review). Geometry is OPTIONAL and, until a real Vision Engine
/// exists, only flags whether positions are available — it does NOT drive any
/// geometric ranking yet.
class SpreadInferenceInput {
  const SpreadInferenceInput({
    required this.system,
    required this.detectedCount,
    this.confirmedCount,
    this.positions,
    this.boxes,
    this.intention,
  });

  final DivinationSystem system;

  /// How many card regions the scanner reported (before any user edits).
  final int detectedCount;

  /// The user-confirmed count after review (null → use [detectedCount]).
  final int? confirmedCount;

  /// Optional per-card positions in normalized 0..1 coordinates.
  final List<NormalizedPoint>? positions;

  /// Optional per-card bounding boxes in normalized 0..1 coordinates.
  final List<NormalizedRect>? boxes;

  /// The reader's stated intention/question (informational only for now).
  final String? intention;

  int get effectiveCount => confirmedCount ?? detectedCount;

  /// True when any geometry was supplied. Without it the Recognition Review
  /// must also ask the reader to confirm the card ORDER (not just the spread).
  bool get hasGeometry =>
      (positions != null && positions!.isNotEmpty) ||
      (boxes != null && boxes!.isNotEmpty);
}

/// One compatible spread template, resolved to its concrete enum.
class SpreadCandidate {
  const SpreadCandidate.tarot(SpreadType value)
      : tarot = value,
        lenormand = null,
        rune = null;
  const SpreadCandidate.lenormand(LenormandSpread value)
      : tarot = null,
        lenormand = value,
        rune = null;
  const SpreadCandidate.rune(RuneCast value)
      : tarot = null,
        lenormand = null,
        rune = value;

  final SpreadType? tarot;
  final LenormandSpread? lenormand;
  final RuneCast? rune;

  int get cardCount =>
      tarot?.cardCount ?? lenormand?.cardCount ?? rune?.cardCount ?? 0;

  String get label => tarot?.label ?? lenormand?.label ?? rune?.label ?? '';

  bool get isPro => tarot?.isPro ?? lenormand?.isPro ?? rune?.isPro ?? false;

  List<String> get slotRoles =>
      tarot?.slotRoles ??
      lenormand?.slotRoles ??
      rune?.slotRoles ??
      const <String>[];

  /// Human-readable basis for the match (kept honest: count-based only).
  String get reason => AppStrings.g(
    cardCount == 1 ? 'inference.match.one' : 'inference.match.other',
    {'count': cardCount},
  );
}

class SpreadInferenceResult {
  const SpreadInferenceResult({
    required this.candidates,
    required this.detectedCount,
    required this.hasGeometry,
  });

  /// Compatible templates, most relevant first.
  final List<SpreadCandidate> candidates;

  /// The raw scan count — preserved so Freeform never loses a card.
  final int detectedCount;

  final bool hasGeometry;

  SpreadCandidate? get top => candidates.isEmpty ? null : candidates.first;

  /// True when no canonical template matches the count → Freeform/Custom.
  bool get isFreeform => candidates.isEmpty;

  /// True when more than one template matches the count (e.g. Lenormand 9 =
  /// `nine` AND `grandPortrait`) — the review must ask.
  bool get needsConfirmation => candidates.length > 1;
}

/// Pure, stateless. No Flutter imports, no network — deterministic.
class SpreadInferenceService {
  const SpreadInferenceService();

  SpreadInferenceResult infer(SpreadInferenceInput input) {
    final count = input.effectiveCount;
    final candidates = <SpreadCandidate>[];
    if (count >= 1) {
      switch (input.system) {
        case DivinationSystem.tarot:
          for (final t in SpreadType.values) {
            if (t.cardCount == count) candidates.add(SpreadCandidate.tarot(t));
          }
        case DivinationSystem.lenormand:
          for (final s in LenormandSpread.values) {
            if (s.cardCount == count) {
              candidates.add(SpreadCandidate.lenormand(s));
            }
          }
        case DivinationSystem.runes:
          for (final r in RuneCast.values) {
            if (r.cardCount == count) candidates.add(SpreadCandidate.rune(r));
          }
      }
    }
    return SpreadInferenceResult(
      candidates: candidates,
      detectedCount: input.detectedCount,
      hasGeometry: input.hasGeometry,
    );
  }
}
