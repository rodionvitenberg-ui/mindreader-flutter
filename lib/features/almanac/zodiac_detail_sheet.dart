import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/data/zodiac_almanac_data.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/natal_calculator_service.dart';
import '../../core/theme/element_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../core/l10n/app_strings.dart';

/// Full-screen Almanac zodiac inspector page.
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
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ZodiacDetailSheet(
          entry: entry,
          onOpenHoroscope: onOpenHoroscope,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Stack(
      key: const ValueKey('zodiac-detail-sheet'),
      children: [
        const Positioned.fill(child: TaroDuskBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const BackButton(color: TaroColors.lavender),
                      const SizedBox(width: 4),
                      Text(
                        e.glyph,
                        style: TextStyle(fontSize: 34, color: e.element.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.display(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                color: TaroColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              e.dateRange,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label(
                                fontSize: 9,
                                letterSpacing: 0.9,
                                color: TaroColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          e.keywords.join(' · ').toUpperCase(),
                          style: AppTypography.label(
                            fontSize: 9.5,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w700,
                            color: TaroColors.lavender,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatTile(
                              label: AppStrings.g('common.element'),
                              value: e.element.label,
                              icon: ElementIcon(e.element, size: 14),
                            ),
                            _StatTile(
                              label: AppStrings.g('common.modality'),
                              value: e.modality.label.toUpperCase(),
                            ),
                            _StatTile(
                              label: AppStrings.g('common.polarity'),
                              value: e.polarity.label,
                            ),
                            _StatTile(
                              label: AppStrings.g('common.rulers'),
                              value: e.rulersLabel,
                            ),
                            _StatTile(
                              label: AppStrings.g(
                                'ui.zodiac_detail_sheet.natural_house',
                              ),
                              value: e.houseLabel,
                            ),
                            _StatTile(
                              label: AppStrings.g(
                                'ui.zodiac_detail_sheet.house_theme',
                              ),
                              value: NatalCalculatorService.houseTheme(
                                e.houseAffinity,
                              ),
                              wide: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TaroGlassLayer(
                          useBackdropGroup: false,
                          child: TaroGlassPanel(
                            radius: 18,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Section(
                                  title: AppStrings.g(
                                    'ui.zodiac_detail_sheet.core_archetype',
                                  ),
                                  body: e.archetype,
                                ),
                                _Section(
                                  title: AppStrings.g(
                                    'ui.zodiac_detail_sheet.shadow_stress_response',
                                  ),
                                  body: e.shadow,
                                ),
                                _Section(
                                  title: AppStrings.g(
                                    'ui.zodiac_detail_sheet.love_connection',
                                  ),
                                  body: e.loveStyle,
                                ),
                                _Section(
                                  title: AppStrings.g(
                                    'ui.zodiac_detail_sheet.career_path_vector',
                                  ),
                                  body: e.careerVector,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TaroGlassLayer(
                          useBackdropGroup: false,
                          child: SizedBox(
                            width: double.infinity,
                            child: TaroGlassButton(
                              key: const ValueKey('zodiac-open-horoscope'),
                              label: AppStrings.g(
                                'ui.zodiac_detail_sheet.view_horoscope_in_astral',
                              ),
                              variant: TaroGlassButtonVariant.primary,
                              onPressed: onOpenHoroscope == null
                                  ? null
                                  : () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.of(context).maybePop();
                                      onOpenHoroscope!(e.sign);
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final Widget? icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label(
              fontSize: 7.5,
              letterSpacing: 0.8,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.body(
                    fontSize: 11.5,
                    color: TaroColors.textPrimary,
                  ),
                ),
              ),
            ],
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
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: AppTypography.body(
              fontSize: 13,
              height: 1.5,
              color: TaroColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
