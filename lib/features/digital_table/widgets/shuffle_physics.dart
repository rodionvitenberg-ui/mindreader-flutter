import 'dart:math' as math;

import 'package:flutter/physics.dart' show Simulation;
import 'package:flutter/widgets.dart' show Curves, Matrix4, Offset, Rect, Size;

import '../../../core/models/lenormand_spread.dart';
import '../../../core/models/rune_cast.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/theme/card_motion.dart';

/// Pure, unit-testable choreography for the true 78-card riffle/weave
/// shuffle. No widget state here — the deck widget feeds drag travel in and
/// reads per-layer poses / matrices out.
///
/// Phase 3 contract: 24–36 individually articulated card layers fanned in
/// 3D (perspective 0.0018, per-card rotateY/rotateZ/translateX/translateZ)
/// with staggered sine phases (`sin(dragPhase + layer * 0.45)`) so cards
/// visibly arc, lift, cascade and interleave like a real physical deck.

/// Geometry of the hero deck — matched to the Almanac's card proportions
/// (220:360) scaled down to the Almanac's ~168 px grid-tile width, so the
/// FOCUS VIEW deck + dealt cards no longer render oversized at 220×360.
/// `deckWidth * 360 / 220 == 274.9`, rounded to 275 — the exact Almanac
/// aspect ratio (0.611) is preserved.
const deckWidth = 168.0;
const deckHeight = 275.0;

/// Headroom above the hero card where the painted layer edges stack up
/// (78 × 0.35 ≈ 27 px); the deck widget's hit-box is 220 × (360 + headroom).
const deckStackHeadroom = 28.0;

/// Hit-box height of the interactive deck widget.
const deckBoxHeight = deckHeight + deckStackHeadroom;

/// Vertical thickness offset per card layer: layer i sits at dy = -i * 0.35.
const layerThicknessPx = 0.35;

/// Top card's dy inside the deck box for a deck with [remaining] cards of
/// [totalCards]. PROPORTIONAL DEPLETION: the top card physically sinks as
/// the deck thins — a full deck sits flush at the top of the headroom,
/// an empty one vacates it entirely. `deckStackHeadroom × (1 - remaining/78)`
/// makes every drawn card visibly reduce the rendered stack.
double deckTopCardDy(int remaining, {int totalCards = 78}) {
  final total = math.max(1, totalCards);
  final r = math.max(0, math.min(remaining, total));
  return deckStackHeadroom * (1.0 - r / total);
}

/// The topmost rendered card layer of the deck: the LAST visible entry in
/// the paint order ([layerOrder] is back → front). A downward grab always
/// lifts THIS layer — the actual top card, never a spawned proxy.
int topVisibleLayer(List<int> layerOrder, int visibleCount) =>
    layerOrder.lastWhere((layer) => layer < visibleCount, orElse: () => 0);

/// Real, individually articulated card layers rendered during the shuffle.
/// VISUAL CAP (mid-range Android performance fix): at most 20 widget layers
/// are ever composed — the logical 78-card state stays fully intact in
/// [SpreadController], so the counter and probabilities remain authentic.
/// Deeper layers stay painted as cheap edge hairlines in one canvas pass.
const fanLayerCount = 20;

/// Staggered phase offset between adjacent fan layers (spec: 0.45).
const fanPhaseStep = 0.45;

/// Drag travel (px) that advances one full sine phase cycle.
const fanPhasePx = 14.0;

/// Max horizontal fan spread of the outermost card layer (px).
const fanSpreadPx = 56.0;

/// Max arc lift of a card cresting its sine wave (px).
const fanLiftPx = 26.0;

/// Haptic + secure permutation tick fires every 18 px of drag travel.
const weaveTickPx = 18.0;

/// Horizontal drag travel (px) at which the fan reaches full separation.
const fullSeparationPx = 120.0;

/// Unified scrollable table canvas geometry (one single continuous axis):
/// top breathing room, deck → dealt-cards gap, slot gap. Phase 2: the
/// gaps were expanded +50% (52–56 px) to host the living Elemental Fate
/// Threads between cards.
const tableTopPad = 24.0;
const deckToPillarGap = 52.0;
const slotGapPx = 56.0;

