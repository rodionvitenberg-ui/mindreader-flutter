import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../taro_tokens.dart';

/// Полноэкранный прелоадер Tarot Tree (адаптация из `promo-tarottree`).
///
/// Отображается с самого первого кадра поверх приложения на сплошном фоне
/// [TaroColors.preloaderBackground] (`#0C101B`) с белым логотипом дерева по
/// центру и прорастающей по окружности органической веточкой (в стиле
/// стихийных веточек цифрового стола `ElementalBranchPainter`).
///
/// Длительность привязана к реальному прогреву приложения ([ready]):
/// веточка начинает прорастать сразу на 1-м кадре, не держит искусственной
/// паузы, по завершении [ready] плавно замыкает круг и распускает последние
/// листья, после чего мягко растворяется и демонтируется из дерева виджетов.
class TaroPreloader extends StatefulWidget {
  const TaroPreloader({
    super.key,
    required this.ready,
    this.predecodedLogo,
    this.onCompleted,
    this.creepDuration = const Duration(milliseconds: 1400),
    this.minFinishDuration = const Duration(milliseconds: 280),
    this.maxFinishDuration = const Duration(milliseconds: 560),
    this.hideDuration = const Duration(milliseconds: 500),
    this.readyTimeout = const Duration(seconds: 4),
  });

  static const logoAssetPath = 'assets/loader/logo.png';
  static const logoSize = 68.0;
  static const ringRadius = 65.0;
  static const canvasSize = 200.0;

