import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/data/intention_prompts.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/spread_type.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';

/// An advisory sequence derived from confirmed slots. Never advances the deck.
int? recommendedPosition(SpreadController ctrl) {
  final empty = ctrl.nextEmptySlotIndex;
  if (empty != null && empty < ctrl.spreadCardCount) return empty;
  final slots = ctrl.slots.take(ctrl.spreadCardCount).toList();
  final centerFirst =
      !ctrl.isCustomSpread &&
      ctrl.system == DivinationSystem.tarot &&
      ctrl.spreadType == SpreadType.three &&
      slots.length >= 3;
  if (centerFirst && slots[1].state == SlotState.faceDown) return 1;
  for (final slot in slots) {
    if (slot.state == SlotState.faceDown) return slot.index;
  }
  return null;
}

class GuideHighlight extends StatelessWidget {
  const GuideHighlight({super.key, this.slot, required this.child});
  final int? slot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AppSettingsController>().enabled(
      ReadingAid.guide,
    );
    final ctrl = context.watch<SpreadController>();
    final highlight =
        enabled &&
        (slot == null
            ? ctrl.nextEmptySlotIndex != null
            : recommendedPosition(ctrl) == slot);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: TaroColors.lavender, width: 1.5)
            : null,
      ),
      child: child,
    );
  }
}

class ReadingGuide extends StatelessWidget {
  const ReadingGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final settings = context.watch<AppSettingsController>();
    if (!ctrl.isSpreadActive || !settings.enabled(ReadingAid.guide)) {
      return const SizedBox.shrink();
    }
    final ru = settings.language == AppLanguage.ru;
    final i = recommendedPosition(ctrl);
    final dealing = ctrl.nextEmptySlotIndex != null;
    final role = i == null ? '' : ctrl.slots[i].role;
    final prompt = i == null
        ? (ru
              ? 'Как прочитать расклад целиком?'
              : 'How do the positions read together?')
        : dealing
        ? (ru
              ? 'Выложите ${i + 1} из ${ctrl.spreadCardCount} · $role'
              : 'Deal ${i + 1} of ${ctrl.spreadCardCount} · $role')
        : (ru
              ? 'Можно открыть ${i + 1} · $role'
              : 'Try revealing ${i + 1} · $role');
    return TextButton.icon(
      key: const ValueKey('reading-guide'),
      icon: const Icon(Icons.menu_book_outlined, size: 16),
      label: Text(prompt, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () => showTaroGlassSheet<void>(
        context: context,
        builder: (sheet) {
          final dealingTip = ctrl.isSpreadOverview
              ? ctrl.system == DivinationSystem.runes
                    ? (ru
                          ? 'Коснитесь камней, чтобы выложить руну.'
                          : 'Tap the stones to cast the next rune.')
                    : (ru
                          ? 'Коснитесь колоды или удерживайте карту и перенесите её на подсвеченное место.'
                          : 'Tap the deck, or hold and carry a card to the highlighted space.')
              : (ru
                    ? 'Потяните карту или камень вниз из стопки.'
                    : 'Pull a card or stone down from the stack.');
          return TaroGlassSheet(
            title: prompt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctrl.spreadFocusLine),
                if (i != null && i < ctrl.spreadCardCount)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      ctrl.isCustomSpread
                          ? ctrl.customSpread!.questions[i]
                          : ctrl.system == DivinationSystem.tarot &&
                                ctrl.spreadType == SpreadType.three
                          ? intentionForSlot(i).question
                          : (ru
                                ? 'Как образ карты раскрывает тему «$role» в этом раскладе?'
                                : 'Which detail in the image helps you read “$role” in this spread?'),
                    ),
                  ),
                if (ctrl.system == DivinationSystem.tarot &&
                    ctrl.faceUpCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      ru
                          ? 'В этой системе Жезлы — Огонь, Кубки — Вода, Мечи — Воздух, Пентакли — Земля. Переворот меняет трактовку карты, сохраняя её стихию.'
                          : 'In this system Wands carry Fire, Cups Water, Swords Air and Pentacles Earth. Reversal changes how you read a card while its element stays the same.',
                    ),
                  ),

                const SizedBox(height: 12),
                if (dealing)
                  Text(dealingTip)
                else if (i != null)
                  Text(
                    ru
                        ? 'Откройте любую карту. Подумайте, как её образ отвечает на вопрос позиции.'
                        : 'Reveal any card you like. How does its image answer the question of its position?',
                  )
                else
                  Text(
                    ru
                        ? 'Выберите образ на первой карте и сравните его с другой позицией. Где он повторяется? Где меняется?'
                        : 'Pick an image on one card and compare it with another position. Where does that image repeat or change?',
                  ),
                if (ctrl.relationships.any((r) => r.influence != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      ru
                          ? 'В традиции Золотой Зари стихии помогают сравнивать карты. Можно также читать образы и значения позиций без стихий.'
                          : 'Golden Dawn elemental dignities compare the elements of cards. A positional reading can instead explore how each image answers its question.',
                    ),
                  ),
                if (ctrl.relationships.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(ctrl.relationships.first.explanation),
                  ),
                TextButton(
                  onPressed: () {
                    settings.setAid(ReadingAid.guide, false);
                    Navigator.pop(sheet);
                  },
                  child: Text(ru ? 'Выключить подсказки' : 'Turn off guidance'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
