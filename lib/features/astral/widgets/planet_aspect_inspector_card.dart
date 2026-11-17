import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';
import 'natal_wheel_painter.dart';

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.lavender.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppColors.lavender.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  body.glyph,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.lavender,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${body.title.toUpperCase()} · HOUSE ${position.house}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 1.4,
                        color: AppColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${position.sign.glyph} '
                      '${position.sign.title.toUpperCase()} · '
                      '${position.formattedDegree}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
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
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            position.interpretation,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (aspects.isEmpty)
            Text(
              'NO MAJOR ASPECTS — AN UNASPECTED DEGREE ACTS ALONE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.3,
                color: AppColors.textMuted,
              ),
            )
          else ...[
            Text(
              'ACTIVE ASPECTS · ${aspects.length}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.6,
                color: AppColors.textMuted,
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
              'ORB ${aspect.orb.toStringAsFixed(1)}°',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            '${(aspect.strength * 100).round()}%',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
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
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Rx',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 7,
          letterSpacing: 1,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
