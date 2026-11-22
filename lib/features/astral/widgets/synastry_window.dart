import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/models/oracle_handoff.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/element_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'astral_gradient_button.dart';
import '../astral_copy.dart';
import '../../../core/l10n/app_strings.dart';

/// Keeps the selected pair by chart ID so reordering and editing are safe.
class SynastryPairPicker extends StatefulWidget {
  const SynastryPairPicker({
    required this.profiles,
    required this.active,
    required this.onAdd,
    required this.onDiscuss,
    super.key,
  });

  final List<NatalChart> profiles;
  final NatalChart? active;
  final Future<NatalChart?> Function() onAdd;
  final ValueChanged<OracleHandoff>? onDiscuss;

  @override
  State<SynastryPairPicker> createState() => _SynastryPairPickerState();
}

class _SynastryPairPickerState extends State<SynastryPairPicker>
    with AutomaticKeepAliveClientMixin {
  String? _firstId;
  String? _secondId;

  @override
  bool get wantKeepAlive => true;

  NatalChart? _chart(String? id) =>
      widget.profiles.where((p) => p.id == id).firstOrNull;

  Future<void> _add(NatalChart? first) async {
    final created = await widget.onAdd();
    if (!mounted || created == null) return;
    setState(() {
      _firstId = first?.id ?? created.id;
      _secondId = first == null ? null : created.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final first = _chart(_firstId) ?? widget.active;
    final savedSecond = _chart(_secondId);
    final otherCharts = widget.profiles
        .where((p) => p.id != first?.id)
        .toList();
    final second = savedSecond != null && savedSecond.id != first?.id
        ? savedSecond
        : otherCharts.length == 1
        ? otherCharts.single
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('synastry-first-${first?.id}'),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.astralText('chooseFirst'),
          ),
          initialValue: first?.id,
          items: [
            for (final p in widget.profiles)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.profileName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() {
            if (id == second?.id) _secondId = first?.id;
            _firstId = id;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('synastry-second-${second?.id}'),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.astralText('chooseSecond'),
          ),
          initialValue: second?.id,
          items: [
            for (final p in otherCharts)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.profileName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() {
            _firstId = first?.id;
            _secondId = id;
          }),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _add(first),
            icon: const Icon(Icons.person_add_outlined),
            label: Text(context.astralText('addPerson')),
          ),
        ),
        SynastryWindow(a: first, b: second, onDiscuss: widget.onDiscuss),
      ],
    );
  }
}

/// ASTRAL window 2 — the 2-profile synastry workspace: an overall resonance
/// score, four compatibility axes, the combined elemental balance, the
/// tightest cross-chart aspects and a one-tap Oracle handoff.
class SynastryWindow extends StatelessWidget {
  const SynastryWindow({
    required this.a,
    required this.b,
    required this.onDiscuss,
    super.key,
  });

  final NatalChart? a;
  final NatalChart? b;
  final ValueChanged<OracleHandoff>? onDiscuss;

