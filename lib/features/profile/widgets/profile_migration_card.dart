import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../design_system/taro.dart';
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
        title: const Text(
          'EXPORT DATA',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.4,
            color: TaroColors.textPrimary,
          ),
        ),
        content: Text(
          'To move your history and profiles to a new device, a snapshot of '
          'your local data (profile, sessions, natal charts) is generated on '
          'this phone. No relay server is configured yet: the snapshot is '
          'copied to your clipboard and shown here so you can transfer it '
          'yourself.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: TaroColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('EXPORT'),
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
        title: const Text(
          'SNAPSHOT READY',
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
            child: const Text('DONE'),
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
        title: const Text(
          'IMPORT DATA',
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
          decoration: const InputDecoration(
            hintText: 'Paste the backup JSON here',
            hintStyle: TextStyle(fontSize: 11, color: TaroColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('IMPORT'),
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
          ? 'Backup imported — profile, sessions and natal charts merged.'
          : 'This payload is not a valid backup.',
      tone: ok ? TaroGlassSnackbarTone.success : TaroGlassSnackbarTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      title: 'DEVICE MIGRATION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaroGlassButton(
            icon: Icons.cloud_upload_outlined,
            label: 'EXPORT DATA FOR NEW DEVICE',
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () => _export(context),
          ),
          const SizedBox(height: 10),
          TaroGlassButton(
            icon: Icons.download_outlined,
            label: 'IMPORT DATA',
            variant: TaroGlassButtonVariant.secondary,
            onPressed: () => _import(context),
          ),
        ],
      ),
    );
  }
}
