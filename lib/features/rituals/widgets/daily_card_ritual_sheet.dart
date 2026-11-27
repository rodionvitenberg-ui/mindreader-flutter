import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/daily_ritual_controller.dart';
import '../../../state/session_history_controller.dart';
import '../../digital_table/widgets/tarot_card_3d_widget.dart';
import '../../share/share_card_payload.dart';
import '../../share/share_card_preview_sheet.dart';

/// Compact Moonly-style hero card for the 30-second Daily Card ritual +
/// live reading streak and 7-day rhythm dots.
class DailyCardHeroCard extends StatelessWidget {
  const DailyCardHeroCard({
    super.key,
    required this.language,
    this.onDiscussDailyCard,
  });

  final AppLanguage language;
  final ValueChanged<DailyCardEntry>? onDiscussDailyCard;

  Future<void> _onTapCard(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final ritual = context.read<DailyRitualController>();
    final history = context.read<SessionHistoryController>();
    final fresh = !ritual.drawnToday;
    final entry = ritual.todayCard ?? await ritual.drawTodayCard(history: history);
    if (!context.mounted) return;
    await DailyCardRitualSheet.show(
      context,
      entry: entry,
      animateFlip: fresh,
      onDiscuss: onDiscussDailyCard == null
          ? null
          : () => onDiscussDailyCard!(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ritual = context.watch<DailyRitualController?>();
    if (ritual == null) return const SizedBox.shrink();
    final entry = ritual.todayCard;
    final streak = ritual.streak;
    final days = ritual.last7Days;

    return TaroGlassPanel(
      key: const ValueKey('daily-card-hero-card'),
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            key: const ValueKey('daily-card-hero-art'),
            onTap: () => _onTapCard(context),
            child: TarotCard3DWidget(
              card: entry?.card ?? DailyCardEntry(
                dayKey: '',
                cardId: 17,
                isReversed: false,
                drawnAt: '',
                sessionTimestamp: '',
              ).card,
              isReversed: entry?.isReversed ?? false,
              state: entry != null ? SlotState.faceUp : SlotState.faceDown,
              width: 58,
              height: 94,
              tilt: false,
              interactive: false,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.t(language, 'ritual.dailyCard.title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.lavender,
                        ),
                      ),
                    ),
                    Container(
                      key: const ValueKey('daily-card-streak-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TaroColors.dawn.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TaroColors.dawn.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Text(
                        '🔥 ${AppStrings.t(language, 'ritual.dailyCard.streakDays', {'days': streak})}',
                        style: AppTypography.label(
                          fontSize: 8.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.dawn,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry != null
                      ? (entry.isReversed
                            ? '${entry.card.name} ↺'
                            : entry.card.name)
                      : AppStrings.t(language, 'ritual.dailyCard.subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: TaroColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                // 7-day rhythm strip
                Row(
                  children: [
                    for (final d in days)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d.completed
                                ? TaroColors.lavender
                                : TaroColors.surface.withValues(alpha: 0.7),
                            border: Border.all(
                              color: d.completed
                                  ? TaroColors.lavender
                                  : TaroColors.mist.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TaroGlassChip(
                        key: const ValueKey('daily-card-cta'),
                        label: entry != null
                            ? AppStrings.t(language, 'ritual.dailyCard.openCta')
                            : AppStrings.t(
                                language,
                                'ritual.dailyCard.drawCta',
                              ),
                        selected: true,
                        compact: true,
                        expanded: true,
                        onTap: () => _onTapCard(context),
                      ),
                    ),
                    if (entry != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        key: const ValueKey('daily-card-hero-share'),
                        tooltip: AppStrings.t(language, 'share.button'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          size: 17,
                          color: TaroColors.lavender,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ShareCardPreviewSheet.show(
                            context,
                            payload: ShareCardPayload.fromDailyCard(
                              card: entry.card,
                              isReversed: entry.isReversed,
                              lang: language,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 30-second tactile Card of the Day reveal modal with Share & Oracle actions.
class DailyCardRitualSheet extends StatefulWidget {
  const DailyCardRitualSheet({
    super.key,
    required this.entry,
    this.animateFlip = false,
    this.onDiscuss,
  });

  final DailyCardEntry entry;
  final bool animateFlip;
  final VoidCallback? onDiscuss;

  static Future<void> show(
    BuildContext context, {
    required DailyCardEntry entry,
    bool animateFlip = false,
    VoidCallback? onDiscuss,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => DailyCardRitualSheet(
        entry: entry,
        animateFlip: animateFlip,
        onDiscuss: onDiscuss,
      ),
    );
  }

  @override
  State<DailyCardRitualSheet> createState() => _DailyCardRitualSheetState();
}

class _DailyCardRitualSheetState extends State<DailyCardRitualSheet> {
  late bool _revealed = !widget.animateFlip;

  @override
  void initState() {
    super.initState();
    if (widget.animateFlip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final card = widget.entry.card;
    final meaning = widget.entry.isReversed ? card.reversed : card.upright;
    final streak = context.watch<DailyRitualController?>()?.streak ?? 1;

    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'ritual.dailyCard.title'),
                    style: AppTypography.label(
                      fontSize: 10.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.lavender,
                    ),
                  ),
                ),
                Text(
                  '🔥 ${AppStrings.t(lang, 'ritual.dailyCard.streakDays', {'days': streak})}',
                  style: AppTypography.label(
                    fontSize: 9.5,
                    letterSpacing: 0.7,
                    color: TaroColors.dawn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TarotCard3DWidget(
              card: card,
              isReversed: widget.entry.isReversed,
              state: _revealed ? SlotState.faceUp : SlotState.faceDown,
              width: 148,
              height: 242,
              tilt: false,
              interactive: false,
            ),
            const SizedBox(height: 14),
            Text(
              card.name,
              textAlign: TextAlign.center,
              style: AppTypography.display(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: TaroColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElementIcon(card.element, size: 13),
                const SizedBox(width: 6),
                Text(
                  widget.entry.isReversed
                      ? '${AppStrings.t(lang, 'almanac.${card.element.name}').toUpperCase()}  ·  ${AppStrings.t(lang, 'common.reversed').toUpperCase()}'
                      : AppStrings.t(lang, 'almanac.${card.element.name}')
                            .toUpperCase(),
                  style: AppTypography.label(
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                    color: TaroColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              meaning,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                fontSize: 13.5,
                height: 1.5,
                color: TaroColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: TaroColors.lavender.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: TaroColors.lavender.withValues(alpha: 0.75),
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                card.socratic,
                style: AppTypography.body(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                  color: TaroColors.textPrimary.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TaroGlassLayer(
                    useBackdropGroup: false,
                    child: TaroGlassButton(
                      key: const ValueKey('daily-card-share-button'),
                      label: AppStrings.t(lang, 'share.button').toUpperCase(),
                      icon: Icons.ios_share_rounded,
                      variant: TaroGlassButtonVariant.primary,
                      onPressed: () {
                        ShareCardPreviewSheet.show(
                          context,
                          payload: ShareCardPayload.fromDailyCard(
                            card: card,
                            isReversed: widget.entry.isReversed,
                            lang: lang,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.onDiscuss != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TaroGlassLayer(
                      useBackdropGroup: false,
                      child: TaroGlassButton(
                        key: const ValueKey('daily-card-oracle-button'),
                        label: AppStrings.t(
                          lang,
                          'ritual.dailyCard.discussCta',
                        ),
                        variant: TaroGlassButtonVariant.secondary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDiscuss!();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