  void _send(BuildContext context) {
    final chartA = a;
    final chartB = b;
    final handoff = onDiscuss;
    if (chartA == null || chartB == null || handoff == null) return;
    HapticFeedback.mediumImpact();
    handoff(
      OracleHandoff(
        prompt: OracleSynthesisService.buildSynastryPrompt(chartA, chartB),
        kind: OracleHandoffKind.synastry,
        chart: chartA,
        otherChart: chartB,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartA = a;
    final chartB = b;
    if (chartA == null || chartB == null) {
      return Container(
        key: const ValueKey('synastry-window'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TaroColors.border),
        ),
        child: Text(
          context.astralText('selectPair'),
          style: AppTypography.body(
            fontSize: 12,
            height: 1.4,
            color: TaroColors.textSecondary,
          ),
        ),
      );
    }

    final report = NatalCalculatorService.computeSynastry(chartA, chartB);
    final cross = NatalCalculatorService.computeSynastryAspects(chartA, chartB);
    final balance = NatalCalculatorService.synastryElementBalance(
      chartA,
      chartB,
    );
    final total = balance.values.fold<int>(0, (sum, v) => sum + v);

    return Column(
      key: const ValueKey('synastry-window'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${chartA.profileName} × ${chartB.profileName}',
          style: AppTypography.display(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: TaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _label(context.astralText('relationshipThemes')),
        const SizedBox(height: 8),
        for (final aspect in _featuredAspects(cross))
          _CrossAspectRow(
            withExplanation: true,
            aspect: aspect,
            a: chartA.profileName,
            b: chartB.profileName,
          ),
        if (cross.isEmpty)
          Text(
            AppStrings.g('ui.astral_synastry_window.no_close_cross_chart_aspects'),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.astralText('synastryDetails')),
          children: [
            _ResonanceCard(score: report.overallScore),
            const SizedBox(height: 12),
            _label(
              AppStrings.g('ui.astral_synastry_window.compatibility_axes'),
            ),
            const SizedBox(height: 8),
            for (final axis in report.axes) _AxisBar(axis: axis),
            const SizedBox(height: 12),
            _label(
              AppStrings.g('ui.astral_synastry_window.elemental_balance'),
            ),
            for (final e in Element.values)
              _ElementBar(element: e, count: balance[e] ?? 0, total: total),
            const SizedBox(height: 12),
            _label(context.astralText('allAspects')),
            for (final aspect in cross)
              _CrossAspectRow(
                aspect: aspect,
                a: chartA.profileName,
                b: chartB.profileName,
              ),
          ],
        ),
        const SizedBox(height: 16),
        AstralGradientButton(
          label: context.astralRussian
              ? context.astralText('discuss')
              : AppStrings.g('astral.discussSynastry'),
          onTap: () => _send(context),
        ),
      ],
    );
  }

  // Prefer a distinct chart interaction for each relationship theme.
  List<NatalAspect> _featuredAspects(List<NatalAspect> aspects) {
    final selected = <NatalAspect>[];
    for (final bodies in [
      {PlanetId.moon},
      {PlanetId.mercury},
      {PlanetId.venus, PlanetId.mars},
    ]) {
      final match = aspects
          .where(
            (a) =>
                !selected.contains(a) &&
                (bodies.contains(a.bodyA) || bodies.contains(a.bodyB)),
          )
          .firstOrNull;
      if (match != null) selected.add(match);
    }
    return [
      ...selected,
      ...aspects.where((a) => !selected.contains(a)),
    ].take(3).toList();
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.label(
      fontSize: 9,
      letterSpacing: 1.0,
      color: TaroColors.textSecondary,
    ),
  );
}

/// The big 0..100 resonance read at the top of the synastry window.
class _ResonanceCard extends StatelessWidget {
  const _ResonanceCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? TaroColors.cyan
        : score >= 40
        ? TaroColors.lavender
        : TaroColors.conflictRose;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaroColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppStrings.g('ui.astral_synastry_window.overall_resonance'),
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: TaroColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$score%',
                style: AppTypography.label(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: TaroColors.background,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score / 100,
                child: Container(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four compatibility axes: title, score bar and a grounded line.
class _AxisBar extends StatelessWidget {
  const _AxisBar({required this.axis});

  final SynastryAxis axis;

  @override
  Widget build(BuildContext context) {
    final color = axis.score >= 66
        ? TaroColors.cyan
        : axis.score >= 40
        ? TaroColors.lavender
        : TaroColors.conflictRose;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  axis.title.toUpperCase(),
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${axis.score}%',
                style: AppTypography.label(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: TaroColors.background,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: axis.score / 100,
                child: Container(color: color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            axis.text,
            style: AppTypography.body(
              fontSize: 11,
              height: 1.35,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One element of the combined synastry balance: label, bar and count.
class _ElementBar extends StatelessWidget {
  const _ElementBar({
    required this.element,
    required this.count,
    required this.total,
  });

  final Element element;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              '${element.glyph} ${element.label.toUpperCase()}',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.7,
                color: element.accent,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: TaroColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(element.accent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
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

/// One cross-chart aspect: the two bodies and the aspect glyph, tinted by
/// register, with the orb on the right.
class _CrossAspectRow extends StatelessWidget {
  const _CrossAspectRow({
    required this.aspect,
    required this.a,
    required this.b,
    this.withExplanation = false,
  });

  final bool withExplanation;
  final String a;
  final String b;

  final NatalAspect aspect;

  @override
  Widget build(BuildContext context) {
    final color = switch (aspect.type.harmony) {
      AspectHarmony.harmonious => TaroColors.cyan,
      AspectHarmony.tense => TaroColors.conflictRose,
      AspectHarmony.intense => TaroColors.lavender,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$a · ${context.astroPlanet(aspect.bodyA)} ${aspect.type.glyph} '
                  '$b · ${context.astroPlanet(aspect.bodyB)}',
                  style: AppTypography.body(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${aspect.orb.toStringAsFixed(1)}°',
                style: AppTypography.label(fontSize: 12, color: color),
              ),
            ],
          ),
          if (withExplanation)
            Text(
              context.astroAspectAdvice(aspect.type),
              style: AppTypography.body(
                color: TaroColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
