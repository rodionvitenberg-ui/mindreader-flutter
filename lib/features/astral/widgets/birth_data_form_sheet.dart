import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/astro_cities_data.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
import '../../../core/models/natal_chart.dart';
import '../../../core/services/natal_calculator_service.dart';
import '../../../core/services/birth_time_service.dart';
import '../astral_copy.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/astral_controller.dart';
import '../../../state/user_profile_controller.dart';
import 'astral_gradient_button.dart';
import 'astral_house_selector.dart';

/// Birth-data form for a new natal profile. Feeds
/// [NatalCalculatorService.calculateNatalChart] and hands the result to
/// [AstralController.generateChart].
class BirthDataFormSheet extends StatefulWidget {
  const BirthDataFormSheet({this.chart, super.key});

  final NatalChart? chart;

  static Future<NatalChart?> show(BuildContext context, {NatalChart? chart}) {
    return showTaroGlassSheet<NatalChart>(
      context: context,
      builder: (_) => BirthDataFormSheet(chart: chart),
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
  bool _timeKnown = false;
  AstroCity? _city;
  late HouseSystem _house;

  @override
  void initState() {
    super.initState();
    _date = DateTime(DateTime.now().year - 30, 1, 1);
    _house = context.read<AstralController>().activeHouseSystem;
    final chart = widget.chart;
    if (chart != null) {
      _nameCtrl.text = chart.profileName;
      _date = DateTime(
        chart.birthLocalYear,
        chart.birthLocalMonth,
        chart.birthLocalDay,
      );
      _time = TimeOfDay(
        hour: chart.birthLocalHour,
        minute: chart.birthLocalMinute,
      );
      _timeKnown = chart.timeKnown;
      _house = chart.houseSystem;
      _city =
          _matchingCity(chart.cityName) ??
          AstroCity(
            name: chart.cityName,
            country: chart.country,
            latitude: chart.latitude,
            longitude: chart.longitude,
            timezoneOffsetHours: chart.timezoneOffsetHours,
            timezoneId: chart.timezoneId,
          );
    }
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
            primary: TaroColors.lavender,
            surface: TaroColors.surface,
            onPrimary: TaroColors.background,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: TaroColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (mounted && picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TaroColors.lavender,
            surface: TaroColors.surface,
            onPrimary: TaroColors.background,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: TaroColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (mounted && picked != null) setState(() => _time = picked);
  }

  /// 1-tap fill from the local profile on the PROFILE tab.
  void _fillFromProfile() {
    final profile = context.read<UserProfileController>();
    if (!profile.hasBirthData) {
      showTaroGlassSnackbar(
        context,
        message:
            context.read<AppSettingsController?>()?.language == AppLanguage.ru
                ? 'Сначала добавьте дату и город рождения в Профиле.'
                : 'Add your birth date and city in Profile first.',
        tone: TaroGlassSnackbarTone.warning,
      );
      return;
    }
    HapticFeedback.selectionClick();
    final match = _matchingCity(profile.cityName);
    setState(() {
      _nameCtrl.text = profile.displayName.trim().isEmpty
          ? 'My Chart'
          : profile.displayName;
      _date = profile.birthDate!;
      if (profile.birthTime != null) _time = profile.birthTime!;
      _timeKnown = profile.birthTimeKnown && profile.birthTime != null;
      _city =
          match ??
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

  AstroCity? _matchingCity(String name) => astroCities
      .where(
        (city) =>
            city.name.toLowerCase() == name.trim().toLowerCase() ||
            city.russianName?.toLowerCase() == name.trim().toLowerCase(),
      )
      .firstOrNull;

  bool _saving = false;

  Future<void> _generate() async {
    if (_saving) return;
    final city = _city;
    if (city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.astralRead('missingCity'))),
      );
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty
        ? 'My Chart'
        : _nameCtrl.text.trim();
    final timeKnown = _timeKnown;
    final hour = timeKnown ? _time.hour : 12;
    final minute = timeKnown ? _time.minute : 0;
    final date = _date;
    final houseSystem = _house;
    final wallClock = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final choices = BirthTimeService.resolve(city, wallClock);
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.astralRead('skippedTime'))),
      );
      return;
    }

    BirthInstant? chosen = choices.first;
    if (choices.length > 1 && timeKnown) {
      _saving = true;
      final title = context.astralRead('repeatedTime');
      chosen = await showDialog<BirthInstant>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(title),
          children: [
            for (final option in choices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option),
                child: Text(BirthTimeService.offsetLabel(option.offset)),
              ),
          ],
        ),
      );
      _saving = false;
    }
    if (!mounted || chosen == null) return;

    DateTime? dayBoundary(int day) {
      for (var hour = 0; hour < 24; hour++) {
        final instants = BirthTimeService.resolve(
          city,
          DateTime.utc(date.year, date.month, day, hour),
        );
        if (instants.isNotEmpty) return instants.first.utc;
      }
      return null;
    }

    final initial = widget.chart;
    final chart = NatalCalculatorService.calculateNatalChart(
      id: initial?.id ?? 'chart-${DateTime.now().microsecondsSinceEpoch}',
      createdAt: initial?.createdAt,
      profileName: name,
      birthDateUtc: chosen.utc,
      birthLocalYear: date.year,
      birthLocalMonth: date.month,
      birthLocalDay: date.day,
      birthLocalHour: hour,
      birthLocalMinute: minute,
      timeKnown: timeKnown,
      birthDayStartUtc: timeKnown ? null : dayBoundary(date.day),
      birthDayEndUtc: timeKnown ? null : dayBoundary(date.day + 1),
      cityName: city.name,
      country: city.country,
      latitude: city.latitude,
      longitude: city.longitude,
      timezoneOffsetHours: chosen.offset.inSeconds / 3600,
      timezoneId: city.timezoneId,
      houseSystem: houseSystem,
    );

    final controller = context.read<AstralController>();
    if (initial != null) {
      controller.updateChart(chart);
    } else if (controller.generateChart(chart) ==
        AstralGenerateResult.proGateBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ASTRAL PRO required for a 3rd natal profile.'),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, chart);
  }

  @override
  Widget build(BuildContext context) {
    final query = _cityCtrl.text.trim();
    final results = query.isEmpty
        ? const <AstroCity>[]
        : searchAstroCities(query, limit: 5);

    return TaroGlassSheet(
      title: context.astralText(widget.chart == null ? 'newChart' : 'edit'),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileFillPill(onFill: _fillFromProfile),
          const SizedBox(height: 14),
          TaroGlassInput(
            label: context.astralText('name'),
            controller: _nameCtrl,
            hint: context.astralRussian
                ? 'Как назвать карту'
                : 'How to address this chart',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow(context.astralText('date')),
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
                    _eyebrow(context.astralText('time')),
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
          TaroGlassInput(
            label: context.astralText('city'),
            controller: _cityCtrl,
            hint: context.astralText('searchCity'),
            onChanged: (_) => setState(() {}),
          ),
          if (_city != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _SelectedCity(city: _city!),
            ),
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
          if (_timeKnown) ...[
            const SizedBox(height: 16),
            _eyebrow(context.astralText('house')),
            AstralHouseSelector(
              value: _house,
              onChanged: (system) => setState(() => _house = system),
            ),
          ],
          const SizedBox(height: 22),
          AstralGradientButton(
            label: context.astralText(
              widget.chart == null ? 'generate' : 'save',
            ),
            onTap: _generate,
          ),
        ],
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
      style: AppTypography.label(
        fontSize: 9,
        letterSpacing: 1.0,
        color: TaroColors.textSecondary,
      ),
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
          color: TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
          ),
        ),
        child: Row(
          children: [
            Text(glyph, style: const TextStyle(color: TaroColors.lavender)),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TaroColors.textPrimary,
                  ),
                ),
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
            context.astralText('selectTime'),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 1.0,
              color: TaroColors.textSecondary,
            ),
          ),
        ),
        TaroGlassToggle(
          value: value,
          semanticLabel: context.astralText('selectTime'),
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
    return TaroGlassPill(
      label: '${city.name}, ${city.country}',
      icon: Icons.place_outlined,
      accent: true,
    );
  }
}

class _CityResult extends StatelessWidget {
  const _CityResult({required this.city, required this.onTap});

  final AstroCity city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${context.astralRussian ? city.russianName ?? city.name : city.name} · ${city.country}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: TaroColors.textPrimary,
                ),
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
    return TaroGlassChip(
      label: context.astralText('profileFill'),
      icon: Icons.person_pin_circle_outlined,
      selected: true,
      expanded: true,
      onTap: onFill,
    );
  }
}
