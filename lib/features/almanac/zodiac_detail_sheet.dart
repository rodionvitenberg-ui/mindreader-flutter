import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/data/zodiac_almanac_data.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The Almanac's rich zodiac inspector: dates, element, modality, polarity,
/// rulers, house affinity, the core archetype, shadow, love and career, plus
/// a 1-tap jump to the sign's Horoscope in ASTRAL.
class ZodiacDetailSheet extends StatelessWidget {
  const ZodiacDetailSheet({
    super.key,
    required this.entry,
    this.onOpenHoroscope,
  });

  final ZodiacSignEntry entry;
  final ValueChanged<ZodiacSign>? onOpenHoroscope;

  static Future<void> show(
    BuildContext context,
    ZodiacSignEntry entry, {
    ValueChanged<ZodiacSign>? onOpenHoroscope,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => ZodiacDetailSheet(
        entry: entry,
        onOpenHoroscope: onOpenHoroscope,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          key: const ValueKey('zodiac-detail-sheet'),
          decoration: const BoxDecoration(
            color: Color(0xEB13131A),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: _details(context, entry, onOpenHoroscope),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _details(
  BuildContext context,
  ZodiacSignEntry e,
  ValueChanged<ZodiacSign>? onOpenHoroscope,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.glyph,
            style: TextStyle(fontSize: 44, color: e.element.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: AppTypography.display(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.dateRange,
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 0.9,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.keywords.join(' · ').toUpperCase(),
                  style: AppTypography.label(
                    fontSize: 9,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lavender,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatTile(
            label: 'ELEMENT',
            value: '${e.element.glyph} ${e.element.label}',
          ),
          _StatTile(label: 'MODALITY', value: e.modality.name.toUpperCase()),
          _StatTile(label: 'POLARITY', value: e.polarity.label),
          _StatTile(label: 'RULERS', value: e.rulersLabel),
          _StatTile(label: 'NATURAL HOUSE', value: e.houseLabel),
          _StatTile(
            label: 'HOUSE THEME',
            value: NatalCalculatorService.houseTheme(e.houseAffinity),
            wide: true,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _Section(title: 'CORE ARCHETYPE', body: e.archetype),
      _Section(title: 'SHADOW · STRESS RESPONSE', body: e.shadow),
      _Section(title: 'LOVE & CONNECTION', body: e.loveStyle),
      _Section(title: 'CAREER & PATH VECTOR', body: e.careerVector),
      const SizedBox(height: 6),
      _HoroscopeButton(
        onTap: onOpenHoroscope == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).maybePop();
                onOpenHoroscope(e.sign);
              },
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body(
              fontSize: 11.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: AppTypography.body(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoroscopeButton extends StatelessWidget {
  const _HoroscopeButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('zodiac-open-horoscope'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.55)),
        ),
        child: Text(
          '✦ VIEW HOROSCOPE IN ASTRAL',
          style: AppTypography.label(
            fontSize: 9.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

