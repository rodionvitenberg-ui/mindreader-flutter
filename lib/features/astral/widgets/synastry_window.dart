import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/models/oracle_handoff.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'astral_gradient_button.dart';

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
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Synastry needs two saved profiles — create a second natal chart '
          'on the NATAL CHART window first.',
          style: AppTypography.body(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textMuted,
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
        _label('SYNASTRY · 2 PROFILES'),
        const SizedBox(height: 4),
        Text(
          '${chartA.profileName} × ${chartB.profileName}',
          style: AppTypography.display(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _ResonanceCard(score: report.overallScore),
        const SizedBox(height: 12),
        _label('COMPATIBILITY AXES'),
        const SizedBox(height: 8),
        for (final axis in report.axes) _AxisBar(axis: axis),
        const SizedBox(height: 14),
        _label('ELEMENTAL BALANCE'),
        const SizedBox(height: 8),
        for (final e in Element.values)
          _ElementBar(element: e, count: balance[e] ?? 0, total: total),
        const SizedBox(height: 14),
        _label('CROSS-CHART ASPECTS'),
        const SizedBox(height: 8),
        if (cross.isEmpty)
          Text(
            'No tight cross-chart aspects — this bond rests on temperament, '
            'not friction.',
            style: AppTypography.body(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          )
        else
          for (final aspect in cross.take(6)) _CrossAspectRow(aspect: aspect),
        const SizedBox(height: 16),
        AstralGradientButton(
          label: '✦ DISCUSS SYNASTRY WITH ORACLE →',
          onTap: () => _send(context),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 1.0,
          color: AppColors.textMuted,
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
        ? AppColors.harmonyCyan
        : score >= 40
            ? AppColors.lavender
            : AppColors.conflictRose;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OVERALL RESONANCE',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
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
              color: AppColors.canvas,
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
        ? AppColors.harmonyCyan
        : axis.score >= 40
            ? AppColors.lavender
            : AppColors.conflictRose;
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
                    color: AppColors.textPrimary,
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
              color: AppColors.canvas,
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
              color: AppColors.textMuted,
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
                backgroundColor: AppColors.canvas,
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
                color: AppColors.textMuted,
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
  const _CrossAspectRow({required this.aspect});

  final NatalAspect aspect;

  @override
  Widget build(BuildContext context) {
    final color = switch (aspect.type.harmony) {
      AspectHarmony.harmonious => AppColors.harmonyCyan,
      AspectHarmony.tense => AppColors.conflictRose,
      AspectHarmony.intense => AppColors.lavender,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 44,
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
            child: Text(
              aspect.synthesis,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${aspect.orb.toStringAsFixed(1)}°',
            style: AppTypography.label(fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }
}


