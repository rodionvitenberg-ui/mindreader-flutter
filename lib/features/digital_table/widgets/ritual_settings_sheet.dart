import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/lunar_phase_service.dart';
import '../../../core/services/ritual_notification_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

/// Notification settings organized into three independent sections:
/// 1. Daily Ritual reminders (toggle, weekday picker, morning/evening times, streak).
/// 2. Lunar Phases (astronomical New Moon & Full Moon reminders).
/// 3. News & Updates subscription.
///
/// Every toggle, weekday chip, and time selection persists and reschedules
/// device notifications immediately — no redundant Save/Disable button.
class RitualSettingsSheet extends StatefulWidget {
  const RitualSettingsSheet({
    super.key,
    this.inline = false,
    this.isActive = true,
  });

  /// When true the sections render directly as glass cards inside a scrollable
  /// page (no modal sheet chrome).
  final bool inline;
  final bool isActive;

  static Future<void> show(BuildContext context) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => const RitualSettingsSheet(),
    );
  }

  @override
  State<RitualSettingsSheet> createState() => _RitualSettingsSheetState();
}

class _RitualSettingsSheetState extends State<RitualSettingsSheet> {
  final _storage = LocalStorageService();
  bool _enabled = false;
  int _morning = 540; // 09:00
  int _evening = 1320; // 22:00
  Set<int> _weekdays = Set<int>.from(LocalStorageService.allWeekdays);
  bool _newMoonEnabled = false;
  bool _fullMoonEnabled = false;
  bool _newsEnabled = false;
  int _streak = 0;
  bool _loaded = false;

