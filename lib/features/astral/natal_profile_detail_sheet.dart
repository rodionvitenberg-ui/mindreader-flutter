import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/natal_chart.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/birth_time_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import 'widgets/astral_gradient_button.dart';
import 'widgets/astral_house_selector.dart';
import 'widgets/birth_data_form_sheet.dart';
import 'astral_copy.dart';

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
    return showTaroGlassSheet<void>(
      context: context,
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
      _chart = NatalCalculatorService.recalculateWithHouseSystem(
        _chart,
        system,
      );
    });
    widget.onHouseSystemChanged?.call(system);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    final sun = _position(chart, PlanetId.sun);
    final moon = _position(chart, PlanetId.moon);
    final asc = chart.planets
        .where((p) => p.planet == PlanetId.ascendant)
        .firstOrNull;
    return SizedBox(
      key: const ValueKey('natal-profile-detail'),
      height: MediaQuery.of(context).size.height * 0.92,
      child: TaroGlassSheet(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, chart),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const ValueKey('astral-edit-birth-data'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(context.astralText('edit')),
              onPressed: () async {
                final updated = await BirthDataFormSheet.show(
                  context,
                  chart: _chart,
                );
                if (mounted && updated != null) {
                  setState(() => _chart = updated);
                }
              },
            ),
            if (chart.timezoneId == null)
              Text(context.astralText('legacyTime')),
            if (!chart.timeKnown) Text(context.astralText('unknownTime')),
            if (chart.moonSignUncertain)
              Text(context.astralText('unknownMoon')),
            const SizedBox(height: 10),
            _bigThree(sun, moon, asc),
            if (chart.timeKnown) ...[
              const SizedBox(height: 18),
              _houseSection(chart),
            ],
            const SizedBox(height: 18),
            _ledger(chart),
            const SizedBox(height: 18),
            _aspects(chart.aspects),
            const SizedBox(height: 20),
            AstralGradientButton(
              label: context.astralText('close'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  static NatalPlanetPosition _position(NatalChart chart, PlanetId planet) =>
      chart.planets.firstWhere((p) => p.planet == planet);

  Widget _header(BuildContext context, NatalChart chart) {
    final stamp =
        '${_two(chart.birthLocalDay)}.'
        '${_two(chart.birthLocalMonth)}.${chart.birthLocalYear}'
        '${chart.timeKnown ? ' · ${_two(chart.birthLocalHour)}:${_two(chart.birthLocalMinute)}' : ''}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.astralRussian ? 'НАТАЛЬНАЯ КАРТА' : 'NATAL PROFILE',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chart.profileName,
                style: AppTypography.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: TaroColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$stamp${chart.timeKnown ? ' · ${BirthTimeService.offsetLabel(Duration(seconds: (chart.timezoneOffsetHours * 3600).round()))}' : ''}',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: TaroColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${chart.cityName} · ${chart.country}',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.7,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: TaroColors.textSecondary),
        ),
      ],
    );
  }

  Widget _bigThree(
    NatalPlanetPosition sun,
    NatalPlanetPosition moon,
    NatalPlanetPosition? asc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          context.astralRussian ? 'ОСНОВНЫЕ ПОЛОЖЕНИЯ' : 'BIG THREE',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SpotlightTile(pos: sun, label: 'SUN'),
            ),
            const SizedBox(width: 8),
            if (!_chart.moonSignUncertain)
              Expanded(
                child: _SpotlightTile(
                  pos: moon,
                  label: 'MOON',
                  showDegree: _chart.timeKnown,
                ),
              ),
            if (asc != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _SpotlightTile(pos: asc, label: 'RISING'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _houseSection(NatalChart chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context.astralText('house')),
        const SizedBox(height: 8),
        AstralHouseSelector(value: chart.houseSystem, onChanged: _switchHouse),
        if (context.astralRussian) ...[
          const SizedBox(height: 6),
          Text(
            chart.houseSystem.ruSubtitle,
            style: AppTypography.body(fontSize: 11, color: TaroColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _ledger(NatalChart chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context.astralText('placement')),
        const SizedBox(height: 8),
        for (final p in chart.planets)
          if (!chart.moonSignUncertain || p.planet != PlanetId.moon)
            _LedgerRow(
              position: p,
              showDegree: chart.timeKnown || p.planet != PlanetId.moon,
            ),
      ],
    );
  }

  Widget _aspects(List<NatalAspect> all) {
    final filtered = _filteredAspects(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context.astralText('matrix')),
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
            context.astralRussian
                ? 'В этой группе нет аспектов.'
                : 'No aspects in this register.',
            style: AppTypography.body(fontSize: 12, color: TaroColors.textSecondary),
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
      color: TaroColors.textSecondary,
    ),
  );

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// One of the Big Three: glyph, label, sign and degree + house.
class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({
    required this.pos,
    required this.label,
    this.showDegree = true,
  });
  final bool showDegree;

  final NatalPlanetPosition pos;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: TaroColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TaroColors.border),
      ),
      child: Column(
        children: [
          Text(
            pos.planet.glyph,
            style: const TextStyle(fontSize: 22, color: TaroColors.lavender),
          ),
          const SizedBox(height: 4),
          Text(
            context.astralRussian
                ? context.astroPlanet(pos.planet).toUpperCase()
                : label,
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 0.8,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pos.sign.glyph} ${context.astroSign(pos.sign)}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${showDegree ? pos.formattedDegree : ''}'
            '${pos.house == null ? '' : ' · H${pos.house}'}',
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 0.6,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One full placement: planet, sign + degree, house chip and retrograde R.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.position, required this.showDegree});
  final bool showDegree;

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
              style: const TextStyle(fontSize: 15, color: TaroColors.lavender),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              context.astroPlanet(p.planet),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${p.sign.glyph} ${context.astroSign(p.sign)} ${showDegree ? p.formattedDegree : ''}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.3,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (p.house case final house?) _HouseChip(house: house),
          SizedBox(
            width: 12,
            child: p.isRetrograde
                ? Text(
                    'R',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.amber,
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
        color: TaroColors.lavender.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'H$house',
        style: AppTypography.label(
          fontSize: 8.5,
          letterSpacing: 0.4,
          color: TaroColors.lavender,
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
              ? TaroColors.lavender.withValues(alpha: 0.16)
              : TaroColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? TaroColors.lavender : TaroColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 0.7,
            color: selected ? TaroColors.lavender : TaroColors.textSecondary,
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
      AspectHarmony.harmonious => TaroColors.cyan,
      AspectHarmony.tense => TaroColors.conflictRose,
      AspectHarmony.intense => TaroColors.lavender,
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
                color: TaroColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: aspect.strength,
                minHeight: 5,
                backgroundColor: TaroColors.background,
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
                color: TaroColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
