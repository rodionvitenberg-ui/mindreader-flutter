import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import 'elemental_threads_painter.dart';

/// Duration of one elemental branch sprouting between newly revealed neighbors.
const branchGrowthDuration = Duration(milliseconds: 2000);

class SpreadThreadsLayer extends StatefulWidget {
  const SpreadThreadsLayer({super.key, required this.rects});
  final Map<int, Rect> rects;

  @override
  State<SpreadThreadsLayer> createState() => _SpreadThreadsLayerState();
}

class _SpreadThreadsLayerState extends State<SpreadThreadsLayer> {
  final _revealOrder = <int>[];
  final _openOnEntry = <int>{};
  int? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = context.watch<SpreadController>();
    final open = {
      for (final slot in ctrl.slots)
        if (slot.state == SlotState.faceUp) slot.index,
    };
    if (_revision != ctrl.readingRevision) {
      _revision = ctrl.readingRevision;
      _revealOrder.clear();
      _openOnEntry
        ..clear()
        ..addAll(open);
    }
    _revealOrder.removeWhere((position) => !open.contains(position));
    _revealOrder.addAll(
      open.where((position) => !_revealOrder.contains(position)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final enabled = context.select<AppSettingsController, bool>(
      (settings) => settings.enabled(ReadingAid.relationships),
    );
    if (!enabled || !elementalThreadsVisibleFor(ctrl.system)) {
      return const SizedBox.shrink();
    }
    final branches = <Widget>[];
    // The reading engine already requires both endpoints to be face up.
    // Flanking comparisons stay in the inspector, outside the board drawing.
    for (final link in ctrl.relationships) {
      if (link.influence == null || (link.from - link.to).abs() != 1) continue;
      final fromOpenedFirst =
          _revealOrder.indexOf(link.from) < _revealOrder.indexOf(link.to);
      final start = fromOpenedFirst ? link.from : link.to;
      final end = fromOpenedFirst ? link.to : link.from;
      final a = widget.rects[start], b = widget.rects[end];
      if (a == null || b == null) continue;
      final segment = (
        start: rectEdgeToward(a, b.center, inset: 4),
        end: rectEdgeToward(b, a.center, inset: 4),
        element: ctrl.slots[link.from].card!.element,
      );
      final alreadyOpen =
          _openOnEntry.contains(start) && _openOnEntry.contains(end);
      branches.add(
        RepaintBoundary(
          key: ValueKey((
            ctrl.readingRevision,
            link.from,
            link.to,
            link.fromId,
            link.toId,
          )),
          child: _GrowingElementalBranch(
            segment: segment,
            alreadyOpen: alreadyOpen,
          ),
        ),
      );
    }
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: branches,
      ),
    );
  }
}

class _GrowingElementalBranch extends StatefulWidget {
  const _GrowingElementalBranch({
    required this.segment,
    required this.alreadyOpen,
  });

  final BranchSegment segment;
  final bool alreadyOpen;

  @override
  State<_GrowingElementalBranch> createState() =>
      _GrowingElementalBranchState();
}

class _GrowingElementalBranchState extends State<_GrowingElementalBranch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _growth = AnimationController(
    vsync: this,
    duration: branchGrowthDuration,
    value: widget.alreadyOpen ? 1.0 : 0.0,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.alreadyOpen) {
      _growth.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _growth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _growth,
      builder: (_, _) => CustomPaint(
        painter: ElementalBranchPainter([widget.segment], _growth.value),
      ),
    );
  }
}
