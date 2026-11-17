import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';

void main() {
  test('flip is the ceremonial 680ms', () {
    expect(cardFlipDuration, const Duration(milliseconds: 680));
    expect(cardFlipThicknessPx, 4.0);
  });

  test('edge bevel collapses behind the face at 0 and ±π', () {
    // At angle 0 the strips all sit at the card's right edge — fully
    // covered by the unrotated face, nothing sticks out.
    for (var k = 0; k < cardEdgeSlices; k++) {
      expect(
        cardEdgeStripX(angle: 0, width: 220, leadingSign: 1, k: k),
        closeTo(220, 0.0001),
      );
      expect(
        cardEdgeStripX(angle: 0, width: 220, leadingSign: -1, k: k),
        closeTo(0, 0.0001),
      );
    }
  });

  test('edge bevel shows the full 4px thickness at π/2', () {
    final xs = [
      for (var k = 0; k < cardEdgeSlices; k++)
        cardEdgeStripX(angle: math.pi / 2, width: 220, leadingSign: 1, k: k),
    ];
    expect(xs.first, closeTo(108, 0.0001));
    expect(xs.last, closeTo(112, 0.0001));
    // Total spread == 4.0 px exactly.
    expect(xs.last - xs.first, closeTo(cardFlipThicknessPx, 0.0001));
    // Centered on the card axis when edge-on.
    expect((xs.first + xs.last) / 2, closeTo(110, 0.0001));
  });

  test('edge thickness becomes visible through 45°–135° (|angle| ≥ π/4)', () {
    // The visible sliver = strips beyond the card's projected turning edge.
    double visibleSliver(double angle) {
      final projectedHalf = 110 * math.cos(angle).abs();
      final edge = 110 + projectedHalf; // screen X of the turning edge
      final strips = [
        for (var k = 0; k < cardEdgeSlices; k++)
          cardEdgeStripX(
              angle: angle, width: 220, leadingSign: 1, k: k),
      ];
      return strips.last - edge;
    }

    expect(visibleSliver(0), lessThan(0.02)); // invisible at rest
    expect(visibleSliver(math.pi / 4), greaterThan(0.5)); // 45°
    expect(visibleSliver(3 * math.pi / 4), greaterThan(0.5)); // 135°
    // At π/2 the card is edge-on: the full 4px rim is the card.
    final strips = [
      for (var k = 0; k < cardEdgeSlices; k++)
        cardEdgeStripX(
            angle: math.pi / 2, width: 220, leadingSign: 1, k: k),
    ];
    expect(strips.last - strips.first, greaterThan(3.0));
  });

  test('the back half of the flip mirrors the edge to the left', () {
    final right = cardEdgeStripX(
        angle: math.pi / 4, width: 220, leadingSign: 1, k: cardEdgeSlices - 1);
    final left = cardEdgeStripX(
        angle: -math.pi / 4, width: 220, leadingSign: -1, k: 0);
    // Mirrored around the card's center axis.
    expect(right + left, closeTo(220, 0.0001));
  });
}