  late final LunarPhaseEvent? _nextNewMoon = LunarPhaseService.next(
    LunarPhase.newMoon,
  );
  late final LunarPhaseEvent? _nextFullMoon = LunarPhaseService.next(
    LunarPhase.fullMoon,
  );

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(RitualSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loaded && widget.isActive && !oldWidget.isActive) _refreshStreak();
  }

  Future<void> _refreshStreak() async {
    try {
      final days = await _storage.loadReadingDays();
      if (mounted) setState(() => _streak = computeStreak(days));
    } catch (_) {
      // Keep the last visible streak if the local store is unavailable.
    }
  }

  Future<void> _restore() async {
    try {
      final enabled = await _storage.loadRitualEnabled();
      final morning = await _storage.loadMorningMinutes();
      final evening = await _storage.loadEveningMinutes();
      final weekdays = await _storage.loadRitualWeekdays();
      final newMoon = await _storage.loadLunarNewMoonEnabled();
      final fullMoon = await _storage.loadLunarFullMoonEnabled();
      final news = await _storage.loadNewsNotificationsEnabled();
      final days = await _storage.loadReadingDays();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _morning = morning;
        _evening = evening;
        _weekdays = weekdays;
        _newMoonEnabled = newMoon;
        _fullMoonEnabled = fullMoon;
        _newsEnabled = news;
        _streak = computeStreak(days);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime utc) {
    final local = utc.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d.$m.${local.year}';
  }

  void _notify(
    String message, {
    TaroGlassSnackbarTone tone = TaroGlassSnackbarTone.info,
  }) {
    if (!mounted) return;
    showTaroGlassSnackbar(context, message: message, tone: tone);
  }

  Future<void> _setDailyEnabled(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _enabled = value);
    try {
      await Future.wait([
        _storage.saveRitualEnabled(value),
        _storage.saveMorningMinutes(_morning),
        _storage.saveEveningMinutes(_evening),
        _storage.saveRitualWeekdays(_weekdays),
      ]);
    } catch (_) {
      // Keep in-session state if local storage is unavailable.
    }
    if (value) {
      final result = await RitualNotificationService.scheduleDailyRituals(
        morningMinutes: _morning,
        eveningMinutes: _evening,
        weekdays: _weekdays,
      );
      if (!result.permissionGranted) {
        _notify(
          AppStrings.g('ritual.permissionDenied'),
          tone: TaroGlassSnackbarTone.warning,
        );
      } else {
        _notify(
          AppStrings.g(
            'ui.ritual_settings_sheet.daily_ritual_reminders_set_all_local_no_server',
          ),
          tone: TaroGlassSnackbarTone.success,
        );
      }
    } else {
      await RitualNotificationService.cancelRituals();
      _notify(
        AppStrings.g('ui.ritual_settings_sheet.ritual_reminders_disabled'),
      );
    }
  }

  Future<void> _toggleWeekday(int weekday) async {
    if (_weekdays.contains(weekday) && _weekdays.length <= 1) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    final next = Set<int>.from(_weekdays);
    if (!next.remove(weekday)) {
      next.add(weekday);
    }
    setState(() => _weekdays = next);
    try {
      await _storage.saveRitualWeekdays(next);
    } catch (_) {
      // Keep in-session selection if storage is unavailable.
    }
    if (_enabled) {
      await RitualNotificationService.scheduleDailyRituals(
        morningMinutes: _morning,
        eveningMinutes: _evening,
        weekdays: next,
        requestPermission: false,
      );
    }
  }

  Future<void> _pickTime({required bool morning}) async {
    final current = TimeOfDay(
      hour: (morning ? _morning : _evening) ~/ 60,
      minute: (morning ? _morning : _evening) % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (!mounted || picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (morning) {
        _morning = minutes;
      } else {
        _evening = minutes;
      }
    });
    try {
      if (morning) {
        await _storage.saveMorningMinutes(minutes);
      } else {
        await _storage.saveEveningMinutes(minutes);
      }
    } catch (_) {
      // Keep in-session choice if storage is unavailable.
    }
    if (_enabled) {
      await RitualNotificationService.scheduleDailyRituals(
        morningMinutes: _morning,
        eveningMinutes: _evening,
        weekdays: _weekdays,
        requestPermission: false,
      );
    }
  }

  Future<void> _setLunarPhase({bool? newMoon, bool? fullMoon}) async {
    HapticFeedback.selectionClick();
    final nextNew = newMoon ?? _newMoonEnabled;
    final nextFull = fullMoon ?? _fullMoonEnabled;
    final turningOn =
        (newMoon == true && !_newMoonEnabled) ||
        (fullMoon == true && !_fullMoonEnabled);
    setState(() {
      _newMoonEnabled = nextNew;
      _fullMoonEnabled = nextFull;
    });
    try {
      await _storage.saveLunarNewMoonEnabled(nextNew);
      await _storage.saveLunarFullMoonEnabled(nextFull);
    } catch (_) {
      // Keep in-session state if storage is unavailable.
    }
    final result = await RitualNotificationService.scheduleLunarPhases(
      newMoon: nextNew,
      fullMoon: nextFull,
      requestPermission: turningOn,
    );
    if (turningOn && !result.permissionGranted) {
      _notify(
        AppStrings.g('ritual.permissionDenied'),
        tone: TaroGlassSnackbarTone.warning,
      );
    }
  }

  Future<void> _setNewsSubscribed(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _newsEnabled = value);
    try {
      await _storage.saveNewsNotificationsEnabled(value);
    } catch (_) {
      // Keep in-session state if storage is unavailable.
    }
    final result = await RitualNotificationService.setNewsSubscribed(value);
    if (value && !result.permissionGranted) {
      _notify(
        AppStrings.g('ritual.permissionDenied'),
        tone: TaroGlassSnackbarTone.warning,
      );
    } else {
      _notify(
        AppStrings.g(
          value ? 'ritual.news.subscribed' : 'ritual.news.unsubscribed',
        ),
        tone: value ? TaroGlassSnackbarTone.success : TaroGlassSnackbarTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild immediately when the user changes app language.
    context.watch<AppSettingsController?>();
    if (widget.inline) return _sections(context);
    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.g('ui.ritual_settings_sheet.daily_ritual'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 16),
            _sections(context),
          ],
        ),
      ),
    );
  }

  Widget _sections(BuildContext context) {
    if (!_loaded) {
      final loader = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: TaroGlassProgress(linear: false, size: 22),
        ),
      );
      return widget.inline
          ? TaroGlassPanel(radius: 20, padding: const EdgeInsets.all(16), child: loader)
          : loader;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NotificationSectionCard(
          key: const ValueKey('ritual-section-daily'),
          inline: widget.inline,
          title: AppStrings.g('ritual.section.daily'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ToggleRow(
                toggleKey: const ValueKey('ritual-daily-toggle'),
                icon: Icons.notifications_outlined,
                label: AppStrings.g(
                  'ui.ritual_settings_sheet.daily_ritual_reminders',
                ),
                value: _enabled,
                onChanged: _setDailyEnabled,
              ),
              const SizedBox(height: 12),
              _WeekdaySelector(
                selectedDays: _weekdays,
                enabled: _enabled,
                onToggle: _toggleWeekday,
              ),
              const SizedBox(height: 12),
              _TimeTile(
                key: const ValueKey('ritual-morning-tile'),
                icon: Icons.wb_twilight_outlined,
                label: AppStrings.g(
                  'ritual.notification.morningTitle',
                ).toUpperCase(),
                hint: AppStrings.g('ritual.morningHint'),
                time: _fmt(_morning),
                enabled: _enabled,
                onTap: () => _pickTime(morning: true),
              ),
              const SizedBox(height: 10),
              _TimeTile(
                key: const ValueKey('ritual-evening-tile'),
                icon: Icons.nightlight_outlined,
                label: AppStrings.g(
                  'ritual.notification.eveningTitle',
                ).toUpperCase(),
                hint: AppStrings.g('ritual.eveningHint'),
                time: _fmt(_evening),
                enabled: _enabled,
                onTap: () => _pickTime(morning: false),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TaroColors.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                      color: TaroColors.dawn,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.g('ritual.streak', {'streak': _streak}),
                        style: AppTypography.label(
                          fontSize: 10,
                          letterSpacing: 0.9,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _NotificationSectionCard(
          key: const ValueKey('ritual-section-lunar'),
          inline: widget.inline,
          title: AppStrings.g('ritual.section.lunar'),
          subtitle: AppStrings.g('ritual.lunar.subtitle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ToggleRow(
                toggleKey: const ValueKey('ritual-new-moon-toggle'),
                icon: Icons.brightness_2_outlined,
                label: AppStrings.g('ritual.lunar.newMoon'),
                subtitle: _nextNewMoon == null
                    ? null
                    : AppStrings.g('ritual.lunar.nextDate', {
                        'date': _fmtDate(_nextNewMoon.utcTime),
                      }),
                value: _newMoonEnabled,
                onChanged: (v) => _setLunarPhase(newMoon: v),
              ),
              const SizedBox(height: 10),
              _ToggleRow(
                toggleKey: const ValueKey('ritual-full-moon-toggle'),
                icon: Icons.brightness_1_outlined,
                iconColor: TaroColors.dawn,
                label: AppStrings.g('ritual.lunar.fullMoon'),
                subtitle: _nextFullMoon == null
                    ? null
                    : AppStrings.g('ritual.lunar.nextDate', {
                        'date': _fmtDate(_nextFullMoon.utcTime),
                      }),
                value: _fullMoonEnabled,
                onChanged: (v) => _setLunarPhase(fullMoon: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _NotificationSectionCard(
          key: const ValueKey('ritual-section-news'),
          inline: widget.inline,
          title: AppStrings.g('ritual.section.news'),
          child: _ToggleRow(
            toggleKey: const ValueKey('ritual-news-toggle'),
            icon: Icons.campaign_outlined,
            label: AppStrings.g('ritual.news.toggle'),
            subtitle: AppStrings.g('ritual.news.subtitle'),
            value: _newsEnabled,
            onChanged: _setNewsSubscribed,
          ),
        ),
      ],
    );
  }
}

class _NotificationSectionCard extends StatelessWidget {
  const _NotificationSectionCard({
    super.key,
    required this.inline,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final bool inline;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTypography.label(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
            color: TaroColors.lavender,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
    if (!inline) return content;
    return TaroGlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.toggleKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.iconColor = TaroColors.lavender,
  });

  final Key toggleKey;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value ? iconColor : TaroColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: TaroColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TaroGlassToggle(
            key: toggleKey,
            value: value,
            semanticLabel: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({
    required this.selectedDays,
    required this.enabled,
    required this.onToggle,
  });

  final Set<int> selectedDays;
  final bool enabled;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.g('ritual.daysLabel'),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.9,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++) ...[
                if (day > DateTime.monday) const SizedBox(width: 4),
                Expanded(
                  child: _WeekdayPill(
                    day: day,
                    label: AppStrings.g('ritual.weekday.$day'),
                    selected: selectedDays.contains(day),
                    active: enabled,
                    onTap: () => onToggle(day),
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

class _WeekdayPill extends StatelessWidget {
  const _WeekdayPill({
    required this.day,
    required this.label,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final int day;
  final String label;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = active ? TaroColors.lavender : TaroColors.mist;
    final fill = selected
        ? accent.withValues(alpha: active ? 0.24 : 0.12)
        : Colors.transparent;
    final border = selected
        ? accent.withValues(alpha: active ? 0.85 : 0.35)
        : TaroColors.mist.withValues(alpha: TaroOpacity.border);
    final textColor = selected
        ? (active ? TaroColors.textPrimary : TaroColors.textSecondary)
        : TaroColors.textSecondary.withValues(alpha: 0.65);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        key: ValueKey('ritual-weekday-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.label(
                fontSize: 9.5,
                letterSpacing: 0.4,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: TaroColors.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: TaroColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label(
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: AppTypography.label(
                  fontSize: 13,
                  letterSpacing: 0.7,
                  color: enabled
                      ? TaroColors.lavender
                      : TaroColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