/// Permanent isometric table camera tilt over the deck (spec):
/// perspective entry 0.0014 + rotateX(0.16) — the 78-card stack is viewed
/// at a tactile angle so its stepped 3D volume never flattens into a brick.
const deckTablePerspective = 0.0014;
const deckTableTilt = 0.16;

/// Builds the deck's camera tilt matrix (tilts the painted residual stack).
Matrix4 deckCameraMatrix() => Matrix4.identity()
  ..setEntry(3, 2, deckTablePerspective)
  ..rotateX(deckTableTilt);

/// One persistent, lived-in resting imperfection of a card layer: a real
/// tarot deck in human hands is never a laser-aligned brick.
class CardRestPose {
  const CardRestPose({required this.dx, required this.dy, required this.rotZ});

  /// Horizontal offset: -6.0..+6.0 px.
  final double dx;

  /// Vertical offset: -3.0..+3.0 px.
  final double dy;

  /// Yaw offset: -0.045..+0.045 rad.
  final double rotZ;
}

/// Generates [count] organic resting imperfections within the spec ranges.
/// Deterministic per [rng] seed.
List<CardRestPose> generateOrganicRestPoses({
  required int count,
  required math.Random rng,
}) => [
      for (var i = 0; i < count; i++)
        CardRestPose(
          dx: rng.nextDouble() * 12.0 - 6.0,
          dy: rng.nextDouble() * 6.0 - 3.0,
          rotZ: rng.nextDouble() * 0.09 - 0.045,
        ),
    ];

/// Separation 0..1 driven by |travel| (saturates at [fullSeparationPx]).
double separationOf(double travel) =>
    math.min(1.0, travel.abs() / fullSeparationPx);

/// Sign of the drag: +1 = dragging right, -1 = dragging left.
double dragSignOf(double travel) => travel >= 0 ? 1.0 : -1.0;

/// Inverse of [separationOf]: the travel that produces [separation].
double travelForSeparation(double separation) => separation * fullSeparationPx;

/// 3D pose of one fan layer, computed purely from its [layer] index,
/// the signed drag [travel] and the drag [sign].
class FanLayerPose {
  const FanLayerPose({
    required this.dx,
    required this.dy,
    required this.depthZ,
    required this.rotateY,
    required this.rotateX,
    required this.rotateZ,
  });

  final double dx;
  final double dy;

  /// A neutral flat pose — used by the rune-stone cast flight.
  static const flat = FanLayerPose(
    dx: 0,
    dy: 0,
    depthZ: 0,
    rotateY: 0,
    rotateX: 0,
    rotateZ: 0,
  );

  /// Depth under perspective: deeper layers recede (translateZ).
  final double depthZ;
  final double rotateY;
  final double rotateX;
  final double rotateZ;

  static FanLayerPose of({
    required int layer,
    required int count,
    required double travel,
    required double sign,
  }) {
    final s = separationOf(travel);
    final phase = (travel.abs() / fanPhasePx) + layer * fanPhaseStep;
    final wave = math.sin(phase); // lateral cascade
    final crest = math.cos(phase); // tilt response
    final fade = 1.0 - (layer / count) * 0.55; // top layers fan the most
    return FanLayerPose(
      dx: wave * fanSpreadPx * fade * s * sign,
      dy: -layer * 1.1 * s - wave.abs() * fanLiftPx * fade * s,
      depthZ: -layer * 0.9,
      rotateY: crest * 0.16 * fade * s * sign,
      rotateX: 0.03 * s + wave * 0.04 * fade,
      rotateZ: wave * 0.10 * fade * s,
    );
  }

  /// Combines the choreography pose with the layer's persistent organic
  /// imperfection (offsets are additive, yaw compounds).
  FanLayerPose withRest(CardRestPose rest) => FanLayerPose(
        dx: dx + rest.dx,
        dy: dy + rest.dy,
        depthZ: depthZ,
        rotateY: rotateY,
        rotateX: rotateX,
        rotateZ: rotateZ + rest.rotZ,
      );
}

