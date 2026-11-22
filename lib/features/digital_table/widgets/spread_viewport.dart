import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../design_system/taro_tokens.dart';

/// The board stays in card coordinates. Only the camera scales or moves.
class SpreadViewport extends StatefulWidget {
  const SpreadViewport({
    super.key,
    required this.viewport,
    required this.boardSize,
    required this.baseBoardSize,
    required this.readingRevision,
    required this.fitLabel,
    required this.child,
  });

  final Size viewport;
  final Size boardSize;
  final Size baseBoardSize;
  final int readingRevision;
  final String fitLabel;
  final Widget child;

  double get inset => math.min(12.0, viewport.shortestSide / 8);

  double get initialScale => math.min(
    1.0,
    math.min(
      (viewport.width - 2 * inset) / baseBoardSize.width,
      (viewport.height - 2 * inset) / baseBoardSize.height,
    ),
  );

  Size get _baseScene => viewport / initialScale;

  // Additional rows extend the scene below the base spread. Its origin stays
  // fixed so a new card cannot re-center or scale the cards already visible.
  Offset get boardOrigin =>
      _baseScene.center(Offset.zero) - baseBoardSize.center(Offset.zero);

  Size get scene => Size(
    math.max(
      _baseScene.width,
      boardOrigin.dx + boardSize.width + inset / initialScale,
    ),
    math.max(
      _baseScene.height,
      boardOrigin.dy + boardSize.height + inset / initialScale,
    ),
  );

  double get fit =>
      math.min(viewport.width / scene.width, viewport.height / scene.height);

  @override
  State<SpreadViewport> createState() => SpreadViewportState();
}

class SpreadViewportState extends State<SpreadViewport>
    with SingleTickerProviderStateMixin {
  late final TransformationController _camera = TransformationController(
    _matrixAtScale(widget.initialScale),
  )..addListener(_storeCamera);
  PageStorageBucket? _storage;
  Object get _storageKey =>
      ('spread-camera', widget.readingRevision, widget.viewport);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final storage = PageStorage.maybeOf(context);
    if (identical(_storage, storage)) return;
    _storage = storage;
    final saved = storage?.readState(context, identifier: _storageKey);
    if (saved is Matrix4) _camera.value = _clampMatrix(saved);
  }

  void _storeCamera() {
    _storage?.writeState(
      context,
      _camera.value.clone(),
      identifier: _storageKey,
    );
  }

  late final _pan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(_panFrame);
  late Offset _panStart;
  late Offset _panEnd;
  late double _panScale;

  /// Bring a distant deal within reach, preserving the reader's zoom.
  void bringIntoView(Offset cardCenter) {
    final matrix = _camera.value;
    final point = MatrixUtils.transformPoint(
      matrix,
      widget.boardOrigin + cardCenter,
    );
    final bounds = Offset.zero & widget.viewport;
    if (bounds.deflate(8).contains(point)) return;
    _panScale = matrix.getMaxScaleOnAxis();
    _panStart = Offset(matrix.storage[12], matrix.storage[13]);
    final desired = _panStart + bounds.center - point;
    final extent = widget.scene * _panScale;
    _panEnd = Offset(
      desired.dx.clamp(math.min(0.0, bounds.width - extent.width), 0.0),
      desired.dy.clamp(math.min(0.0, bounds.height - extent.height), 0.0),
    );
    _pan.forward(from: 0);
  }

  void _panFrame() {
    final offset = Offset.lerp(
      _panStart,
      _panEnd,
      Curves.easeOut.transform(_pan.value),
    )!;
    _camera.value = Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..scaleByDouble(_panScale, _panScale, _panScale, 1);
  }

  Matrix4 _matrixAtScale(double scale) =>
      Matrix4.diagonal3Values(scale, scale, scale);

  Matrix4 _clampMatrix(Matrix4 matrix) {
    final scale = math.max(widget.fit, matrix.getMaxScaleOnAxis());
    final extent = widget.scene * scale;
    final dx = matrix.storage[12].clamp(
      math.min(0.0, widget.viewport.width - extent.width),
      0.0,
    );
    final dy = matrix.storage[13].clamp(
      math.min(0.0, widget.viewport.height - extent.height),
      0.0,
    );
    return Matrix4.translationValues(dx.toDouble(), dy.toDouble(), 0)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  void didUpdateWidget(SpreadViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport == widget.viewport &&
        oldWidget.baseBoardSize == widget.baseBoardSize) {
      if (oldWidget.scene.height > widget.scene.height ||
          oldWidget.scene.width > widget.scene.width) {
        _pan.stop();
        _camera.value = _clampMatrix(_camera.value);
      }
      return;
    }
    _pan.stop();
    final scale = _camera.value.getMaxScaleOnAxis();
    final center =
        _camera.toScene(oldWidget.viewport.center(Offset.zero)) -
        oldWidget.boardOrigin +
        widget.boardOrigin;
    final nextScale = scale <= oldWidget.initialScale + 0.001
        ? widget.initialScale
        : math.max(scale, widget.fit);
    final offset = widget.viewport.center(Offset.zero) - center * nextScale;
    _camera.value = _clampMatrix(
      Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..scaleByDouble(nextScale, nextScale, nextScale, 1),
    );
  }

  @override
  void dispose() {
    _pan.dispose();
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
        final scale = matrix.getMaxScaleOnAxis();
        final isZoomed = scale > widget.initialScale + 0.001;
        final canPan = scale > widget.fit + 0.001;
        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: isZoomed
                  ? media.copyWith(gestureSettings: zoomedBoardSettings)
                  : media,
              child: InteractiveViewer(
                key: const ValueKey('spread-viewport'),
                onInteractionStart: (_) => _pan.stop(),
                alignment: Alignment.topLeft,
                transformationController: _camera,
                constrained: false,
                panEnabled: canPan,
                panAxis: isZoomed ? PanAxis.free : PanAxis.vertical,
                minScale: widget.fit,
                maxScale: 3,
                child: child!,
              ),
            ),
            if (canPan)
              Positioned(
                top: 2,
                right: 8,
                child: IconButton(
                  tooltip: widget.fitLabel,
                  icon: const Icon(
                    Icons.fit_screen_outlined,
                    size: 20,
                    color: TaroColors.lavender,
                  ),
                  onPressed: () => _camera.value = _matrixAtScale(widget.fit),
                ),
              ),
          ],
        );
      },
      child: SizedBox.fromSize(
        size: widget.scene,
        child: Stack(
          children: [
            Positioned(
              left: widget.boardOrigin.dx,
              top: widget.boardOrigin.dy,
              width: widget.boardSize.width,
              height: widget.boardSize.height,
              child: RepaintBoundary(child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
