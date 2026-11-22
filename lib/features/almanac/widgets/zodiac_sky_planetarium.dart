import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/data/celestial_sky_data.dart';
import '../../../core/data/zodiac_almanac_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro.dart';

const _radians = math.pi / 180;
const _lavender = Color(0xffc6b2f1);
const _ink = Color(0xff15101f);
double _delta(double a, double b) => (b - a + 180) % 360 - 180;
double _eclipticDec(double ra) =>
    math.atan(math.tan(23.43928 * _radians) * math.sin(ra * _radians)) /
    _radians;

class _Aim {
  const _Aim(this.ra, this.dec);
  factory _Aim.at(ZodiacSign sign) {
    final c = zodiacSky[sign]!;
    return _Aim(c.centerRa, c.centerDec);
  }
  final double ra, dec;
  _Aim travel(_Aim end, double t) {
    final lon = ra + _delta(ra, end.ra) * t;
    return _Aim(
      lon,
      _eclipticDec(lon) +
          ui.lerpDouble(
            dec - _eclipticDec(ra),
            end.dec - _eclipticDec(end.ra),
            t,
          )!,
    );
  }
}

class _SkyCamera extends ChangeNotifier {
  _SkyCamera(this.aim, this.focus) : extent = _SkyPainter._extents[focus]!;
  Size extent;
  _Aim aim;
  ZodiacSign focus;
  double glow = 0;
  Rect aperture = Rect.zero;
  ui.Image? image;
  void repaint() => notifyListeners();
}

class ZodiacSkyPlanetarium extends StatefulWidget {
  const ZodiacSkyPlanetarium({
    super.key,
    required this.sign,
    required this.header,
    required this.language,
    required this.onChanged,
    required this.onExplore,
  });
  final ZodiacSign sign;
  final Widget header;
  final AppLanguage language;
  final ValueChanged<ZodiacSign> onChanged;
  final VoidCallback onExplore;
  @override
  State<ZodiacSkyPlanetarium> createState() => _ZodiacSkyPlanetariumState();
}

