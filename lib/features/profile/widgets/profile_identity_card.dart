import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/data/astro_cities_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/user_profile_controller.dart';
import 'profile_card.dart';

/// Card 1 — identity, birth data and the free-form life context. Everything
/// here stays on the device (Zero-Knowledge badge).
class ProfileIdentityCard extends StatefulWidget {
  const ProfileIdentityCard({super.key});

  @override
  State<ProfileIdentityCard> createState() => _ProfileIdentityCardState();
}

class _ProfileIdentityCardState extends State<ProfileIdentityCard> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  List<AstroCity> _matches = const [];

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProfileController>();
    _name = TextEditingController(text: profile.displayName);
    _city = TextEditingController(text: profile.cityName);
    _bio = TextEditingController(text: profile.personalBioContext);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final profile = context.read<UserProfileController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.birthDate ?? DateTime(DateTime.now().year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    profile.setBirthData(date: picked);
  }

  Future<void> _pickTime() async {
    final profile = context.read<UserProfileController>();
    final picked = await showTimePicker(
      context: context,
      initialTime: profile.birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    profile.setBirthData(time: picked, timeKnown: true);
  }

  void _selectCity(AstroCity city) {
    HapticFeedback.selectionClick();
    _city.text = city.name;
    setState(() => _matches = const []);
    context.read<UserProfileController>().setBirthData(
          cityName: city.name,
          latitude: city.latitude,
          longitude: city.longitude,
          timezoneOffset: city.timezoneOffsetHours,
        );
  }

  String _fmtDate(DateTime? date) => date == null
      ? 'NOT SET'
      : '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _fmtTime(TimeOfDay? time) => time == null
      ? 'UNKNOWN'
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    return ProfileCard(
      title: 'PERSONAL CONTEXT & BIRTH DATA',
      trailing: const ProfilePill(
        label: 'LOCAL ONLY',
        active: true,
        icon: Icons.shield_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileFieldLabel('NAME'),
          _field(
            controller: _name,
            hint: 'How the Oracle should address you',
            onChanged: profile.setDisplayName,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tile(
                  label: 'BIRTH DATE',
                  value: _fmtDate(profile.birthDate),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tile(
                  label: 'BIRTH TIME',
                  value: profile.birthTimeKnown
                      ? _fmtTime(profile.birthTime)
                      : 'UNKNOWN',
                  icon: Icons.schedule_outlined,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProfilePill(
            label: profile.birthTimeKnown ? 'BIRTH TIME KNOWN' : 'TIME UNKNOWN',
            active: profile.birthTimeKnown,
            icon: profile.birthTimeKnown
                ? Icons.check_circle_outline
                : Icons.help_outline,
            onTap: () =>
                profile.setBirthData(timeKnown: !profile.birthTimeKnown),
          ),
          const SizedBox(height: 12),
          const ProfileFieldLabel('BIRTH CITY'),
          _field(
            controller: _city,
            hint: 'Search a city',
            onChanged: (v) =>
                setState(() => _matches = searchAstroCities(v, limit: 5)),
          ),
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final city in _matches)
                    ProfilePill(
                      label: '${city.name}, ${city.country}',
                      onTap: () => _selectCity(city),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const ProfileFieldLabel('MY LIFE CONTEXT & BACKGROUND'),
          _field(
            controller: _bio,
            hint: 'Relationship status, career crossroads, inner state…',
            maxLines: 4,
            onChanged: profile.setPersonalBioContext,
          ),
          const ProfilePrivacyNote(
            'Stored strictly on your device. Used to personalize Oracle '
            'readings when you draw for yourself.',
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: AppColors.canvas.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lavender),
        ),
      ),
    );
  }

  Widget _tile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.canvas.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.lavender),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      letterSpacing: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
