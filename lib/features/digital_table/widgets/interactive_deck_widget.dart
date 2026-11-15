import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/spread_controller.dart';
import 'tarot_card_3d_widget.dart';

/// The tactile deck. All gestures are touch-scoped to THIS widget only
/// (`HitTestBehavior.opaque`): horizontal drag fans and cryptographically
/// shuffles the deck (2.5D, haptic ticks), downward drag deals the top card
/// into the pillar along a curved flight path.
class InteractiveDeckWidget extends StatefulWidget {
  const InteractiveDeckWidget({super.key});

  @override
  State<InteractiveDeckWidget> createState() => _InteractiveDeckWidgetState();
}

class _InteractiveDeckWidgetState extends State<InteractiveDeckWidget>
    with TickerProviderStateMixin {
  static const _miniW = 52.0;
  static const _miniH = 87.0;

  double _fan = 0;
  bool _settling = false;
  bool _dealing = false;
  double _dragDown = 0;
  int _lastTick = 0;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _settle.dispose();
    _flight.dispose();
    super.dispose();
  }

  double get _fanValue => _settling ? _settle.value : _fan;

  void _onFanDrag(DragUpdateDetails d) {
    setState(() => _fan += d.delta.dx);
    final tick = _fan.abs() ~/ 24;
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick(); // continuous subtle shuffle ticks
    }
  }

  void _onFanEnd(DragEndDetails d) {
    if (_fan.abs() > 40) {
      context.read<SpreadController>().shuffleDeck();
      HapticFeedback.mediumImpact();
    }
    _lastTick = 0;
    setState(() => _settling = true);
    _settle.stop();
    // Spring snap-back: the fan returns with the shared game-feel spring.
    _settle
        .animateWith(SpringSimulation(spring, _fan, 0, 0))
        .whenCompleteOrCancel(() {
      if (mounted) {
        setState(() {
          _settling = false;
          _fan = 0;
        });
      }
    });
  }

  void _onDealDrag(DragUpdateDetails d) {
    _dragDown += d.delta.dy;
    if (_dragDown > 60) _tryDeal();
  }

  void _onDealEnd(DragEndDetails d) {
    if (d.primaryVelocity != null && d.primaryVelocity! > 450) _tryDeal();
    _dragDown = 0;
  }

  void _tryDeal() {
    if (_dealing) return;
    final ctrl = context.read<SpreadController>();
    if (ctrl.nextEmptySlotIndex == null || ctrl.remaining == 0) {
      HapticFeedback.heavyImpact(); // table is full
      return;
    }
    setState(() {
      _dealing = true;
      _dragDown = 0;
    });
    HapticFeedback.mediumImpact();
    _flight.forward(from: 0).whenComplete(() {
      context.read<SpreadController>().dealNextCard();
      if (mounted) setState(() => _dealing = false);
    });
  }

  Widget _fanCard(int i, int count, double fan) {
    final depth = count - 1 - i; // 0 = top card
    final cx = depth - (count - 1) / 2;
    return Transform.translate(
      offset: Offset(fan * 0.22 * cx + cx * 2, -depth * 5 + fan.abs() * 0.05),
      child: Transform.rotate(
        angle: fan * 0.0008 * cx + cx * 0.04,
        child: const CardBack(width: _miniW, height: _miniH),
      ),
    );
  }

  Widget _flightProxy() {
    final t = Curves.easeOutCubic.transform(_flight.value);
    // shortcut: the proxy flies on a curved path toward the pillar region
    // (the deck sits directly below the board); the slot fills at the end.
    final dy = -MediaQuery.sizeOf(context).height * 0.38 * t;
    final sway = math.sin(math.pi * t) * 44;
    return Transform.translate(
      offset: Offset(sway, dy),
      child: Transform.rotate(
        angle: t * 0.35,
        child: Transform.scale(
          scale: 1 + t * 1.6,
          child: const CardBack(width: _miniW, height: _miniH),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = context.watch<SpreadController>().deckTop;
    return SizedBox(
      height: 122,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onFanDrag,
              onHorizontalDragEnd: _onFanEnd,
              onVerticalDragUpdate: _onDealDrag,
              onVerticalDragEnd: _onDealEnd,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_settle, _flight]),
                  builder: (context, _) {
                    final fan = _fanValue;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = top.length - 1;
                            i >= (_dealing ? 1 : 0);
                            i--)
                          _fanCard(i, top.length, fan),
                        if (_dealing) _flightProxy(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '←  →  SHUFFLE    ·    ↓  DEAL',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
