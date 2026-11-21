import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/models/natal_chart.dart';
import '../../core/models/oracle_handoff.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/element_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import 'widgets/astral_gradient_button.dart';

/// ASTRAL Phase 4 — 2-profile synastry: Moon compatibility, the combined
/// elemental balance and the tightest cross-chart aspects, closed with a
/// one-tap handoff into the Oracle AI Chat.
class SynastrySummarySheet extends StatelessWidget {
  const SynastrySummarySheet({
    required this.a,
    required this.b,
    required this.onSendToOracle,
    super.key,
  });

  final NatalChart a;
  final NatalChart b;
  final ValueChanged<OracleHandoff>? onSendToOracle;

  static Future<void> show(
    BuildContext context, {
    required NatalChart a,
    required NatalChart b,
    ValueChanged<OracleHandoff>? onSendToOracle,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => SynastrySummarySheet(
        a: a,
        b: b,
        onSendToOracle: onSendToOracle,
      ),
    );
  }

  static NatalPlanetPosition _position(NatalChart chart, PlanetId planet) =>
      chart.planets.firstWhere((p) => p.planet == planet);

  void _send(BuildContext context) {
    final handoff = OracleHandoff(
      prompt: OracleSynthesisService.buildSynastryPrompt(a, b),
      kind: OracleHandoffKind.synastry,
      chart: a,
      otherChart: b,
    );
    HapticFeedback.mediumImpact();
    Navigator.of(context).maybePop();
    onSendToOracle?.call(handoff);
  }

  @override
  Widget build(BuildContext context) {
    final cross = NatalCalculatorService.computeSynastryAspects(a, b);
    final balance = NatalCalculatorService.synastryElementBalance(a, b);
    final total = balance.values.fold<int>(0, (sum, v) => sum + v);
    final moonA = _position(a, PlanetId.moon);
    final moonB = _position(b, PlanetId.moon);
    return SizedBox(
      key: const ValueKey('synastry-summary'),
      height: MediaQuery.of(context).size.height * 0.88,
      child: TaroGlassSheet(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 12),
            _moonCard(moonA, moonB),
            const SizedBox(height: 18),
            _label('ELEMENTAL BALANCE'),
            const SizedBox(height: 8),
            for (final e in Element.values)
              _ElementBar(
                element: e,
                count: balance[e] ?? 0,
                total: total,
              ),
            const SizedBox(height: 14),
            _label('CROSS-CHART ASPECTS'),
            const SizedBox(height: 8),
            if (cross.isEmpty)
              Text(
                'No tight cross-chart aspects — this bond rests on '
                'temperament, not friction.',
                style: AppTypography.body(
                  fontSize: 12,
                  height: 1.4,
                  color: TaroColors.textSecondary,
                ),
              )
            else
              for (final aspect in cross.take(6))
                _CrossAspectRow(aspect: aspect),
            const SizedBox(height: 18),
            AstralGradientButton(
              label: '✦ DISCUSS THIS SYNASTRY WITH THE ORACLE',
              onTap: () => _send(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYNASTRY · 2 PROFILES',
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${a.profileName} × ${b.profileName}',
                style: AppTypography.display(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: TaroColors.textPrimary,
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

  Widget _moonCard(NatalPlanetPosition moonA, NatalPlanetPosition moonB) {
    final same = moonA.sign.element == moonB.sign.element;
    final line = same
        ? 'Both Moons share the ${moonA.sign.element.label} element — '
            'emotional rhythms match easily.'
        : 'Moons in ${moonA.sign.title} and ${moonB.sign.title} need '
            'different things — the bond asks for translation.';
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
          _moonLine(a.profileName, moonA),
          const SizedBox(height: 4),
          _moonLine(b.profileName, moonB),
          const SizedBox(height: 10),
          Text(
            line,
            style: AppTypography.body(
              fontSize: 12,
              height: 1.45,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moonLine(String name, NatalPlanetPosition moon) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'MOON · ${name.toUpperCase()}',
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.7,
              color: TaroColors.textSecondary,
            ),
          ),
        ),
        Text(
          '${moon.sign.glyph} ${moon.sign.title}',
          style: AppTypography.body(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TaroColors.textPrimary,
          ),
        ),
      ],
    );
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
  const _CrossAspectRow({required this.aspect});

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
        'synastry-${aspect.bodyA.name}-${aspect.type.name}-${aspect.bodyB.name}',
      ),
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
                color: TaroColors.textPrimary,
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
                color: TaroColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${aspect.orb.toStringAsFixed(1)}°',
            style: AppTypography.label(
              fontSize: 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