class _ZodiacSkyPlanetariumState extends State<ZodiacSkyPlanetarium>
    with TickerProviderStateMixin {
  late final _camera = _SkyCamera(_Aim.at(widget.sign), widget.sign);
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late _Aim _from, _to;
  late Size _fromExtent, _toExtent;
  late ZodiacSign _dragSign;
  double _dragPixels = 0;
  final _chips = {for (final entry in zodiacAlmanac) entry.sign: GlobalKey()};
  final _strip = ScrollController();
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onImageError);
  ImageInfo? _imageInfo;

  @override
  void initState() {
    super.initState();
    _flight.addListener(() {
      final t = Curves.easeInOutCubic.transform(_flight.value);
      _camera.aim = _from.travel(_to, t);
      _camera.extent = Size.lerp(_fromExtent, _toExtent, t)!;
      _camera.repaint();
    });
    _flight.addStatusListener((s) {
      if (s == AnimationStatus.completed) _ignite();
    });
    _reveal.addListener(() {
      _camera.glow = Curves.easeOut.transform(_reveal.value);
      _camera.repaint();
    });
    _centerChip(animate: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadArt();
    if (!_flight.isAnimating && _reveal.isDismissed) _ignite();
  }

  @override
  void didUpdateWidget(ZodiacSkyPlanetarium oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sign != widget.sign) {
      _loadArt();
      animateToSign(widget.sign);
      _centerChip();
    }
  }

  void _centerChip({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _chips[widget.sign]?.currentContext;
      if (target != null && _strip.hasClients) {
        _strip.position.ensureVisible(
          target.findRenderObject()!,
          alignment: 0.5,
          duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _loadArt() {
    final next = AssetImage('assets/zodiac_art/${widget.sign.name}.png')
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == next.key) return;
    _stream?.removeListener(_listener);
    _stream = next;
    _clearArt();
    next.addListener(_listener);
  }

  void _clearArt() {
    _camera.image = null;
    _imageInfo?.dispose();
    _imageInfo = null;
    _camera.repaint();
  }

  void _onImage(ImageInfo image, bool synchronous) {
    _imageInfo?.dispose();
    _imageInfo = image;
    _camera.image = image.image;
    _camera.repaint();
  }

  void _onImageError(Object error, StackTrace? stack) => _clearArt();

  void _ignite() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  void _interrupt() {
    _flight.stop();
    _reveal.stop();
    _camera.glow = 0;
    _camera.repaint();
  }

  void animateToSign(ZodiacSign sign) {
    _interrupt();
    _camera.focus = sign;
    _from = _camera.aim;
    _fromExtent = _camera.extent;
    _to = _Aim.at(sign);
    _toExtent = _SkyPainter._extents[sign]!;
    if (MediaQuery.disableAnimationsOf(context)) {
      _camera.aim = _to;
      _camera.extent = _toExtent;
      _ignite();
    } else {
      _flight.forward(from: 0);
    }
  }

  ZodiacSign _neighbor(int direction) {
    final i = zodiacAlmanac.indexWhere((e) => e.sign == _dragSign);
    return zodiacAlmanac[(i + direction) % zodiacAlmanac.length].sign;
  }

  void _dragStart(DragStartDetails details) {
    _interrupt();
    _from = _camera.aim;
    _fromExtent = _camera.extent;
    _dragPixels = 0;
    _dragSign = zodiacAlmanac
        .reduce(
          (a, b) =>
              _delta(_from.ra, zodiacSky[a.sign]!.centerRa).abs() <=
                  _delta(_from.ra, zodiacSky[b.sign]!.centerRa).abs()
              ? a
              : b,
        )
        .sign;
  }

  void _dragUpdate(DragUpdateDetails details) {
    _dragPixels += details.primaryDelta ?? 0;
    final travelWidth = math.max(1.0, _camera.aperture.width * 0.80);
    final next = _neighbor(_dragPixels >= 0 ? 1 : -1);
    final t = (_dragPixels.abs() / travelWidth).clamp(0.0, 1.0);
    _camera.aim = _from.travel(_Aim.at(next), t);
    _camera.extent = Size.lerp(_fromExtent, _SkyPainter._extents[next]!, t)!;
    _camera.repaint();
  }

  void _choose(ZodiacSign sign) {
    if (sign == widget.sign) {
      animateToSign(sign);
    } else {
      widget.onChanged(sign);
    }
  }

  void _dragEnd(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    final flick = speed.abs() > 360;
    final step = flick || _dragPixels.abs() > _camera.aperture.width * 0.14;
    _choose(
      step ? _neighbor((flick ? speed : _dragPixels) >= 0 ? 1 : -1) : _dragSign,
    );
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _imageInfo?.dispose();
    _flight.dispose();
    _reveal.dispose();
    _strip.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = zodiacEntryFor(widget.sign);
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 450;
        return ClipRect(
          child: CustomMultiChildLayout(
            delegate: _AtlasLayout(_camera),
            children: [
              LayoutId(
                id: _Layer.sky,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _dragStart,
                  onHorizontalDragUpdate: _dragUpdate,
                  onHorizontalDragEnd: _dragEnd,
                  onHorizontalDragCancel: () => _choose(widget.sign),
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _SkyPainter(_camera)),
                  ),
                ),
              ),
              LayoutId(
                id: _Layer.header,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.header,
                    SingleChildScrollView(
                      controller: _strip,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          for (final sign in zodiacAlmanac)
                            Padding(
                              key: _chips[sign.sign],
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                key: ValueKey('zodiac-sign-${sign.sign.name}'),
                                label: _symbolLabel(
                                  sign.glyph,
                                  _name(sign, widget.language),
                                ),
                                selected: widget.sign == sign.sign,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _ink.withValues(alpha: .80),
                                selectedColor: const Color(0xff504160),
                                onSelected: (_) => _choose(sign.sign),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              LayoutId(
                id: _Layer.info,
                child: _SkyInfo(
                  entry: entry,
                  language: widget.language,
                  compact: compact,
                  onExplore: widget.onExplore,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Text _symbolLabel(String glyph, String label, {TextStyle? style}) => Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: glyph,
        style: const TextStyle(fontFamily: 'ZodiacSymbols'),
      ),
      TextSpan(text: ' $label'),
    ],
  ),
  style: style,
);
const _ruNames = [
  'Овен',
  'Телец',
  'Близнецы',
  'Рак',
  'Лев',
  'Дева',
  'Весы',
  'Скорпион',
  'Стрелец',
  'Козерог',
  'Водолей',
  'Рыбы',
];
String _name(ZodiacSignEntry entry, AppLanguage language) =>
    language == AppLanguage.ru
    ? _ruNames[zodiacAlmanac.indexOf(entry)]
    : entry.name;

enum _Layer { sky, header, info }

class _AtlasLayout extends MultiChildLayoutDelegate {
  _AtlasLayout(this.camera);
  final _SkyCamera camera;
  @override
  void performLayout(Size size) {
    final top = layoutChild(
      _Layer.header,
      BoxConstraints.tightFor(width: size.width),
    );
    final bottom = layoutChild(
      _Layer.info,
      BoxConstraints(
        maxWidth: math.min(472, size.width),
        maxHeight: size.height * 0.46,
      ),
    );
    positionChild(_Layer.header, Offset.zero);
    positionChild(
      _Layer.info,
      Offset((size.width - bottom.width) / 2, size.height - bottom.height),
    );
    camera.aperture = Rect.fromLTWH(
      0,
      top.height,
      size.width,
      math.max(1, size.height - top.height - bottom.height),
    );
    layoutChild(_Layer.sky, BoxConstraints.tight(size));
    positionChild(_Layer.sky, Offset.zero);
  }

  @override
  bool shouldRelayout(_AtlasLayout oldDelegate) => oldDelegate.camera != camera;
}

class _SkyInfo extends StatelessWidget {
  const _SkyInfo({
    required this.entry,
    required this.language,
    required this.compact,
    required this.onExplore,
  });
  final ZodiacSignEntry entry;
  final AppLanguage language;
  final bool compact;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final c = zodiacSky[entry.sign]!;
    final ru = language == AppLanguage.ru;
    final start = DateTime.parse(c.solarIngress),
        end = DateTime.parse(c.solarEgress);
    String date(DateTime d) {
      const en = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      const months = [
        'янв',
        'фев',
        'мар',
        'апр',
        'май',
        'июн',
        'июл',
        'авг',
        'сен',
        'окт',
        'ноя',
        'дек',
      ];
      return ru
          ? '${d.day} ${months[d.month - 1]}'
          : '${en[d.month - 1]} ${d.day}';
    }

    final year = start.year == end.year
        ? '${start.year}'
        : '${start.year}–${end.year}';
    final sun =
        "${ru ? 'Солнце' : 'Sun'} · ${date(start)} – ${date(end)}, $year";
    final star = c.stars[c.brightest];
    final title = _symbolLabel(
      entry.glyph,
      _name(entry, language),
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(color: const Color(0xfff4eade)),
    );
    final explore = TextButton(
      key: const ValueKey('zodiac-explore'),
      onPressed: onExplore,
      style: TextButton.styleFrom(
        foregroundColor: _lavender,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: _symbolLabel(
        '✦',
        ru ? 'О ЗНАКЕ И ЕГО МИФАХ' : 'EXPLORE SIGN & LORE',
        style: const TextStyle(fontSize: 11, letterSpacing: 0.7),
      ),
    );
    Widget badge(String text) => DecoratedBox(
      decoration: BoxDecoration(
        color: _lavender.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: _lavender),
        ),
      ),
    );
    final badges = Wrap(
      spacing: 6,
      runSpacing: 3,
      children: [
        badge(AppStrings.t(language, 'almanac.${entry.element.name}')),
        badge(AppStrings.t(language, 'almanac.${entry.modality.name}')),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, compact ? 4 : 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: .88),
          border: Border.all(color: _lavender.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SingleChildScrollView(
          primary: false,
          padding: EdgeInsets.fromLTRB(14, compact ? 6 : 10, 14, 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [title, badges],
              ),
              Text(
                sun,
                style: const TextStyle(
                  color: TaroColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                "${ru ? 'Ярчайшая звезда' : 'Brightest star'} · ${star.name ?? 'HIP ${star.hip}'}",
                style: const TextStyle(
                  color: TaroColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              explore,
            ],
          ),
        ),
      ),
    );
  }
}

class _Direction {
  const _Direction(this.x, this.y, this.z);
  factory _Direction.equatorial(double ra, double dec) {
    final lon = ra * _radians, lat = dec * _radians;
    final band = math.cos(lat);
    return _Direction(
      band * math.cos(lon),
      band * math.sin(lon),
      math.sin(lat),
    );
  }
  final double x, y, z;
}

class _Projection {
  _Projection(_Aim aim, this.origin, this.scale)
    : sinRa = math.sin(aim.ra * _radians),
      cosRa = math.cos(aim.ra * _radians),
      sinDec = math.sin(aim.dec * _radians),
      cosDec = math.cos(aim.dec * _radians);
  final double sinRa, cosRa, sinDec, cosDec, scale;
  final Offset origin;

  Offset? project(_Direction d) {
    final meridian = cosRa * d.x + sinRa * d.y;
    final depth = cosDec * meridian + sinDec * d.z;
    if (depth <= 0) return null;
    final k = 2 * scale / (1 + depth);
    return Offset(
      origin.dx + k * (sinRa * d.x - cosRa * d.y),
      origin.dy + k * (sinDec * meridian - cosDec * d.z),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.camera) : super(repaint: camera);
  final _SkyCamera camera;
  static final _directions = {
    for (final s in [
      ...skyBackgroundStars,
      ...zodiacSky.values.expand((c) => c.stars),
    ])
      s.hip: _Direction.equatorial(s.ra, s.dec),
  };
  static final _ecliptic = List.generate(361, (i) {
    final sin = math.sin(i * _radians);
    return _Direction(
      math.cos(i * _radians),
      sin * math.cos(23.43928 * _radians),
      sin * math.sin(23.43928 * _radians),
    );
  });
  static final _extents = {
    for (final sign in zodiacSky.keys) sign: _measure(sign),
  };
  static Size _measure(ZodiacSign sign) {
    final p = _Projection(_Aim.at(sign), Offset.zero, 1);
    double x = 0, y = 0;
    for (final star in zodiacSky[sign]!.stars) {
      final at = p.project(_directions[star.hip]!)!;
      x = math.max(x, at.dx.abs());
      y = math.max(y, at.dy.abs());
    }
    return Size(x, y);
  }

  final _dot = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
  final _art = Paint()
    ..blendMode = BlendMode.screen
    ..filterQuality = FilterQuality.low;
  static const _night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xff06060b), Color(0xff120e1d)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _night.createShader(rect));
    final aperture = camera.aperture;
    if (aperture.isEmpty) return;
    final extent = camera.extent;
    final normal = aperture.shortestSide / (4 * math.tan(52 * _radians / 4));
    final scale = math.min(
      normal,
      math.min(
        aperture.width * .43 / extent.width,
        aperture.height * .43 / extent.height,
      ),
    );
    final p = _Projection(camera.aim, aperture.center, scale);
    final visible = rect.inflate(9);
    for (final star in skyBackgroundStars) {
      final at = p.project(_directions[star.hip]!);
      if (at != null && visible.contains(at)) _star(canvas, at, star, .65, 0);
    }
    _line
      ..color = _lavender.withValues(alpha: .15)
      ..strokeWidth = .8;
    for (int i = 0; i < 360; i += 2) {
      final a = p.project(_ecliptic[i]), b = p.project(_ecliptic[i + 1]);
      if (a != null &&
          b != null &&
          (visible.contains(a) || visible.contains(b))) {
        canvas.drawLine(a, b, _line);
      }
    }
    for (final entry in zodiacSky.entries) {
      final c = entry.value;
      final points = [
        for (final star in c.stars) p.project(_directions[star.hip]!),
      ];
      if (!points.any((at) => at != null && visible.contains(at))) continue;
      final light = entry.key == camera.focus ? camera.glow : 0.0;
      if (light > 0) _figure(canvas, c, points, light);
      _line
        ..color = _lavender.withValues(alpha: .22 + .5 * light)
        ..strokeWidth = .8 + light * .42;
      for (final (i, j) in c.edges) {
        final a = points[i], b = points[j];
        if (a != null && b != null) canvas.drawLine(a, b, _line);
      }
      for (var i = 0; i < points.length; i++) {
        final at = points[i];
        if (at != null && visible.contains(at)) {
          _star(canvas, at, c.stars[i], .22 + .78 * light, light);
        }
      }
    }
  }

  void _star(
    Canvas canvas,
    Offset at,
    SkyStar s,
    double opacity,
    double light,
  ) {
    final r = (1.85 - s.magnitude * .27).clamp(.47, 2.4) + light * .52;
    final tint = s.bv < .25
        ? const Color(0xffcbdfff)
        : s.bv > .72
        ? const Color(0xffffe6be)
        : const Color(0xffddd2f4);
    if (light > 0.01) {
      _glow.color = Color.lerp(
        tint,
        _lavender,
        .35,
      )!.withValues(alpha: light * .65);
      canvas.drawCircle(at, r * 2.4, _glow);
    }
    _dot.color = tint.withValues(alpha: opacity);
    canvas.drawCircle(at, r, _dot);
  }

  void _figure(
    Canvas canvas,
    SkyConstellation c,
    List<Offset?> points,
    double light,
  ) {
    final a = c.artAnchorStars;
    final o = points[a[0].$1], p = points[a[1].$1], q = points[a[2].$1];
    if (o == null || p == null || q == null) return;
    // Solve the image-to-screen affine map from the three measured HIP anchors.
    final u = Offset(a[1].$2 - a[0].$2, a[1].$3 - a[0].$3);
    final v = Offset(a[2].$2 - a[0].$2, a[2].$3 - a[0].$3);
    final det = u.dx * v.dy - u.dy * v.dx;
    final ex = ((p - o) * v.dy - (q - o) * u.dy) / det;
    final ey = ((q - o) * u.dx - (p - o) * v.dx) / det;
    final corner = o - ex * a[0].$2 - ey * a[0].$3;
    canvas.save();
    canvas.transform(
      Float64List.fromList([
        ex.dx,
        ex.dy,
        0,
        0,
        ey.dx,
        ey.dy,
        0,
        0,
        0,
        0,
        1,
        0,
        corner.dx,
        corner.dy,
        0,
        1,
      ]),
    );
    final image = camera.image;
    if (image != null) {
      _art.color = Colors.white.withValues(alpha: .34 * light);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1, 1),
        _art,
      );
    } else {
      _line
        ..color = _lavender.withValues(alpha: .34 * light)
        ..strokeWidth = .004;
      final path = Path();
      for (final outline in c.outlines) {
        path.moveTo(outline[0] / 100, outline[1] / 100);
        for (int i = 2; i < outline.length; i += 2) {
          path.lineTo(outline[i] / 100, outline[i + 1] / 100);
        }
        path.close();
      }
      canvas.drawPath(path, _line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => true; // Includes HUD/viewport layout changes.
}
