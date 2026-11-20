import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/divination_system.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../../state/deck_pack_controller.dart';
import 'deck_cover.dart';

class DeckCoverPicker extends StatelessWidget {
  const DeckCoverPicker({super.key, required this.system});

  final DivinationSystem system;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeckPackController>();
    final pack = controller.activeFor(system);
    final covers = deckCovers(pack);
    final saved = controller.coverFor(pack);
    final active = covers.contains(saved) ? saved : covers.first;
    final language = context.watch<AppSettingsController>().language;
    final label = AppStrings.t(language, 'almanac.cover');
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemCount: covers.length,
              itemBuilder: (_, i) {
                final cover = covers[i];
                final selected = cover == active;
                return Semantics(
                  label: '$label ${i + 1}',
                  selected: selected,
                  button: true,
                  child: InkWell(
                    onTap: () => controller.setCover(pack, cover),
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.lavender
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: DeckCover(pack: pack, choice: cover),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
