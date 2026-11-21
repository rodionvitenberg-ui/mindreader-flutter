import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import 'elemental_threads_painter.dart';

class SpreadThreadsLayer extends StatelessWidget {
  const SpreadThreadsLayer({
    super.key,
    required this.selected,
    required this.rects,
  });
  final int? selected;
  final Map<int, Rect> rects;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final settings = context.watch<AppSettingsController>();
    if (selected == null ||
        !settings.enabled(ReadingAid.relationships) ||
        !elementalThreadsVisibleFor(ctrl.system) ||
        !ctrl.allDealt ||
        (settings.enabled(ReadingAid.guide) && !ctrl.allFaceUp)) {
      return const SizedBox.shrink();
    }
    final links = ctrl.relationships.where(
      (r) => r.influence != null && r.includes(selected!),
    );
    final segments = <BranchSegment>[];
    for (final link in links) {
      final a = rects[link.from], b = rects[link.to];
      if (a == null || b == null) continue;
      segments.add((
        start: rectEdgeToward(a, b.center, inset: 8),
        end: rectEdgeToward(b, a.center, inset: 8),
        element: ctrl.slots[link.from].card!.element,
      ));
    }
    if (segments.isEmpty) return const SizedBox.shrink();
    Widget branches(double progress) => CustomPaint(
      painter: ElementalBranchPainter(segments, progress),
      size: Size.infinite,
    );
    return IgnorePointer(
      child: RepaintBoundary(
        child: MediaQuery.disableAnimationsOf(context)
            ? branches(1)
            : TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 680),
                curve: Curves.easeOut,
                builder: (_, v, _) => branches(v),
              ),
      ),
    );
  }
}
