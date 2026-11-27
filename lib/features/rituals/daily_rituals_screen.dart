import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/custom_spread.dart';
import '../../core/services/spread_check_in_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/daily_ritual_controller.dart';
import '../../state/session_history_controller.dart';
import '../digital_table/spread_history_pane.dart'
    show formatSessionTime, spreadTitleForSnapshot;
import '../digital_table/widgets/ritual_settings_sheet.dart';
import '../digital_table/widgets/spread_check_in_sheet.dart';
import '../profile/widgets/profile_header.dart';
import 'widgets/daily_card_ritual_sheet.dart';
import 'widgets/lunar_ritual_card.dart';

class DailyRitualsScreen extends StatelessWidget {
  const DailyRitualsScreen({
    super.key,
    required this.isActive,
    this.onStartLunarSpread,
    this.onDiscussDailyCard,
  });

  final bool isActive;
  final ValueChanged<CustomSpreadConfig>? onStartLunarSpread;
  final ValueChanged<DailyCardEntry>? onDiscussDailyCard;

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final history = context.watch<SessionHistoryController?>();
    final dueCheckIns = history?.dueCheckIns() ?? const [];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ProfileHeader(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: ProfileHeaderTitle('rituals.title'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                DailyCardHeroCard(
                  language: lang,
                  onDiscussDailyCard: onDiscussDailyCard,
                ),
                const SizedBox(height: 12),
                LunarRitualCard(
                  language: lang,
                  onStartLunarSpread: onStartLunarSpread,
                ),
                const SizedBox(height: 12),
                if (dueCheckIns.isNotEmpty) ...[
                  _ZeigarnikCheckInSection(
                    language: lang,
                    dueSessions: dueCheckIns,
                  ),
                  const SizedBox(height: 12),
                ],
                RitualSettingsSheet(inline: true, isActive: isActive),
                if (history != null) ...[
                  const SizedBox(height: 14),
                  _CheckInCadenceCard(language: lang, history: history),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZeigarnikCheckInSection extends StatelessWidget {
  const _ZeigarnikCheckInSection({
    required this.language,
    required this.dueSessions,
  });

  final AppLanguage language;
  final List dueSessions;

  @override
  Widget build(BuildContext context) {
    return TaroGlassPanel(
      key: const ValueKey('rituals-checkin-section'),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                size: 16,
                color: TaroColors.dawn,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.t(language, 'checkin.sectionTitle'),
                  style: AppTypography.label(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.dawn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final snapshot in dueSessions.take(3)) ...[
            GestureDetector(
              key: ValueKey('rituals-checkin-item-${snapshot.timestamp}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                SpreadCheckInSheet.show(context, snapshot: snapshot);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TaroColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TaroColors.dawn.withValues(alpha: 0.36),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${spreadTitleForSnapshot(snapshot).toUpperCase()}  ·  ${formatSessionTime(snapshot.timestamp)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(
                              fontSize: 8.5,
                              letterSpacing: 0.8,
                              color: TaroColors.lavender,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            SpreadCheckInService.promptFor(snapshot, language),
                            style: AppTypography.body(
                              fontSize: 12,
                              height: 1.35,
                              color: TaroColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: TaroColors.dawn,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckInCadenceCard extends StatelessWidget {
  const _CheckInCadenceCard({required this.language, required this.history});

  final AppLanguage language;
  final SessionHistoryController history;

  @override
  Widget build(BuildContext context) {
    return TaroGlassPanel(
      key: const ValueKey('rituals-checkin-cadence'),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t(language, 'checkin.sectionTitle'),
            style: AppTypography.label(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              color: TaroColors.lavender,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.t(language, 'checkin.cadenceLabel'),
            style: const TextStyle(
              fontSize: 11.5,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < SpreadCheckInService.cadenceOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: TaroGlassChip(
                    key: ValueKey(
                      'checkin-cadence-${SpreadCheckInService.cadenceOptions[i]}',
                    ),
                    label: AppStrings.t(language, 'checkin.days', {
                      'days': SpreadCheckInService.cadenceOptions[i],
                    }),
                    selected:
                        history.defaultCheckInDays ==
                        SpreadCheckInService.cadenceOptions[i],
                    expanded: true,
                    compact: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      history.setDefaultCheckInDays(
                        SpreadCheckInService.cadenceOptions[i],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
