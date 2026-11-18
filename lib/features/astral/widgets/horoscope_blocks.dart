import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/natal_chart.dart';
import '../../../core/theme/app_colors.dart';

/// The 0..100 Energy & Resonance bar shared by both Horoscope modes.
class EnergyResonanceBar extends StatelessWidget {
  const EnergyResonanceBar({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 66
        ? AppColors.harmonyCyan
        : score >= 40
            ? AppColors.lavender
            : AppColors.conflictRose;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ENERGY & RESONANCE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              '$score%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: AppColors.canvas,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score.clamp(0, 100) / 100,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

/// One focus sphere (relationships, career, inner state).
class FocusSphereCard extends StatelessWidget {
  const FocusSphereCard({required this.sphere, super.key});

  final FocusSphere sphere;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('focus-sphere-${sphere.title}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sphere.title.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sphere.text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 7-day 'Windows of Power & Tension' timeline strip: one compact cell
/// per day (Today .. +6) tinted by the day's strongest transit harmony.
class SevenDayForecastCard extends StatelessWidget {
  const SevenDayForecastCard({required this.peaks, super.key});

  final List<DailyTransitPeak> peaks;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('seven-day-forecast'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-DAY WINDOWS OF POWER & TENSION',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < peaks.length; i++)
                Expanded(
                  child: _DayCell(
                    peak: peaks[i],
                    label: i == 0 ? 'TODAY' : _days[peaks[i].date.weekday - 1],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.peak, required this.label});

  final DailyTransitPeak peak;
  final String label;

  @override
  Widget build(BuildContext context) {
    final transit = peak.transit;
    final color = transit == null
        ? AppColors.textMuted.withValues(alpha: 0.5)
        : switch (transit.harmony) {
            AspectHarmony.harmonious => AppColors.harmonyCyan,
            AspectHarmony.tense => AppColors.conflictRose,
            AspectHarmony.intense => AppColors.lavender,
          };
    final planet = transit == null
        ? 'CALM'
        : transit.title.split(' ').first.toUpperCase();
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 7,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          planet,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 6.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
