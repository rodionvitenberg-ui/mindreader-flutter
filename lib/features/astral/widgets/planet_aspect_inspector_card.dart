import 'package:flutter/material.dart';

import '../astral_copy.dart';
import '../../../core/models/natal_chart.dart';
import '../../../design_system/taro_tokens.dart';
import '../../../core/theme/app_typography.dart';
import 'natal_wheel_painter.dart';
import '../../../core/l10n/app_strings.dart';

/// Tap-to-inspect panel: the selected body's sign/house reading plus every
/// chord touching it, harmony-colored and tightest orb first.
class PlanetAspectInspectorCard extends StatelessWidget {
  const PlanetAspectInspectorCard({
    required this.position,
    required this.aspects,
    this.onClose,
    super.key,
  });

  final NatalPlanetPosition position;

  /// Aspects that involve [position]'s planet, chart order (tightest first).
  final List<NatalAspect> aspects;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final body = position.planet;
    return Container(
      key: const ValueKey('planet-inspector-card'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TaroColors.lavender.withValues(alpha: 0.10),
                  border: Border.all(
                    color: TaroColors.lavender.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  body.glyph,
                  style: const TextStyle(
                    fontSize: 16,
                    color: TaroColors.lavender,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.astroPlanet(body).toUpperCase()}'
                      '${position.house == null ? '' : ' · ${AppStrings.g('ui.astral_planet_aspect_inspector_card.house')} ${position.house}'}',
                      style: AppTypography.label(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: TaroColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${position.sign.glyph} '
                      '${context.astroSign(position.sign).toUpperCase()} · '
                      '${position.formattedDegree}',
                      style: AppTypography.label(
                        fontSize: 8.5,
                        letterSpacing: 0.7,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (position.isRetrograde) const _RetrogradeBadge(),
              if (onClose != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      '✕',
                      style: TextStyle(
                        fontSize: 12,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.astroPlacement(position),
            style: AppTypography.body(
              fontSize: 12,
              height: 1.45,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (aspects.isEmpty)
            Text(
              AppStrings.g('ui.astral_planet_aspect_inspector_card.no_major_aspects'),
              style: AppTypography.label(
                fontSize: 8.5,
                letterSpacing: 0.7,
                color: TaroColors.textSecondary,
              ),
            )
          else ...[
            Text(
              '${AppStrings.g('ui.astral_planet_aspect_inspector_card.active_aspects')} · ${aspects.length}',
              style: AppTypography.label(
                fontSize: 8.5,
                letterSpacing: 0.9,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (final aspect in aspects.take(4))
              _AspectRow(aspect: aspect, selected: body),
          ],
        ],
      ),
    );
  }
}

class _AspectRow extends StatelessWidget {
  const _AspectRow({required this.aspect, required this.selected});

  final NatalAspect aspect;
  final PlanetId selected;

  @override
  Widget build(BuildContext context) {
    final other = aspect.bodyA == selected ? aspect.bodyB : aspect.bodyA;
    final accent = aspectAccentColor(aspect.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            aspect.type.glyph,
            style: TextStyle(fontSize: 12, color: accent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${other.glyph} ${other.title.toUpperCase()} · '
              '${aspect.type.baseAngle.round()}° · '
              '${context.astralText('orb').toUpperCase()} ${aspect.orb.toStringAsFixed(1)}°',
              style: AppTypography.label(
                fontSize: 8.5,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${(aspect.strength * 100).round()}%',
            style: AppTypography.label(
              fontSize: 8.5,
              letterSpacing: 1.1,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetrogradeBadge extends StatelessWidget {
  const _RetrogradeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TaroColors.textSecondary.withValues(alpha: 0.4)),
      ),
      child: Text(AppStrings.g('ui.planet_aspect_inspector_card.rx'),
        style: AppTypography.label(
          fontSize: 7.5,
          letterSpacing: 1,
          color: TaroColors.textSecondary,
        ),
      ),
    );
  }
}
