import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/oracle_personality.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

class OraclePersonalitySelector extends StatelessWidget {
  const OraclePersonalitySelector({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('oracle-personality-selector'),
      style: TextButton.styleFrom(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(44, 44),
        foregroundColor: TaroColors.lavender,
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading(
                fontSize: 18,
                color: TaroColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }
}

Future<OraclePersonality?> showOraclePersonalities(
  BuildContext context, {
  required Future<List<OraclePersonality>> catalogue,
  required String? Function() selected,
  required AppLanguage language,
  required OraclePersonality local,
}) {
  return showTaroGlassSheet<OraclePersonality>(
    context: context,
    builder: (context) => TaroGlassSheet(
      title: AppStrings.t(language, 'oracle.personality.title'),
      child: FutureBuilder<List<OraclePersonality>>(
        future: catalogue,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: TaroGlassProgress(linear: false));
          }
          final personalities = snapshot.data ?? const [];
          final selectedId = selected() ?? local.id;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (personalities.isEmpty)
                Text(AppStrings.t(language, 'oracle.personality.unavailable')),
              for (final entry in [...personalities, local])
                ListTile(
                  key: ValueKey('oracle-personality-${entry.id}'),
                  contentPadding: EdgeInsets.zero,
                  selected: entry.id == selectedId,
                  title: Text(entry.name),
                  subtitle: entry.description.isEmpty
                      ? null
                      : Text(entry.description),
                  trailing: entry.id == selectedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, entry),
                ),
            ],
          );
        },
      ),
    ),
  );
}