/// Builds the 2.5D matrix of one fan layer under the deck's permanent
/// isometric table camera: translate (with Z depth) → perspective 0.0014 →
/// rotateX(0.16 + wave) → rotateY/rotateZ. [liftZ] raises a grabbed card
/// toward the viewer.
Matrix4 fanMatrixWithCamera(FanLayerPose pose, {double liftZ = 0}) {
  return Matrix4.identity()
    ..translateByDouble(pose.dx, pose.dy, pose.depthZ + liftZ, 1)
    ..setEntry(3, 2, deckTablePerspective)
    ..rotateX(deckTableTilt + pose.rotateX)
    ..rotateY(pose.rotateY)
    ..rotateZ(pose.rotateZ);
}

/// The single continuous extraction construction shared by the deck's
/// grabbed card and the flight overlay:
/// * t = 0 → exactly [fanMatrixWithCamera] with the grab lift (pixel-identical
///   handoff from the deck, no pop);
/// * t = 1 → exactly the dealt slot card's construction (perspective 0.0012,
///   rotateX(slotTiltRadians), no fan remnants) — pixel-identical landing.
Matrix4 extractedFlightMatrix(FanLayerPose pose, double t,
    {double liftZ = 26}) {
  final k = 1 - t;
  double lerp(double a, double b) => a + (b - a) * t;
  return Matrix4.identity()
    ..translateByDouble(pose.dx * k, pose.dy * k, (pose.depthZ + liftZ) * k, 1)
    ..setEntry(3, 2, lerp(deckTablePerspective, perspectiveEntry))
    ..rotateX(lerp(deckTableTilt + pose.rotateX, slotTiltRadians))
    ..rotateY(pose.rotateY * k)
    ..rotateZ(pose.rotateZ * k);
}

/// Handoff payload: the exact card the user grabbed and released past the
/// deal threshold, in deck-local coordinates. The parent plays the single
/// continuous flight from this release point into the target slot.
class DeckDealReleaseRequest {
  const DeckDealReleaseRequest({
    required this.depth,
    required this.cardOffsetLocal,
    required this.pose,
    required this.releaseVelocityPx,
  });

  /// Physical depth of the extracted card (0 = top card).
  final int depth;

  /// Top-left of the card at release, deck-local (pre-matrix).
  final Offset cardOffsetLocal;

  /// The card's fan/organic pose at release (drives the flight rotation).
  final FanLayerPose pose;

  /// Downward release velocity (px/s).
  final double releaseVelocityPx;
}

/// Deck settle spring re-exported so the widget and tests share one source.
const deckSettleSpring = deckSpring;

/// 80ms ease-out micro-damping after the finger lifts from a shuffle:
/// drifts the fan separation a few px FORWARD along the release velocity
/// and stops. It can never move backward — the exact finger-release pose
/// is the new permanent rest state (no reverse spring, no rollback).
const microDampDuration = Duration(milliseconds: 80);

/// The forward-only micro-damp simulation ([from] → [to], to >= from) on
/// `Curves.easeOutCubic`.
class ShuffleMicroDamp extends Simulation {
  ShuffleMicroDamp({required this.from, required this.to})
      : assert(to >= from, 'micro-damp must never move backward');

  /// Separation (0..1) at the moment the finger lifted.
  final double from;

  /// Separation after the forward-only micro-drift (to >= from).
  final double to;

  static const _seconds = 0.08; // microDampDuration in seconds

  @override
  double x(double timeInSeconds) {
    final f = (timeInSeconds / _seconds).clamp(0.0, 1.0);
    return from + (to - from) * Curves.easeOutCubic.transform(f);
  }

