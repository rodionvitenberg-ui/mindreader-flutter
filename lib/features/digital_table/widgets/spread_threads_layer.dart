import 'package:flutter/material.dart';

import '../../../core/models/dealt_card_slot.dart';
import 'elemental_threads_painter.dart';

/// The shimmering Elemental Fate Threads painted BEHIND the spread canvas
/// in Spread Overview mode: segments between adjacent face-up cards in
/// their true table geometry (design coordinates).
class SpreadThreadsLayer extends StatefulWidget {
  const SpreadThreadsLayer({
    super.key,
    required this.dealt,
    required this.rects,
  });

  /// Dealt cards in reading order.
  final List<DealtCardSlot> dealt;

  /// Parallel card rectangles in the canvas design space.
  final List<Rect> rects;

  @override
  State<SpreadThreadsLayer> createState() => _SpreadThreadsLayerState();
}

class _SpreadThreadsLayerState extends State<SpreadThreadsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: ElementalThreadsPainter(
            segments: threadSegmentsFor(widget.dealt, widget.rects),
            pulse: _pulse,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