  /// Точная CSS-кривая скрытия из `promo-tarottree/public/static/css/depress.css`.
  static const hideCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Преддекодирует `assets/loader/logo.png` (~10 КБ) до `runApp`, чтобы на
  /// первом же кадре Flutter логотип нарисовался синхронно без мигания после
  /// нативного сплэш-экрана.
  static Future<ui.Image?> decodeLogoAsset() async {
    try {
      final data = await rootBundle.load(logoAssetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } on Object {
      return null;
    }
  }

  /// Промис реальной инициализации приложения (шейдеры, GPU-проба, хранилище).
  final Future<void> ready;

  /// Заранее декодированный логотип для синхронного 1-го кадра (опционально).
  final ui.Image? predecodedLogo;

  /// Вызывается после полного исчезновения прелоадера.
  final VoidCallback? onCompleted;

  /// Плавный рост веточки до потолка ожидания, пока приложение грузится.
  final Duration creepDuration;

  /// Минимальная длительность доводки веточки до 100% после [ready].
  final Duration minFinishDuration;

  /// Максимальная длительность доводки (если [ready] завершился почти сразу).
  final Duration maxFinishDuration;

  /// Длительность плавного растворения (`opacity: 1 → 0`).
  final Duration hideDuration;

  /// Предохранительный таймаут, чтобы зависший канал не удерживал прелоадер.
  final Duration readyTimeout;

  @override
  State<TaroPreloader> createState() => _TaroPreloaderState();
}

class _TaroPreloaderState extends State<TaroPreloader>
    with TickerProviderStateMixin {
  /// Пока [widget.ready] ещё идёт, стебель дорастает до ~90% окружности
  /// (`0.78 / 0.86`), оставляя живой светящийся кончик активным.
  static const _creepCeiling = 0.78;

  late final AnimationController _creepController;
  late final AnimationController _finishController;
  late final AnimationController _fadeController;

  Timer? _timeoutTimer;
  bool _readyHandled = false;
  bool _finishing = false;
  bool _hiding = false;
  bool _done = false;
  double _finishStart = 0.0;

  double get _progress {
    if (_hiding || _done) return 1.0;
    if (_finishing) {
      final t = Curves.easeOutQuad.transform(_finishController.value);
      return _finishStart + (1.0 - _finishStart) * t;
    }
    return Curves.easeOutCubic.transform(_creepController.value) *
        _creepCeiling;
  }

  double get _opacity =>
      TaroPreloader.hideCurve.transform(_fadeController.value);

  @override
  void initState() {
    super.initState();
    _creepController = AnimationController(
      vsync: this,
      duration: widget.creepDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _finishController = AnimationController(
      vsync: this,
      duration: widget.maxFinishDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.hideDuration,
      value: 1.0,
      animationBehavior: AnimationBehavior.preserve,
    );

    _finishController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startHide();
      }
    });
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_done && mounted) {
        setState(() => _done = true);
        widget.onCompleted?.call();
      }
    });

    // Веточка начинает прорастать немедленно на первом кадре без пустой паузы.
    _creepController.forward();

    _timeoutTimer = Timer(widget.readyTimeout, _onReady);
    widget.ready.then(
      (_) => _onReady(),
      onError: (Object _) => _onReady(),
    );
  }

  void _onReady() {
    if (_readyHandled || !mounted) return;
    _readyHandled = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    _finishStart = _progress;
    _creepController.stop();

    final remaining = (1.0 - _finishStart).clamp(0.0, 1.0);
    final minMs = widget.minFinishDuration.inMilliseconds;
    final maxMs = widget.maxFinishDuration.inMilliseconds;
    final finishMs = (minMs + (maxMs - minMs) * remaining).round();

    _finishing = true;
    _finishController.duration = Duration(
      milliseconds: math.max(1, finishMs),
    );
    _finishController.forward(from: 0.0);
  }

  void _startHide() {
    if (_hiding || !mounted) return;
    setState(() => _hiding = true);
    _fadeController.reverse(from: 1.0);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _creepController.dispose();
    _finishController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    final logoWidget = widget.predecodedLogo != null
        ? RawImage(
            key: const ValueKey('taro-preloader-logo'),
            image: widget.predecodedLogo,
            width: TaroPreloader.logoSize,
            height: TaroPreloader.logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        : Image.asset(
            TaroPreloader.logoAssetPath,
            key: const ValueKey('taro-preloader-logo'),
            width: TaroPreloader.logoSize,
            height: TaroPreloader.logoSize,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );

    final overlay = AnimatedBuilder(
      animation: Listenable.merge([
        _creepController,
        _finishController,
        _fadeController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.clamp(0.0, 1.0),
          child: ColoredBox(
            color: TaroColors.preloaderBackground,
            child: Center(
              child: SizedBox(
                width: TaroPreloader.canvasSize,
                height: TaroPreloader.canvasSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        key: const ValueKey('taro-preloader-ring'),
                        size: const Size.square(TaroPreloader.canvasSize),
                        painter: PreloaderBranchRingPainter(
                          progress: _progress,
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: logoWidget,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('taro-preloader'),
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: TaroColors.preloaderBackground,
      ),
      child: _hiding
          ? IgnorePointer(child: overlay)
          : AbsorbPointer(child: overlay),
    );
  }
}

/// Рисует тонкий круговой трек и прорастающую по нему органическую веточку
/// с аурой, конусным стеблем, светящимся живым кончиком и распускающимися
/// листьями — по той же ботанической анатомии, что `ElementalBranchPainter`
/// на цифровом столе.
class PreloaderBranchRingPainter extends CustomPainter {
  const PreloaderBranchRingPainter({
    required this.progress,
    this.radius = TaroPreloader.ringRadius,
    this.branchColor = const Color(0xFFEDEAF5),
    this.trackColor = const Color(0x26FFFFFF),
  });

  final double progress;
  final double radius;
  final Color branchColor;
  final Color trackColor;

  /// Доля прогресса, на которой стебель полностью замыкает окружность;
  /// оставшиеся `0.14` завершают раскрытие последних листьев (как в
  /// `ElementalBranchPainter`).
  static const _stemEndProgress = 0.86;

  /// Узлы листьев вдоль окружности: `(доля пути, сторона)`.
  /// Для пути по часовой стрелке `-1.0` — наружу от кольца, `+1.0` — внутрь.
  static const _leafNodes = [
    (0.08, -1.0),
    (0.17, 1.0),
    (0.27, -1.0),
    (0.36, 1.0),
    (0.46, -1.0),
    (0.55, 1.0),
    (0.65, -1.0),
    (0.74, 1.0),
    (0.84, -1.0),
    (0.93, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // 1. Базовый тонкий трек кольца (как в promo-tarottree и на нативном сплэше).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    // 2. Органическая окружность-стебель: старт на 12 часах (-π/2), по часовой
    // стрелке, с лёгкой живой волной, затухающей к стыку на 12 часах.
    const steps = 72;
    final stemPath = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = -math.pi / 2 + t * 2 * math.pi;
      final envelope = math.sin(t * math.pi);
      final wobble =
          (math.sin(t * 8 * math.pi) * 1.5 +
              math.cos(t * 14 * math.pi) * 0.7) *
          envelope;
      final r = radius + wobble;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        stemPath.moveTo(x, y);
      } else {
        stemPath.lineTo(x, y);
      }
    }

    final metric = stemPath.computeMetrics().first;
    final stemFraction = Curves.easeInOutSine.transform(
      (p / _stemEndProgress).clamp(0.0, 1.0),
    );
    final grownLen = metric.length * stemFraction;
    if (grownLen <= 0) return;

    // 3. Мягкая светящаяся аура под растущим стеблем.
    final auraPaint = Paint()
      ..color = branchColor.withValues(alpha: 0.24)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawPath(metric.extractPath(0, grownLen), auraPaint);

    // 4. Конусный стебель: плотнее у истока, тоньше к растущему кончику.
    const slices = 18;
    for (var i = 0; i < slices; i++) {
      final t0 = i / slices;
      final t1 = (i + 1) / slices;
      final stemPaint = Paint()
        ..color = branchColor.withValues(alpha: 0.88 - 0.12 * t0)
        ..strokeWidth = 2.8 - 1.5 * t0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        metric.extractPath(grownLen * t0, grownLen * t1),
        stemPaint,
      );
    }

    // 5. Живой прорастающий кончик, пока стебель активно тянется.
    if (stemFraction > 0.01 && stemFraction < 0.99) {
      final tip = metric.getTangentForOffset(grownLen);
      if (tip != null) {
        final tipAlpha = math
            .min(stemFraction / 0.08, (1 - stemFraction) / 0.10)
            .clamp(0.0, 1.0);
        canvas.drawCircle(
          tip.position,
          4.8,
          Paint()
            ..color = branchColor.withValues(alpha: 0.38 * tipAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
        );
        canvas.drawCircle(
          tip.position,
          2.1,
          Paint()
            ..color = Color.lerp(branchColor, Colors.white, 0.55)!
                .withValues(alpha: 0.95 * tipAlpha),
        );
      }
    }

    // 6. Черешки и распускающиеся листья с тонкой центральной прожилкой.
    final twigPaint = Paint()
      ..color = branchColor.withValues(alpha: 0.82)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leafPaint = Paint()
      ..color = branchColor.withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;

    for (final (position, side) in _leafNodes) {
      // Точный момент прогресса, когда easeInOutSine-кончик проходит узел.
      final reach = (math.acos(1 - 2 * position) / math.pi) * _stemEndProgress;
      final age = ((p - reach) / 0.26).clamp(0.0, 1.0);
      if (age > 0) {
        _paintLeaf(canvas, metric, position, side, age, twigPaint, leafPaint);
      }
    }
  }

  void _paintLeaf(
    Canvas canvas,
    ui.PathMetric stem,
    double position,
    double side,
    double age,
    Paint wood,
    Paint foliage,
  ) {
    final joint = stem.getTangentForOffset(stem.length * position);
    if (joint == null) return;
    final forward = joint.vector;
    final outward = Offset(-forward.dy, forward.dx) * side;
    // Наружные листья чуть крупнее, внутренние — изящнее, чтобы не касаться дерева.
    final unit = side < 0 ? 13.5 : 10.0;

    final sprout = Curves.easeOut.transform((age / 0.36).clamp(0.0, 1.0));
    final root =
        joint.position + (forward * 0.22 + outward * 0.40) * unit * sprout;
    canvas.drawLine(joint.position, root, wood);

    final bloom = Curves.easeOutCubic.transform(
      ((age - 0.18) / 0.82).clamp(0.0, 1.0),
    );
    if (bloom == 0) return;

    final axis = (forward * 0.62 + outward * 0.78) * unit * bloom;
    final width = Offset(-axis.dy, axis.dx) * (0.40 * bloom);
    final tip = root + axis;
    final upper = root + axis * 0.52 + width;
    final lower = root + axis * 0.38 - width;
    canvas.drawPath(
      Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(upper.dx, upper.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(lower.dx, lower.dy, root.dx, root.dy)
        ..close(),
      foliage,
    );

    // Светлая прожилка вдоль раскрывающегося листа.
    canvas.drawLine(
      root,
      root + axis * 0.72,
      Paint()
        ..color = Color.lerp(branchColor, Colors.white, 0.40)!
            .withValues(alpha: 0.48 * bloom)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(PreloaderBranchRingPainter old) =>
      old.progress != progress ||
      old.radius != radius ||
      old.branchColor != branchColor ||
      old.trackColor != trackColor;
}