  @override
  double dx(double timeInSeconds) {
    // Forward difference of x — only used by simulation consumers, never
    // by the animation ticker itself.
    const dt = 1e-4;
    return (x(timeInSeconds + dt) - x(timeInSeconds)) / dt;
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds >= _seconds;
}

// ---- Full Spread Overview mode (real table layout) -----------------------

/// Maximum painted footprint of the horizontal deck in the Spread View dock.
const overviewDeckHeight = 44.0;
const overviewDeckWidth = overviewDeckHeight * deckHeight / deckWidth;

/// Design-space geometry of a spread: the board's full design size plus the
/// exact card rectangle of every slot in reading order. Shared by the active
/// `SpreadBoard` AND the picker miniatures so every thumbnail is built from
/// the schema's real positions.
class SpreadBoardGeometry {
  const SpreadBoardGeometry({
    required this.canvasSize,
    required this.slotRects,
    this.crossingSlotIndex,
  });

  final Size canvasSize;
  final List<Rect> slotRects;

  /// Optional index of a card laid across another (slot 1 of Celtic Cross).
  final int? crossingSlotIndex;
}

/// Horizontal gap between the Celtic Cross horizontal crossing card and Past / Future.
const _celticArmGapPx = 44.0;

/// Horizontal gap separating the 6-card Cross from the 4-card Staff.
const _celticStaffGapPx = 76.0;

/// Design-space size of the spread canvas for a spread of [count] cards —
/// [deckWidth] × [deckHeight] cards with [slotGapPx] gaps.
/// Layout is derived from the schema / count: 1 → single, 2 → pair row,
/// 3 → row, 4 → 2×2, 5 → Cross of 5 or Love Bridge (3×3), 6 → 1-2-3 tree,
/// 7 → 3-1-3, 8 → 3-2-3, 9 → 3×3, 10 → Celtic Cross.
/// The camera initially fits the complete canvas in the viewport.
///
/// When [totalSlots] exceeds the template's card count (clarifiers),
/// the extra cards append as additional rows below the base geometry.
Size spreadCanvasDesignSizeForCount(int count, {int? totalSlots}) {
  final w = deckWidth;
  final h = deckHeight;
  final g = slotGapPx;
  final base = switch (count) {
    1 => Size(w, h),
    2 => Size(2 * w + g, h),
    3 => Size(3 * w + 2 * g, h),
    4 => Size(2 * w + g, 2 * h + g),
    5 => Size(3 * w + 2 * g, 3 * h + 2 * g),
    6 => Size(3 * w + 2 * g, 3 * h + 2 * g),
    7 => Size(3 * w + 2 * g, 3 * h + 2 * g),
    8 => Size(3 * w + 2 * g, 3 * h + 2 * g),
    9 => Size(3 * w + 2 * g, 3 * h + 2 * g),
    10 => Size(
        3 * w + h + 2 * _celticArmGapPx + _celticStaffGapPx,
        4 * h + 3 * g,
      ),
    _ => Size(3 * w + 2 * g, 3 * h + 2 * g),
  };
  final extra = (totalSlots ?? count) - count;
  if (extra <= 0) return base;
  final cols = _spreadColsForCount(count);
  final rows = (extra + cols - 1) ~/ cols;
  return Size(base.width, base.height + rows * (h + g));
}

/// Design-space top-left of slot [index] inside a spread of [count]
/// canonical cards. Set [loveBridge] to `true` for the 5-card Love Bridge
/// schema (two shores + central bridge + flow + union) rather than the
/// classic Cross of 5. Slots beyond the template ([totalSlots] > count) are
/// clarifiers — they fill a new row below the base spread.
Offset spreadSlotDesignTopLeftForCount(
  int count,
  int index, {
  int? totalSlots,
  bool loveBridge = false,
}) {
  final w = deckWidth;
  final h = deckHeight;
  final g = slotGapPx;
  if (index < count) {
    switch (count) {
      case 1:
        return Offset.zero;
      case 2:
        return Offset(index * (w + g), 0);
      case 3:
        return Offset(index * (w + g), 0);
      case 4:
        return Offset((index % 2) * (w + g), (index ~/ 2) * (h + g));
      case 5:
        if (loveBridge) {
          // Love Bridge: two sides (left/right) and the bridge between them.
          const cells = [
            [0, 0], // 0 Your Shore (left top)
            [2, 0], // 1 Their Shore (right top)
            [1, 1], // 2 The Bridge (center)
            [0, 2], // 3 What Flows Between (left bottom)
            [2, 2], // 4 The Union (right bottom)
          ];
          final cell = cells[index];
          return Offset(cell[0] * (w + g), cell[1] * (h + g));
        }
        // Cross of 5 / Thor's Cross — center + 4 cardinal arms.
        const cells = [
          [1, 1], // 0 center
          [1, 0], // 1 top
          [0, 1], // 2 left
          [2, 1], // 3 right
          [1, 2], // 4 bottom
        ];
        final cell = cells[index];
        return Offset(cell[0] * (w + g), cell[1] * (h + g));
      case 6: // Career Crossroads — 1-2-3 branching tree
        const order = [1, 0, 2, 0, 1, 2];
        const row = [0, 1, 1, 2, 2, 2];
        return Offset(order[index] * (w + g), row[index] * (h + g));
      case 7: // Heimdall's Bridge / Horseshoe — 3-1-3
        if (index < 3) return Offset(index * (w + g), 0);
        if (index == 3) return Offset(w + g, h + g);
        return Offset((index - 4) * (w + g), 2 * (h + g));
      case 8: // Symmetric 3-2-3 (custom 8-card spread)
        if (index < 3) return Offset(index * (w + g), 0);
        if (index == 3) return Offset(0.5 * (w + g), h + g);
        if (index == 4) return Offset(1.5 * (w + g), h + g);
        return Offset((index - 5) * (w + g), 2 * (h + g));
      case 9: // 3×3 portrait box — reading order left→right, top→bottom
        return Offset((index % 3) * (w + g), (index ~/ 3) * (h + g));
      case 10: // Celtic Cross — 6-card cross (centered vertically) + 4-card staff
        final crossLeft = w + _celticArmGapPx;
        final crossCenterX = crossLeft + h / 2;
        final crossColX = crossCenterX - w / 2;
        final crossTopY = 0.5 * (h + g);
        final crossMidY = crossTopY + h + g;
        final crossCenterY = crossMidY + h / 2;
        final futureX = crossLeft + h + _celticArmGapPx;
        final staffX = futureX + w + _celticStaffGapPx;
        return switch (index) {
          0 => Offset(crossColX, crossMidY), // significator (center)
          1 => Offset(crossLeft, crossCenterY - w / 2), // crossing (horizontal, centered on 0)
          2 => Offset(crossColX, crossTopY), // crown
          3 => Offset(crossColX, crossMidY + h + g), // foundation
          4 => Offset(0, crossMidY), // past
          5 => Offset(futureX, crossMidY), // future
          _ => Offset(staffX, (index - 6) * (h + g)), // staff 6..9
        };
      default:
        return Offset((index % 3) * (w + g), (index ~/ 3) * (h + g));
    }
  }
  // Clarifier slot: a fresh row below the base spread.
  final k = index - count;
  final cols = _spreadColsForCount(count);
  final baseRows = _spreadBaseRowsForCount(count);
  return Offset(
    (k % cols) * (w + g),
    baseRows * (h + g) + (k ~/ cols) * (h + g),
  );
}

/// Complete real board geometry for a given [count] and optional [loveBridge]
/// layout variant. Used directly by both `SpreadBoard` and the picker
/// miniatures.
SpreadBoardGeometry spreadBoardGeometryForCount(
  int count, {
  int? totalSlots,
  bool loveBridge = false,
}) {
  final slots = totalSlots ?? count;
  final size = spreadCanvasDesignSizeForCount(count, totalSlots: slots);
  final crossingIndex = count == 10 ? 1 : null;
  final rects = [
    for (var i = 0; i < slots; i++)
      spreadSlotDesignTopLeftForCount(
            count,
            i,
            totalSlots: slots,
            loveBridge: loveBridge,
          ) &
          (i == crossingIndex
              ? const Size(deckHeight, deckWidth)
              : const Size(deckWidth, deckHeight)),
  ];
  return SpreadBoardGeometry(
    canvasSize: size,
    slotRects: rects,
    crossingSlotIndex: crossingIndex,
  );
}

SpreadBoardGeometry spreadBoardGeometryForTarot(
  SpreadType type, {
  int? totalSlots,
}) =>
    spreadBoardGeometryForCount(
      type.cardCount,
      totalSlots: totalSlots,
      loveBridge: type == SpreadType.loveBridge,
    );

SpreadBoardGeometry spreadBoardGeometryForLenormand(
  LenormandSpread spread, {
  int? totalSlots,
}) =>
    spreadBoardGeometryForCount(spread.cardCount, totalSlots: totalSlots);

SpreadBoardGeometry spreadBoardGeometryForRune(
  RuneCast cast, {
  int? totalSlots,
}) =>
    spreadBoardGeometryForCount(cast.cardCount, totalSlots: totalSlots);

/// Automatic row-based layout for the Custom Spread builder (1..12 positions):
/// * 1 → 1×1, 2 → 2×1, 3 → 3×1, 4 → 2×2, 5..12 → 3 columns per row
///   (e.g. 9 = 3×3, 12 = 3×4), with any partial last row centered.
/// Clarifier slots beyond [count] append as full-width rows below the base.
SpreadBoardGeometry spreadBoardGeometryForCustom(
  int count, {
  bool fiveCardLine = false,
  int? totalSlots,
}) {
  final baseCount = math.max(1, count);
  final slots = math.max(baseCount, totalSlots ?? baseCount);
  final cols = switch (baseCount) {
    5 when fiveCardLine => 5,
    1 => 1,
    2 => 2,
    4 => 2,
    _ => 3,
  };
  final w = deckWidth;
  final h = deckHeight;
  final g = slotGapPx;
  final baseRows = (baseCount + cols - 1) ~/ cols;
  final extra = slots - baseCount;
  final extraRows = extra <= 0 ? 0 : (extra + cols - 1) ~/ cols;
  final totalRows = baseRows + extraRows;
  final canvasSize = Size(
    cols * w + (cols - 1) * g,
    totalRows * h + (totalRows - 1) * g,
  );
  final rects = <Rect>[];
  for (var i = 0; i < baseCount; i++) {
    final row = i ~/ cols;
    final col = i % cols;
    final rowLen = math.min(cols, baseCount - row * cols);
    final rowOffset = ((cols - rowLen) / 2.0) * (w + g);
    rects.add(
      Rect.fromLTWH(rowOffset + col * (w + g), row * (h + g), w, h),
    );
  }
  for (var k = 0; k < extra; k++) {
    final row = baseRows + (k ~/ cols);
    final col = k % cols;
    rects.add(Rect.fromLTWH(col * (w + g), row * (h + g), w, h));
  }
  return SpreadBoardGeometry(canvasSize: canvasSize, slotRects: rects);
}

/// Number of card rows in the base spread geometry for [count] cards.
int _spreadBaseRowsForCount(int count) => switch (count) {
      1 => 1,
      2 => 1,
      3 => 1,
      4 => 2,
      5 => 3,
      6 => 3,
      7 => 3,
      8 => 3,
      9 => 3,
      10 => 4,
      _ => 3,
    };

/// Cards per row in the base spread geometry for [count] cards.
int _spreadColsForCount(int count) => switch (count) {
      1 => 1,
      2 => 2,
      3 => 3,
      4 => 2,
      5 => 3,
      6 => 3,
      7 => 3,
      8 => 3,
      9 => 3,
      10 => 4,
      _ => 3,
    };

// ---- SpreadType-based compat wrappers (tarot templates) -------------------

/// Design-space size of the spread canvas for [type] — full cards with
/// [slotGapPx] gaps in their true table geometry.
Size spreadCanvasDesignSize(SpreadType type, {int? totalSlots}) =>
    spreadCanvasDesignSizeForCount(type.cardCount, totalSlots: totalSlots);

/// Design-space top-left of slot [index] inside its true spread geometry.
Offset spreadSlotDesignTopLeft(SpreadType type, int index, {int? totalSlots}) =>
    spreadSlotDesignTopLeftForCount(
      type.cardCount,
      index,
      totalSlots: totalSlots,
      loveBridge: type == SpreadType.loveBridge,
    );



