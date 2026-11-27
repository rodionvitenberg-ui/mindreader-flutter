import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/data/astro_cities_data.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
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

  Future<void> _pickAvatar() async {
    final profile = context.read<UserProfileController>();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final raw = await picked.readAsBytes();
      if (raw.isEmpty || !mounted) return;
      Uint8List encoded = raw;
      try {
        final decoded = img.decodeImage(raw);
        if (decoded != null) {
          final square = img.copyResizeCropSquare(decoded, size: 256);
          encoded = Uint8List.fromList(img.encodeJpg(square, quality: 82));
        }
      } catch (_) {
        // Keep the original bytes if re-encoding is unavailable for the format.
      }
      HapticFeedback.selectionClick();
      profile.setAvatarBytes(encoded);
    } catch (_) {
      // Ignore picker cancellation / unavailable platform channel.
    }
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
      initialEntryMode: TimePickerEntryMode.input,
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
      ? AppStrings.g('common.notSet')
      : '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _fmtTime(TimeOfDay? time) => time == null
      ? AppStrings.g('common.unknown')
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileController>();
    if (_name.text != profile.displayName &&
        !FocusScope.of(context).hasFocus) {
      _name.text = profile.displayName;
    }
    final lang = context.watch<AppSettingsController>().language;
    final avatarBytes = profile.avatarBytes;
    final name = profile.displayName.trim();
    final initial = name.isEmpty
        ? '✦'
        : String.fromCharCode(name.runes.first).toUpperCase();
    return ProfileCard(
      section: SettingsSection.personalContext,
      title: AppStrings.t(lang, 'profile.card.identity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TaroPalette.of(context).background.withValues(alpha: 0.72),
                    border: Border.all(
                      color: TaroColors.lavender.withValues(alpha: 0.65),
                      width: 1.4,
                    ),
                  ),
                  child: avatarBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            avatarBytes,
                            key: const ValueKey('profile-identity-avatar-image'),
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        )
                      : Text(
                          initial,
                          style: AppTypography.display(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: TaroColors.lavender,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ProfilePill(
                      key: const ValueKey('profile-pick-avatar'),
                      label: AppStrings.t(
                        lang,
                        avatarBytes == null
                            ? 'profile.avatar.add'
                            : 'profile.avatar.change',
                      ),
                      active: true,
                      icon: Icons.photo_camera_outlined,
                      onTap: _pickAvatar,
                    ),
                    if (avatarBytes != null)
                      ProfilePill(
                        key: const ValueKey('profile-remove-avatar'),
                        label: AppStrings.t(lang, 'profile.avatar.remove'),
                        icon: Icons.delete_outline,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          profile.clearAvatar();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProfileFieldLabel(AppStrings.g('common.name')),
          _field(
            controller: _name,
            hint: AppStrings.g('profile.field.nameHint'),
            onChanged: profile.setDisplayName,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tile(
                  label: AppStrings.g('ui.profile_identity_card.birth_date'),
                  value: _fmtDate(profile.birthDate),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tile(
                  label: AppStrings.g('ui.profile_identity_card.birth_time'),
                  value: profile.birthTimeKnown
                      ? _fmtTime(profile.birthTime)
                      : AppStrings.g('common.unknown'),
                  icon: Icons.schedule_outlined,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProfilePill(
            label: profile.birthTimeKnown ? AppStrings.g('ui.profile_identity_card.birth_time_known') : AppStrings.g('ui.profile_identity_card.time_unknown'),
            active: profile.birthTimeKnown,
            icon: profile.birthTimeKnown
                ? Icons.check_circle_outline
                : Icons.help_outline,
            onTap: () =>
                profile.setBirthData(timeKnown: !profile.birthTimeKnown),
          ),
          const SizedBox(height: 12),
          ProfileFieldLabel(AppStrings.g('astral.city')),
          _field(
            controller: _city,
            hint: AppStrings.g('astral.searchCity'),
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
          ProfileFieldLabel(AppStrings.g('profile.field.context')),
          _field(
            controller: _bio,
            hint: AppStrings.g('profile.field.contextHint'),
            maxLines: 4,
            onChanged: profile.setPersonalBioContext,
          ),
          ProfilePrivacyNote(AppStrings.g('profile.field.privacy')),
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
    final palette = TaroPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: palette.borderHairline),
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      cursorColor: TaroColors.lavender,
      style: const TextStyle(fontSize: 13, color: TaroColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: TaroColors.textSecondary.withValues(alpha: 0.72),
        ),
        filled: true,
        fillColor: palette.background.withValues(alpha: 0.56),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: palette.isMoonlit
                ? palette.activeOutline
                : TaroColors.lavender,
          ),
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
    final palette = TaroPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.background.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: TaroColors.lavender),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 11,
                      color: TaroColors.textPrimary,
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
