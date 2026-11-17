import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/theme/app_colors.dart';
import 'natal_wheel_controls.dart';
import 'natal_wheel_geometry.dart';
import 'natal_wheel_painter.dart';
import 'planet_aspect_inspector_card.dart';

/// Phase 3 — the living natal wheel: 4-stage choreography (ring calibration,
/// house sweep, planet lock-on, aspect flashes), live house-system morphing,
/// tap-to-inspect and an optional transits overlay.
class NatalWheelWidget extends StatefulWidget {
  const NatalWheelWidget({required this.chart, this.now, super.key});

  final NatalChart chart;

  /// Fixed epoch for the transit overlay (tests); defaults to `DateTime.now()`.
  final DateTime? now;

  @override
  State<NatalWheelWidget> createState() => _NatalWheelWidgetState();
}

class _NatalWheelWidgetState extends State<NatalWheelWidget>
    with TickerProviderStateMixin {
  static const _choreographyDuration = Duration(milliseconds: 2200);
  static const _morphDuration = Duration(milliseconds: 450);
  static const _pulseDuration = Duration(milliseconds: 6000);

  late final AnimationController _choreography;
  late final AnimationController _pulse;
  late final AnimationController _houseMorph;

  List<double> _morphFrom = const [];
  List<double> _morphTo = const [];

  PlanetId? _selected;
  bool _showTransits = false;
  Map<PlanetId, double>? _transits;

  bool _lockHapticFired = false;
  int _flashHapticsFired = 0;

  @override
  void initState() {
    super.initState();
    _choreography = AnimationController(
      vsync: this,
      duration: _choreographyDuration,
    );
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat();
    _houseMorph = AnimationController(
      vsync: this,
      duration: _morphDuration,
      value: 1,
    );
    _morphFrom = widget.chart.houseCusps;
    _morphTo = widget.chart.houseCusps;
    _choreography.addListener(_onChoreographyTick);
    _choreography.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant NatalWheelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // House-system switch keeps the profile id: morph the spokes in place.
    if (!listEquals(oldWidget.chart.houseCusps, widget.chart.houseCusps)) {
      _morphFrom = _currentCusps();
      _morphTo = widget.chart.houseCusps;
      _houseMorph.forward(from: 0);
    }
    // A different profile replays the whole 2200 ms choreography.
    if (oldWidget.chart.id != widget.chart.id) {
      _selected = null;
      _transits = null;
      _showTransits = false;
      _replay();
    }
  }

  @override
  void dispose() {
    _choreography.removeListener(_onChoreographyTick);
    _choreography.dispose();
    _pulse.dispose();
    _houseMorph.dispose();
    super.dispose();
  }

  // ---- choreography haptics -------------------------------------------

  void _onChoreographyTick() {
    final t = _choreography.value;
    if (!_lockHapticFired && t >= 0.30) {
      _lockHapticFired = true;
      HapticFeedback.mediumImpact();
    }
    final total = widget.chart.aspects.length;
    var flashes = 0;
    for (var i = 0; i < total; i++) {
      if (t >= aspectFlashBegin(i, total)) flashes++;
    }
    if (flashes > _flashHapticsFired) {
      _flashHapticsFired = flashes;
      HapticFeedback.selectionClick();
    }
  }

  void _replay() {
    _lockHapticFired = false;
    _flashHapticsFired = 0;
    _choreography.forward(from: 0);
  }

  void _handleReplay() {
    HapticFeedback.selectionClick();
    _replay();
  }

  // ---- house morph -----------------------------------------------------

  List<double> _currentCusps() {
    if (_morphFrom.length != 12 || _morphTo.length != 12) {
      return widget.chart.houseCusps;
    }
    final progress =
        Curves.easeOutCubic.transform(_houseMorph.value.clamp(0.0, 1.0));
    return lerpCusps(_morphFrom, _morphTo, progress);
  }

  // ---- interaction -----------------------------------------------------

  double _ascendantLongitude(NatalChart chart) {
    for (final position in chart.planets) {
      if (position.planet == PlanetId.ascendant) return position.longitude;
    }
    return chart.houseCusps.isEmpty ? 0 : chart.houseCusps.first;
  }

  void _selectPlanet(PlanetId? planet) {
    HapticFeedback.selectionClick();
    setState(() => _selected = planet);
  }

  void _handleWheelTap(Offset local, Size size) {
    final chart = widget.chart;
    final bodies = [
      for (final position in chart.planets)
        if (position.planet.isBody) position,
    ];
    if (bodies.isEmpty) return;

    final display = resolveCollisions([for (final p in bodies) p.longitude]);
    final center = size.center(Offset.zero);
    final track = wheelRadius(size) * wheelPlanetFactor;
    final asc = _ascendantLongitude(chart);

    PlanetId? hit;
    var best = double.infinity;
    for (var i = 0; i < bodies.length; i++) {
      final node = pointOnCircle(
        center,
        track,
        chartScreenAngle(display[i], asc),
      );
      final distance = (node - local).distance;
      if (distance < best) {
        best = distance;
        hit = bodies[i].planet;
      }
    }

    if (best > 26.0) {
      if (_selected != null) _selectPlanet(null);
      return;
    }
    _selectPlanet(hit == _selected ? null : hit);
  }

  void _toggleTransits() {
    HapticFeedback.selectionClick();
    setState(() {
      _showTransits = !_showTransits;
      if (_showTransits) _transits ??= _computeTransits();
    });
  }

  Map<PlanetId, double> _computeTransits() {
    final now = (widget.now ?? DateTime.now()).toUtc();
    return {
      for (final planet in PlanetId.values)
        if (planet.isBody)
          planet: NatalCalculatorService.computeEclipticLongitude(planet, now),
    };
  }

  double _siderealDegrees(NatalChart chart) =>
      NatalCalculatorService.localSiderealTime(
        chart.birthDateUtc,
        eastLongitude: chart.longitude,
      );
  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NatalWheelHeader(
            subtitle:
                '${chart.cityName.toUpperCase()} · ${chart.houseSystem.label}',
            onReplay: _handleReplay,
            onToggleTransits: _toggleTransits,
            transitsActive: _showTransits,
          ),
          const SizedBox(height: 10),
          _buildCanvas(chart),
          const SizedBox(height: 12),
          NatalPlanetChipBar(
            planets: chart.planets,
            selected: _selected,
            onSelect: _selectPlanet,
          ),
          const SizedBox(height: 10),
          _buildInspector(chart),
        ],
      ),
    );
  }

  Widget _buildCanvas(NatalChart chart) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleWheelTap(details.localPosition, size),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _houseMorph,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('natal-wheel-canvas'),
                  painter: NatalWheelPainter(
                    chart: chart,
                    ascendantLongitude: _ascendantLongitude(chart),
                    houseCusps: _currentCusps(),
                    choreography: _choreography,
                    pulse: _pulse,
                    houseMorph: _houseMorph,
                    siderealTimeDegrees: _siderealDegrees(chart),
                    selectedPlanet: _selected,
                    transitLongitudes: _showTransits ? _transits : null,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInspector(NatalChart chart) {
    final selected = _selected;
    if (selected == null) {
      return Text(
        'TAP A PLANET TO INSPECT ITS ASPECTS',
        textAlign: TextAlign.center,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 7.5,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      );
    }
    return PlanetAspectInspectorCard(
      position: chart.planets.firstWhere((p) => p.planet == selected),
      aspects: [
        for (final aspect in chart.aspects)
          if (aspect.bodyA == selected || aspect.bodyB == selected) aspect,
      ],
      onClose: () => _selectPlanet(null),
    );
  }
}
