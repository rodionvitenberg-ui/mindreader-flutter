import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/natal_chart.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'widgets/astral_gradient_button.dart';
import 'widgets/astral_house_selector.dart';

/// Aspect filter inside the full natal profile sheet.
enum _AspectFilter { all, harmony, tension }

/// Full natal profile detail sheet: the Big Three spotlight, a live
/// house-system switch, the complete placement ledger and the aspect matrix.
class NatalProfileDetailSheet extends StatefulWidget {
  const NatalProfileDetailSheet({
    required this.chart,
    this.onHouseSystemChanged,
    super.key,
  });

  final NatalChart chart;

  /// Persists a house-system flip on the owning (active) profile.
  final ValueChanged<HouseSystem>? onHouseSystemChanged;

  static Future<void> show(
    BuildContext context, {
    required NatalChart chart,
    ValueChanged<HouseSystem>? onHouseSystemChanged,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => NatalProfileDetailSheet(
        chart: chart,
        onHouseSystemChanged: onHouseSystemChanged,
      ),
    );
  }

  @override
  State<NatalProfileDetailSheet> createState() =>
      _NatalProfileDetailSheetState();
}

class _NatalProfileDetailSheetState extends State<NatalProfileDetailSheet> {
  late NatalChart _chart = widget.chart;
  _AspectFilter _filter = _AspectFilter.all;

  void _switchHouse(HouseSystem system) {
    if (system == _chart.houseSystem) return;
    HapticFeedback.selectionClick();
    setState(() {
      _chart = NatalCalculatorService.recalculateWithHouseSystem(_chart, system);
    });
    widget.onHouseSystemChanged?.call(system);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final sun = _position(chart, PlanetId.sun);
    final moon = _position(chart, PlanetId.moon);
    final asc = _position(chart, PlanetId.ascendant);
    return Container(
      key: const ValueKey('natal-profile-detail'),
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, chart),
                  const SizedBox(height: 16),
                  _bigThree(sun, moon, asc),
                  const SizedBox(height: 18),
                  _houseSection(chart),
                  const SizedBox(height: 18),
                  _ledger(chart),
                  const SizedBox(height: 18),
                  _aspects(chart.aspects),
                  const SizedBox(height: 20),
                  AstralGradientButton(
                    label: 'CLOSE PROFILE',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static NatalPlanetPosition _position(NatalChart chart, PlanetId planet) =>
      chart.planets.firstWhere((p) => p.planet == planet);

  Widget _header(BuildContext context, NatalChart chart) {
    final stamp = '${_two(chart.birthLocalDay)}.'
        '${_two(chart.birthLocalMonth)}.${chart.birthLocalYear} · '
        '${_two(chart.birthLocalHour)}:${_two(chart.birthLocalMinute)}';
    final timeLine = chart.timeKnown ? 'LOCAL' : 'TIME UNKNOWN (NOON)';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NATAL PROFILE',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: AppColors.lavender,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chart.profileName,
                style: AppTypography.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$stamp · $timeLine',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${chart.cityName} · ${chart.country}',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _bigThree(
    NatalPlanetPosition sun,
    NatalPlanetPosition moon,
    NatalPlanetPosition asc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('BIG THREE'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SpotlightTile(pos: sun, label: 'SUN')),
            const SizedBox(width: 8),
            Expanded(child: _SpotlightTile(pos: moon, label: 'MOON')),
            const SizedBox(width: 8),
            Expanded(child: _SpotlightTile(pos: asc, label: 'RISING')),
          ],
        ),
      ],
    );
  }

  Widget _houseSection(NatalChart chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('HOUSE SYSTEM'),
        const SizedBox(height: 8),
        AstralHouseSelector(value: chart.houseSystem, onChanged: _switchHouse),
        const SizedBox(height: 6),
        Text(
          chart.houseSystem.ruSubtitle,
          style: AppTypography.body(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _ledger(NatalChart chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('FULL PLACEMENTS'),
        const SizedBox(height: 8),
        for (final p in chart.planets) _LedgerRow(position: p),
      ],
    );
  }

  Widget _aspects(List<NatalAspect> all) {
    final filtered = _filteredAspects(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('ASPECT MATRIX'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final f in _AspectFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterPill(
                  label: f.name.toUpperCase(),
                  selected: _filter == f,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = f);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Text(
            'No aspects in this register.',
            style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
          )
        else
          for (final aspect in filtered.take(14)) _AspectRow(aspect: aspect),
      ],
    );
  }

  List<NatalAspect> _filteredAspects(List<NatalAspect> all) =>
      switch (_filter) {
        _AspectFilter.all => all,
        _AspectFilter.harmony => [
            for (final a in all)
              if (a.type.harmony == AspectHarmony.harmonious) a,
          ],
        _AspectFilter.tension => [
            for (final a in all)
              if (a.type.harmony != AspectHarmony.harmonious) a,
          ],
      };

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 1.0,
          color: AppColors.textMuted,
        ),
      );

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// One of the Big Three: glyph, label, sign and degree + house.
class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({required this.pos, required this.label});

  final NatalPlanetPosition pos;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            pos.planet.glyph,
            style: const TextStyle(fontSize: 22, color: AppColors.lavender),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pos.sign.glyph} ${pos.sign.title}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${pos.formattedDegree} · H${pos.house}',
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One full placement: planet, sign + degree, house chip and retrograde R.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.position});

  final NatalPlanetPosition position;

  @override
  Widget build(BuildContext context) {
    final p = position;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              p.planet.glyph,
              style: const TextStyle(fontSize: 15, color: AppColors.lavender),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              p.planet.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${p.sign.glyph} ${p.sign.title} ${p.formattedDegree}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.3,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HouseChip(house: p.house),
          SizedBox(
            width: 12,
            child: p.isRetrograde
                ? Text(
                    'R',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.conflictAmber,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _HouseChip extends StatelessWidget {
  const _HouseChip({required this.house});

  final int house;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'H$house',
        style: AppTypography.label(
          fontSize: 8.5,
          letterSpacing: 0.4,
          color: AppColors.lavender,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.7,
            color: selected ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// One aspect: bodyA glyph + aspect glyph + bodyB glyph, a strength bar and
/// the orb in degrees, tinted by the aspect register.
class _AspectRow extends StatelessWidget {
  const _AspectRow({required this.aspect});

  final NatalAspect aspect;

  @override
  Widget build(BuildContext context) {
    final color = switch (aspect.type.harmony) {
      AspectHarmony.harmonious => AppColors.harmonyCyan,
      AspectHarmony.tense => AppColors.conflictRose,
      AspectHarmony.intense => AppColors.lavender,
    };
    return Padding(
      key: ValueKey(
        'aspect-${aspect.bodyA.name}-${aspect.type.name}-${aspect.bodyB.name}',
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '${aspect.bodyA.glyph} ${aspect.type.glyph} '
              '${aspect.bodyB.glyph}',
              style: AppTypography.label(
                fontSize: 11,
                letterSpacing: 1,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: aspect.strength,
                minHeight: 5,
                backgroundColor: AppColors.canvas,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              '${aspect.orb.toStringAsFixed(1)}°',
              textAlign: TextAlign.right,
              style: AppTypography.label(
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
