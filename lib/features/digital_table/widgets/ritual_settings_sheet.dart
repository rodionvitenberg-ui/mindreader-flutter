import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/ritual_notification_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// Daily ritual settings: enable/disable local reminders, pick the morning
/// anchor (09:00) and evening reflection (22:00) times, and see the current
/// reading streak. Zero server retention — everything stays on the device.
class RitualSettingsSheet extends StatefulWidget {
  const RitualSettingsSheet({super.key, this.inline = false});

  /// When true the same controls render as plain page content (no sheet
  /// chrome, no drag handle, no auto-close) — used by ProfileScreen so the
  /// ritual toggles live on the full page instead of a second modal.
  final bool inline;

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
  int _streak = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final enabled = await _storage.loadRitualEnabled();
      final morning = await _storage.loadMorningMinutes();
      final evening = await _storage.loadEveningMinutes();
      final days = await _storage.loadReadingDays();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _morning = morning;
        _evening = evening;
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
    if (picked == null) return;
    setState(() {
      if (morning) {
        _morning = picked.hour * 60 + picked.minute;
      } else {
        _evening = picked.hour * 60 + picked.minute;
      }
    });
  }

  Future<void> _apply() async {
    HapticFeedback.mediumImpact();
    try {
      await _storage.saveRitualEnabled(_enabled);
      await _storage.saveMorningMinutes(_morning);
      await _storage.saveEveningMinutes(_evening);
      if (_enabled) {
        await RitualNotificationService.scheduleDailyRituals(
          morningMinutes: _morning,
          eveningMinutes: _evening,
        );
      } else {
        await RitualNotificationService.cancelRituals();
      }
    } catch (_) {
      // Settings persist even when the notification plugin is unavailable.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_enabled
            ? 'Daily ritual reminders set — all local, no server.'
            : 'Ritual reminders disabled.'),
      ),
    );
    if (!widget.inline) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) return _content(context);
    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.inline) const SizedBox(height: 8),
        Text('DAILY RITUAL', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(
          'LOCAL REMINDERS · ZERO SERVER RETENTION · '
          '$_streak-DAY STREAK',
          style: AppTypography.label(
            fontSize: 9,
            letterSpacing: 1.0,
            color: TaroColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        if (!_loaded)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: TaroGlassProgress(linear: false, size: 22),
            ),
          )
        else ...[
          _RitualSwitch(
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
            },
          ),
          const SizedBox(height: 14),
          _TimeTile(
            icon: Icons.wb_twilight_outlined,
            label: 'MORNING ANCHOR · 09:00',
            hint: 'Draw your Daily Anchor card.',
            time: _fmt(_morning),
            enabled: _enabled,
            onTap: () => _pickTime(morning: true),
          ),
          const SizedBox(height: 10),
          _TimeTile(
            icon: Icons.nightlight_outlined,
            label: 'EVENING REFLECTION · 22:00',
            hint: 'Ground your thoughts before sleep.',
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
                Text(
                  '$_streak-DAY READING STREAK',
                  style: AppTypography.label(
                    fontSize: 10,
                    letterSpacing: 0.9,
                    color: TaroColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TaroGlassButton(
            label: _enabled ? 'SAVE RITUAL TIMES' : 'DISABLE RITUALS',
            variant: _enabled
                ? TaroGlassButtonVariant.primary
                : TaroGlassButtonVariant.secondary,
            onPressed: _apply,
          ),
        ],
      ],
    );
  }
}

class _RitualSwitch extends StatelessWidget {
  const _RitualSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            Icons.notifications_outlined,
            size: 18,
            color: TaroColors.lavender,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DAILY RITUAL REMINDERS',
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.8,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
          TaroGlassToggle(
            value: value,
            semanticLabel: 'DAILY RITUAL REMINDERS',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
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
