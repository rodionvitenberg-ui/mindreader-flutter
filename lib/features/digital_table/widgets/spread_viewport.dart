import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The board stays in card coordinates. Only the camera scales or moves.
class SpreadViewport extends StatefulWidget {
  const SpreadViewport({
    super.key,
    required this.viewport,
    required this.boardSize,
    required this.fitLabel,
    required this.child,
  });

  final Size viewport;
  final Size boardSize;
  final String fitLabel;
  final Widget child;

  double get fit {
    final inset = math.min(12.0, viewport.shortestSide / 8);
    return math.min(
      1.0,
      math.min(
        (viewport.width - 2 * inset) / boardSize.width,
        (viewport.height - 2 * inset) / boardSize.height,
      ),
    );
  }

  // A scene at least as wide AND tall as the viewport at the minimum zoom
  // keeps InteractiveViewer's pan bounds correct for short and tall layouts.
  Size get scene => viewport / fit;
  Offset get boardOrigin =>
      scene.center(Offset.zero) - boardSize.center(Offset.zero);

  @override
  State<SpreadViewport> createState() => _SpreadViewportState();
}

class _SpreadViewportState extends State<SpreadViewport> {
  late final TransformationController _camera = TransformationController(
    _fitMatrix(),
  );

  Matrix4 _fitMatrix() =>
      Matrix4.diagonal3Values(widget.fit, widget.fit, widget.fit);

  @override
  void didUpdateWidget(SpreadViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport == widget.viewport &&
        oldWidget.boardSize == widget.boardSize) {
      return;
    }
    // A zoomed reader keeps the same board point under the viewport center
    // after a rotation, keyboard resize, or the addition of a clarifier.
    final scale = _camera.value.getMaxScaleOnAxis();
    if (scale <= oldWidget.fit + 0.0001) {
      _camera.value = _fitMatrix();
      return;
    }
    final center =
        _camera.toScene(oldWidget.viewport.center(Offset.zero)) -
        oldWidget.boardOrigin +
        widget.boardOrigin;
    final nextScale = math.max(scale, widget.fit);
    final offset = widget.viewport.center(Offset.zero) - center * nextScale;
    final extent = widget.scene * nextScale;
    final dx = offset.dx.clamp(
      math.min(0.0, widget.viewport.width - extent.width),
      0.0,
    );
    final dy = offset.dy.clamp(
      math.min(0.0, widget.viewport.height - extent.height),
      0.0,
    );
    _camera.value = Matrix4.translationValues(dx.toDouble(), dy.toDouble(), 0)
      ..scaleByDouble(nextScale, nextScale, nextScale, 1);
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // ScaleGestureRecognizer uses twice the drag slop for one-finger pans.
    // Match the enclosing horizontal PageView threshold only while zoomed in
    // so a full-scale board lets horizontal swipes reach the Oracle Chat pane.
    final zoomedBoardSettings = DeviceGestureSettings(
      touchSlop: (media.gestureSettings.touchSlop ?? kTouchSlop) / 2,
    );
    return ValueListenableBuilder<Matrix4>(
      valueListenable: _camera,
      builder: (context, matrix, child) {
        final isZoomed = matrix.getMaxScaleOnAxis() > widget.fit + 0.001;
        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: isZoomed
                  ? media.copyWith(gestureSettings: zoomedBoardSettings)
                  : media,
              child: InteractiveViewer(
                key: const ValueKey('spread-viewport'),
                alignment: Alignment.topLeft,
                transformationController: _camera,
                constrained: false,
                panEnabled: isZoomed,
                minScale: widget.fit,
                maxScale: 3,
                child: child!,
              ),
            ),
            if (isZoomed)
              Positioned(
                top: 2,
                right: 8,
                child: IconButton(
                  tooltip: widget.fitLabel,
                  icon: const Icon(
                    Icons.fit_screen_outlined,
                    size: 20,
                    color: AppColors.lavender,
                  ),
                  onPressed: () => _camera.value = _fitMatrix(),
                ),
              ),
          ],
        );
      },
      child: SizedBox.fromSize(
        size: widget.scene,
        child: Center(child: RepaintBoundary(child: widget.child)),
      ),
    );
  }
}
