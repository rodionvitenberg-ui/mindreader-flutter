import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/theme/app_colors.dart';
import 'package:mindreader/features/digital_table/widgets/shuffle_physics.dart';

void main() {
  test('hero deck geometry matches the spec: 168×275, 0.35 px layers', () {
    // Two-step Table refactor: the hero deck was re-scaled to the Almanac
    // 220:360 aspect at its ~168 px tile width (220×360 → 168×275). The
    // per-layer thickness is unchanged.
    expect(deckWidth, 168.0);
    expect(deckHeight, 275.0);
    expect(layerThicknessPx, 0.35);
  });

  test('deckTopCardDy sinks PROPORTIONALLY: deckStackHeadroom × (1 - len/78)', () {
    // Full 78-card deck → the top card sits flush at the top of the 28 px
    // headroom. Every drawn card sinks the stack by 28/78 px; an empty
    // deck vacates the headroom entirely — the deck visibly thins.
    expect(deckTopCardDy(78), closeTo(0.0, 0.001));
    expect(deckTopCardDy(39), closeTo(14.0, 0.001));
    expect(deckTopCardDy(1), closeTo(28.0 * (1 - 1 / 78), 0.001));
    expect(deckTopCardDy(0), 28.0);
  });

  test('visual layer cap: 20 rendered deck layers (spec 18..20)', () {
    expect(fanLayerCount, 20);
    expect(fanLayerCount, inInclusiveRange(18, 20));
    expect(fanPhaseStep, 0.45); // spec: staggered phase offset
  });

  test('weave tick fires every 18 px', () {
    expect(weaveTickPx, 18.0);
  });

  test('separation saturates at fullSeparationPx and mirrors drag sign', () {
    expect(separationOf(0), 0.0);
    expect(separationOf(fullSeparationPx), 1.0);
    expect(separationOf(fullSeparationPx * 2), 1.0);
    expect(dragSignOf(18), 1.0);
    expect(dragSignOf(-18), -1.0);
    expect(travelForSeparation(0.5), fullSeparationPx * 0.5);
  });

  test('layers cascade with staggered sine phases', () {
    // Adjacent layers are phase-shifted by 0.45 rad → their lateral wave
    // values differ, so cards do not move as one rigid block.
    final top = FanLayerPose.of(
        layer: 0, count: 28, travel: 60, sign: 1.0);
    final next = FanLayerPose.of(
        layer: 1, count: 28, travel: 60, sign: 1.0);
    expect(top.dx, isNot(closeTo(next.dx, 0.5)));

    // At zero travel every pose converges to the resting stack: no lateral
    // spread, no lift, no rotation.
    final idle = FanLayerPose.of(
        layer: 10, count: 28, travel: 0, sign: 1.0);
    expect(idle.dx, 0.0);
    expect(idle.dy, 0.0);
    expect(idle.rotateY, 0.0);
    expect(idle.rotateZ, 0.0);
    // Depth (translateZ) persists — real physical layering.
    expect(idle.depthZ, lessThan(0));
  });

  test('drag sign mirrors the whole fan', () {
    final right = FanLayerPose.of(
        layer: 0, count: 28, travel: 90, sign: 1.0);
    final left = FanLayerPose.of(
        layer: 0, count: 28, travel: -90, sign: -1.0);
    expect(right.dx, closeTo(-left.dx, 0.001));
  });

  test('deck settle spring is the spec 380/26 heavy spring', () {
    expect(deckSettleSpring.mass, 1.0);
    expect(deckSettleSpring.stiffness, 380.0);
    expect(deckSettleSpring.damping, 26.0);
  });

  // ---- isometric table camera (spec: perspective 0.0014 + rotateX 0.16) --

  test('table camera matrix: perspective 0.0014 + rotateX(0.16)', () {
    expect(deckTablePerspective, 0.0014);
    expect(deckTableTilt, 0.16);
    final m = deckCameraMatrix();
    expect(m.entry(3, 2), closeTo(0.0014, 0.0001));
    // rotateX(0.16) leaves cos(0.16) on the y/z diagonal.
    expect(m.entry(1, 1), closeTo(math.cos(0.16), 0.001));
    expect(m.entry(2, 2), closeTo(math.cos(0.16), 0.001));
  });

  test('fan layers compose the table camera into every card', () {
    final pose = FanLayerPose.of(
        layer: 3, count: 28, travel: 50, sign: -1.0);
    final m = fanMatrixWithCamera(pose);
    expect(m.entry(3, 2), closeTo(deckTablePerspective, 0.0001));
    // The camera tilt compounds with the layer's wave tilt.
    expect(
      m.entry(1, 1),
      closeTo(math.cos(deckTableTilt + pose.rotateX), 0.001),
    );
  });

  test('extractedFlightMatrix: seamless at t=0 (deck) and t=1 (slot)', () {
    final pose = FanLayerPose.of(
        layer: 2, count: 28, travel: 90, sign: -1.0);
    // t=0 reproduces the lifted fan construction EXACTLY (pixel handoff).
    final start = extractedFlightMatrix(pose, 0.0);
    final lifted = fanMatrixWithCamera(pose, liftZ: 26);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        expect(start.entry(r, c), closeTo(lifted.entry(r, c), 0.0001),
            reason: 'row $r col $c');
      }
    }
    // t=1 collapses EXACTLY to the dealt slot card's construction.
    final end = extractedFlightMatrix(pose, 1.0);
    expect(end.entry(3, 2), closeTo(perspectiveEntry, 0.0001));
    expect(end.entry(1, 1), closeTo(math.cos(slotTiltRadians), 0.001));
    expect(end.entry(0, 0), closeTo(1.0, 0.001)); // no rotateY/Z remnants
    expect(end.entry(1, 0), closeTo(0.0, 0.001));
    // Translation is fully gone at landing.
    expect(end.entry(0, 3), closeTo(0.0, 0.001));
    expect(end.entry(1, 3), closeTo(0.0, 0.001));
    expect(end.entry(2, 3), closeTo(0.0, 0.001));
  });

  // ---- organic, persistent, lived-in deck state ----

  test('organic rest poses stay inside the lived-in spec ranges', () {
    final poses =
        generateOrganicRestPoses(count: 28, rng: math.Random(7));
    expect(poses.length, 28);
    for (final p in poses) {
      expect(p.dx, inInclusiveRange(-6.0, 6.0));
      expect(p.dy, inInclusiveRange(-3.0, 3.0));
      expect(p.rotZ, inInclusiveRange(-0.045, 0.045));
    }
    // Deterministic per seed.
    final again =
        generateOrganicRestPoses(count: 28, rng: math.Random(7));
    expect(again.first.dx, poses.first.dx);
  });

  test('withRest adds the organic imperfection to a fan pose', () {
    final base = FanLayerPose.of(
        layer: 0, count: 28, travel: 0, sign: 1.0);
    final posed =
        base.withRest(const CardRestPose(dx: 5, dy: -2, rotZ: 0.03));
    expect(posed.dx, 5.0);
    expect(posed.dy, -2.0);
    expect(posed.rotateZ, 0.03);
    expect(posed.depthZ, base.depthZ);
  });

  test('topVisibleLayer: the grab always lifts the topmost rendered layer', () {
    // Fresh deck: paint order is back → front, so the LAST visible entry
    // is the actual top card.
    expect(topVisibleLayer([0, 1, 2, 3], 4), 3);
    expect(topVisibleLayer([0, 1, 2, 3, 4], 3), 2); // only 3 layers visible
    // After a deal the dealt layer is buried at the back of the paint
    // order and the exposed second card becomes the new top.
    expect(topVisibleLayer([3, 1, 2], 4), 2);
    // Empty deck fallback.
    expect(topVisibleLayer([], 0), 0);
  });

  test('deal release request carries the exact extracted card', () {
    final pose = FanLayerPose.of(
        layer: 1, count: 28, travel: 30, sign: 1.0);
    final req = DeckDealReleaseRequest(
      depth: 1,
      cardOffsetLocal: const Offset(0, 90),
      pose: pose,
      releaseVelocityPx: 600,
    );
    expect(req.depth, 1);
    expect(req.cardOffsetLocal.dy, 90);
    expect(req.releaseVelocityPx, 600);
  });

  test('unified table geometry: Phase 2 52/56 px thread gaps', () {
    expect(deckToPillarGap, 52.0);
    expect(slotGapPx, 56.0);
    expect(tableTopPad, greaterThanOrEqualTo(16.0));
  });

  test('shuffle release micro-damp: 80ms, forward-only, never backward', () {
    expect(microDampDuration, const Duration(milliseconds: 80));
    final sim = ShuffleMicroDamp(from: 0.5, to: 0.6);
    expect(sim.x(0), closeTo(0.5, 0.0001));
    expect(sim.x(0.04), closeTo(0.5 + 0.1 * Curves.easeOutCubic.transform(0.5), 0.0001));
    expect(sim.x(0.08), closeTo(0.6, 0.0001));
    expect(sim.x(0.09), closeTo(0.6, 0.0001)); // clamps, never overshoots
    // Every sampled value stays within [from, to] — never a rollback.
    for (var t = 0.0; t <= 0.08; t += 0.008) {
      final v = sim.x(t);
      expect(v, inInclusiveRange(0.5, 0.6));
    }
    expect(sim.isDone(0.08), isTrue);
    expect(sim.isDone(0.01), isFalse);
  });

  test('spread overview geometry: Triad row, 2×2, Deep Synthesis 3-1-3',
      () {
    // Triad: one horizontal row of three 220×360 cards.
    expect(spreadCanvasDesignSize(SpreadType.three),
        const Size(3 * deckWidth + 2 * slotGapPx, deckHeight));
    expect(spreadSlotDesignTopLeft(SpreadType.three, 1),
        const Offset(deckWidth + slotGapPx, 0));
    // Target & Shadow: 2×2 grid.
    expect(spreadCanvasDesignSize(SpreadType.four),
        const Size(2 * deckWidth + slotGapPx, 2 * deckHeight + slotGapPx));
    expect(spreadSlotDesignTopLeft(SpreadType.four, 3),
        const Offset(deckWidth + slotGapPx, deckHeight + slotGapPx));
    // Deep Synthesis: rows of 3-1-3, crossing card centered.
    expect(spreadCanvasDesignSize(SpreadType.seven),
        const Size(3 * deckWidth + 2 * slotGapPx, 3 * deckHeight + 2 * slotGapPx));
    expect(spreadSlotDesignTopLeft(SpreadType.seven, 2),
        const Offset(2 * (deckWidth + slotGapPx), 0));
    expect(spreadSlotDesignTopLeft(SpreadType.seven, 3),
        const Offset(deckWidth + slotGapPx, deckHeight + slotGapPx));
    expect(spreadSlotDesignTopLeft(SpreadType.seven, 6),
        const Offset(2 * (deckWidth + slotGapPx), 2 * (deckHeight + slotGapPx)));
    // Single card: trivial canvas.
    expect(spreadCanvasDesignSize(SpreadType.one),
        const Size(deckWidth, deckHeight));
    expect(spreadSlotDesignTopLeft(SpreadType.one, 0), Offset.zero);
  });

  test('clarifier slots append a new row below the base spread geometry',
      () {
    // Triad + 1 clarifier: the clarifier starts a second row below.
    expect(
      spreadSlotDesignTopLeft(SpreadType.three, 3, totalSlots: 4),
      const Offset(0, deckHeight + slotGapPx),
    );
    expect(
      spreadCanvasDesignSize(SpreadType.three, totalSlots: 4),
      const Size(
        3 * deckWidth + 2 * slotGapPx,
        2 * deckHeight + slotGapPx,
      ),
    );
    // 2×2 + 2 clarifiers: they share the third row side by side.
    expect(
      spreadSlotDesignTopLeft(SpreadType.four, 5, totalSlots: 6),
      const Offset(deckWidth + slotGapPx, 2 * (deckHeight + slotGapPx)),
    );
    // No clarifiers: identical to the template canvas.
    expect(
      spreadCanvasDesignSize(SpreadType.seven, totalSlots: 7),
      spreadCanvasDesignSize(SpreadType.seven),
    );
  });

  test('the dock deck preserves the horizontal card aspect ratio', () {
    expect(overviewDeckHeight, 44.0);
    expect(overviewDeckWidth / overviewDeckHeight, closeTo(deckHeight / deckWidth, 1e-6));
  });

  test('5-card schemas use distinct real positions: Love Bridge vs Cross of 5',
      () {
    final bridge = spreadBoardGeometryForTarot(SpreadType.loveBridge);
    final cross = spreadBoardGeometryForCount(5);

    expect(bridge.slotRects.length, 5);
    expect(cross.slotRects.length, 5);

    // Love Bridge places two shores on left/right corners and the bridge in center.
    expect(bridge.slotRects[0].topLeft, Offset.zero);
    expect(bridge.slotRects[1].topLeft, const Offset(2 * (deckWidth + slotGapPx), 0));
    expect(
      bridge.slotRects[2].topLeft,
      const Offset(deckWidth + slotGapPx, deckHeight + slotGapPx),
    );
    expect(bridge.slotRects[3].topLeft, const Offset(0, 2 * (deckHeight + slotGapPx)));
    expect(
      bridge.slotRects[4].topLeft,
      const Offset(2 * (deckWidth + slotGapPx), 2 * (deckHeight + slotGapPx)),
    );

    // Cross of 5 places center + 4 cardinal arms (top, left, right, bottom).
    expect(
      cross.slotRects[0].topLeft,
      const Offset(deckWidth + slotGapPx, deckHeight + slotGapPx),
    );
    expect(cross.slotRects[1].topLeft, const Offset(deckWidth + slotGapPx, 0));
    expect(cross.slotRects[2].topLeft, const Offset(0, deckHeight + slotGapPx));
    expect(
      cross.slotRects[3].topLeft,
      const Offset(2 * (deckWidth + slotGapPx), deckHeight + slotGapPx),
    );
    expect(
      cross.slotRects[4].topLeft,
      const Offset(deckWidth + slotGapPx, 2 * (deckHeight + slotGapPx)),
    );
  });

  test('custom spread counts 2 and 8 have dedicated symmetric real layouts', () {
    final pair = spreadBoardGeometryForCount(2);
    expect(pair.canvasSize, const Size(2 * deckWidth + slotGapPx, deckHeight));
    expect(pair.slotRects[0].topLeft, Offset.zero);
    expect(pair.slotRects[1].topLeft, const Offset(deckWidth + slotGapPx, 0));

    final eight = spreadBoardGeometryForCount(8);
    expect(eight.slotRects.length, 8);
    expect(eight.slotRects[3].left, closeTo(0.5 * (deckWidth + slotGapPx), 0.01));
    expect(eight.slotRects[4].left, closeTo(1.5 * (deckWidth + slotGapPx), 0.01));
  });

  test('custom row layout handles 1..12 positions (incl. 9 and 12) + clarifiers',
      () {
    // 9 positions → 3×3 rows.
    final nine = spreadBoardGeometryForCustom(9);
    expect(nine.slotRects.length, 9);
    expect(
      nine.canvasSize,
      const Size(3 * deckWidth + 2 * slotGapPx, 3 * deckHeight + 2 * slotGapPx),
    );
    expect(nine.slotRects[8].topLeft,
        const Offset(2 * (deckWidth + slotGapPx), 2 * (deckHeight + slotGapPx)));

    // 12 positions → 4 rows of 3 cards.
    final twelve = spreadBoardGeometryForCustom(12);
    expect(twelve.slotRects.length, 12);
    expect(
      twelve.canvasSize,
      const Size(3 * deckWidth + 2 * slotGapPx, 4 * deckHeight + 3 * slotGapPx),
    );
    expect(twelve.slotRects[9].topLeft, const Offset(0, 3 * (deckHeight + slotGapPx)));
    expect(
      twelve.slotRects[11].topLeft,
      const Offset(2 * (deckWidth + slotGapPx), 3 * (deckHeight + slotGapPx)),
    );

    // 12 positions + 2 clarifiers → 5th row below the base 4 rows.
    final twelvePlus = spreadBoardGeometryForCustom(12, totalSlots: 14);
    expect(twelvePlus.slotRects.length, 14);
    expect(
      twelvePlus.canvasSize,
      const Size(3 * deckWidth + 2 * slotGapPx, 5 * deckHeight + 4 * slotGapPx),
    );
    expect(
      twelvePlus.slotRects[12].topLeft,
      const Offset(0, 4 * (deckHeight + slotGapPx)),
    );

    // 5 positions → 3 on row 0, 2 centered on row 1.
    final five = spreadBoardGeometryForCustom(5);
    expect(five.slotRects[3].left, closeTo(0.5 * (deckWidth + slotGapPx), 0.01));
    expect(five.slotRects[4].left, closeTo(1.5 * (deckWidth + slotGapPx), 0.01));
  });
}
