import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/data/astro_cities_data.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/astral_controller.dart';
import '../../../state/user_profile_controller.dart';
import 'astral_gradient_button.dart';
import 'astral_house_selector.dart';

/// Birth-data form for a new natal profile. Feeds
/// [NatalCalculatorService.calculateNatalChart] and hands the result to
/// [AstralController.generateChart].
class BirthDataFormSheet extends StatefulWidget {
  const BirthDataFormSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const BirthDataFormSheet(),
    );
  }

  @override
  State<BirthDataFormSheet> createState() => _BirthDataFormSheetState();
}

class _BirthDataFormSheetState extends State<BirthDataFormSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();

  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  bool _timeKnown = true;
  AstroCity? _city;
  late HouseSystem _house;

  @override
  void initState() {
    super.initState();
    _date = DateTime(DateTime.now().year - 30, 1, 1);
    _house = context.read<AstralController>().activeHouseSystem;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.lavender,
            surface: AppColors.surface,
            onPrimary: AppColors.canvas,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.lavender,
            surface: AppColors.surface,
            onPrimary: AppColors.canvas,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  /// 1-tap fill from the local profile on the PROFILE tab.
  void _fillFromProfile() {
    final profile = context.read<UserProfileController>();
    if (!profile.hasBirthData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your birth date and city in PROFILE first.'),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    AstroCity? match;
    for (final city in astroCities) {
      if (city.name.toLowerCase() == profile.cityName.toLowerCase()) {
        match = city;
        break;
      }
    }
    setState(() {
      _nameCtrl.text =
          profile.displayName.trim().isEmpty ? 'My Chart' : profile.displayName;
      _date = profile.birthDate!;
      if (profile.birthTime != null) _time = profile.birthTime!;
      _timeKnown = profile.birthTimeKnown;
      _city = match ??
          AstroCity(
            name: profile.cityName,
            country: '',
            latitude: profile.latitude!,
            longitude: profile.longitude!,
            timezoneOffsetHours: profile.timezoneOffset ?? 0,
          );
      _cityCtrl.clear();
    });
  }

  void _generate() {
    final city = _city;
    if (city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a birth city first.')),
      );
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final name =
        _nameCtrl.text.trim().isEmpty ? 'My Chart' : _nameCtrl.text.trim();
    final hour = _timeKnown ? _time.hour : 12;
    final minute = _timeKnown ? _time.minute : 0;
    final utc = DateTime.utc(_date.year, _date.month, _date.day, hour, minute)
        .subtract(Duration(minutes: (city.timezoneOffsetHours * 60).round()));

    final chart = NatalCalculatorService.calculateNatalChart(
      id: 'chart-${DateTime.now().microsecondsSinceEpoch}',
      profileName: name,
      birthDateUtc: utc,
      birthLocalYear: _date.year,
      birthLocalMonth: _date.month,
      birthLocalDay: _date.day,
      birthLocalHour: hour,
      birthLocalMinute: minute,
      timeKnown: _timeKnown,
      cityName: city.name,
      country: city.country,
      latitude: city.latitude,
      longitude: city.longitude,
      timezoneOffsetHours: city.timezoneOffsetHours,
      houseSystem: _house,
    );

    final result = context.read<AstralController>().generateChart(chart);
    HapticFeedback.mediumImpact();
    navigator.pop();
    if (result == AstralGenerateResult.proGateBlocked) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ASTRAL PRO required for a 3rd natal profile.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _cityCtrl.text.trim();
    final results =
        query.isEmpty ? const <AstroCity>[] : searchAstroCities(query, limit: 5);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: const Color(0xEB13131A),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),
                  Text(
                    'NEW NATAL CHART',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BIRTH DATA · STAYS ON THIS DEVICE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      letterSpacing: 1.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProfileFillPill(onFill: _fillFromProfile),
                  const SizedBox(height: 14),
                  _eyebrow('NAME'),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _fieldDecoration('How to address this chart'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _eyebrow('DATE'),
                            _PickerField(
                              glyph: '◷',
                              value: _dateLabel,
                              onTap: _pickDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _eyebrow('TIME'),
                            _PickerField(
                              glyph: '☾',
                              value: _timeKnown ? _timeLabel : '--:--',
                              onTap: _timeKnown ? _pickTime : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TimeKnownSwitch(
                    value: _timeKnown,
                    onChanged: (value) => setState(() => _timeKnown = value),
                  ),
                  const SizedBox(height: 14),
                  _eyebrow('BIRTH CITY'),
                  TextField(
                    controller: _cityCtrl,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration('Search a city'),
                  ),
                  if (_city != null) ...[
                    const SizedBox(height: 8),
                    _SelectedCity(city: _city!),
                  ],
                  for (final city in results)
                    _CityResult(
                      city: city,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _city = city;
                          _cityCtrl.clear();
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  _eyebrow('HOUSE SYSTEM'),
                  AstralHouseSelector(
                    value: _house,
                    onChanged: (system) => setState(() => _house = system),
                  ),
                  const SizedBox(height: 22),
                  AstralGradientButton(
                    label: '✦ GENERATE NATAL CHART',
                    onTap: _generate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _dateLabel {
    final d = _date.day.toString().padLeft(2, '0');
    final m = _date.month.toString().padLeft(2, '0');
    return '$d.$m.${_date.year}';
  }

  String get _timeLabel {
    final h = _time.hour.toString().padLeft(2, '0');
    final m = _time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.8,
            color: AppColors.textMuted,
          ),
        ),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lavender),
        ),
      );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.glyph,
    required this.value,
    required this.onTap,
  });

  final String glyph;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(glyph, style: const TextStyle(color: AppColors.lavender)),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeKnownSwitch extends StatelessWidget {
  const _TimeKnownSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'BIRTH TIME KNOWN',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.lavender,
          activeTrackColor: AppColors.indigo.withValues(alpha: 0.5),
          inactiveThumbColor: AppColors.textMuted,
          inactiveTrackColor: AppColors.surface,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelectedCity extends StatelessWidget {
  const _SelectedCity({required this.city});

  final AstroCity city;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, size: 14, color: AppColors.lavender),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${city.name}, ${city.country}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityResult extends StatelessWidget {
  const _CityResult({required this.city, required this.onTap});

  final AstroCity city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final offset = city.timezoneOffsetHours >= 0
        ? '+${city.timezoneOffsetHours.toStringAsFixed(1)}'
        : city.timezoneOffsetHours.toStringAsFixed(1);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${city.name} · ${city.country}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              'UTC$offset',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-tap entry point for the local profile birth data.
class _ProfileFillPill extends StatelessWidget {
  const _ProfileFillPill({required this.onFill});

  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFill,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined,
                size: 14, color: AppColors.lavender),
            const SizedBox(width: 8),
            Text(
              'USE BIRTH DATA FROM MY PROFILE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
