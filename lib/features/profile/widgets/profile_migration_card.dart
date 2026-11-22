import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../design_system/taro.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/user_profile_controller.dart';
import 'profile_card.dart';

/// Card 3 — device-to-device migration (Phase G5: [ProfileCard] +
/// [TaroGlassButton] + [showTaroGlassSnackbar]).
class ProfileMigrationCard extends StatelessWidget {
  const ProfileMigrationCard({super.key});

  Future<void> _export(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaroColors.surface,
        title: Text(AppStrings.g('ui.profile_migration_card.export_data'),
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.4,
            color: TaroColors.textPrimary,
          ),
        ),
        content: Text(
          AppStrings.g('profile.migration.explainer'),
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: TaroColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.g('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppStrings.g('common.export')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final payload =
        context.read<UserProfileController>().exportAllUserDataJson();
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaroColors.surface,
        title: Text(AppStrings.g('ui.profile_migration_card.snapshot_ready'),
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.4,
            color: TaroColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 240,
          child: SingleChildScrollView(
            child: SelectableText(
              payload,
              style: const TextStyle(
                fontSize: 10,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.g('common.done')),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaroColors.surface,
        title: Text(AppStrings.g('ui.profile_migration_card.import_data'),
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.4,
            color: TaroColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 8,
          cursorColor: TaroColors.lavender,
          style: const TextStyle(fontSize: 11, color: TaroColors.textPrimary),
          decoration: InputDecoration(
            hintText: AppStrings.g('ui.profile_migration_card.paste_the_backup_json_here'),
            hintStyle: TextStyle(fontSize: 11, color: TaroColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.g('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(AppStrings.g('common.import')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (payload == null || payload.trim().isEmpty || !context.mounted) return;
    final ok = context.read<UserProfileController>().importUserDataJson(payload);
    if (!context.mounted) return;
    showTaroGlassSnackbar(
      context,
      message: ok
          ? AppStrings.g('ui.profile_migration_card.backup_imported_profile_sessions_and_natal_chart') : AppStrings.g('ui.profile_migration_card.this_payload_is_not_a_valid_backup'),
      tone: ok ? TaroGlassSnackbarTone.success : TaroGlassSnackbarTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      section: SettingsSection.deviceMigration,
      title: AppStrings.t(context.watch<AppSettingsController>().language, 'profile.card.migration'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaroGlassButton(
            icon: Icons.cloud_upload_outlined,
            label: AppStrings.g('ui.profile_migration_card.export_data_for_new_device'),
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () => _export(context),
          ),
          const SizedBox(height: 10),
          TaroGlassButton(
            icon: Icons.download_outlined,
            label: AppStrings.g('ui.profile_migration_card.import_data'),
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () => _import(context),
          ),
        ],
      ),
    );
  }
}
