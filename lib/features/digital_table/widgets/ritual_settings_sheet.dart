import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/ritual_notification_service.dart';
import '../../../core/theme/app_colors.dart';

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
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
    final picked =
        await showTimePicker(context: context, initialTime: current);
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
    final content = Padding(
      padding: widget.inline
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: _content(context),
    );
    if (widget.inline) return content;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.inline)
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
                const SizedBox(height: 16),
                Text('DAILY RITUAL',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 4),
                Text(
                  'LOCAL REMINDERS · ZERO SERVER RETENTION · '
                  '$_streak-DAY STREAK',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_loaded)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.lavender,
                        ),
                      ),
                    ),
                  )
                else ...[
                  _RitualSwitch(
                    value: _enabled,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
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
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_outlined,
                            size: 18, color: AppColors.conflictAmber),
                        const SizedBox(width: 10),
                        Text(
                          '$_streak-DAY READING STREAK',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            letterSpacing: 1.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ApplyButton(
                    label: _enabled ? 'SAVE RITUAL TIMES' : 'DISABLE RITUALS',
                    onTap: _apply,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 18, color: AppColors.lavender),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DAILY RITUAL REMINDERS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.lavender.withValues(alpha: 0.5),
            activeThumbColor: AppColors.lavender,
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
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      letterSpacing: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                letterSpacing: 1.2,
                color: enabled ? AppColors.lavender : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
