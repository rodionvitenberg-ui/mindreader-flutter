import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/guide_copy.dart';
import '../../../core/data/intention_prompts.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/guide_event.dart';
import '../../../core/models/guide_hint.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/guided_reading_controller.dart';
import '../../../state/spread_controller.dart';
import 'guide_mascot.dart';

/// A lavender outline on the slot (or deck) the mentor currently recommends.
/// Purely advisory — the reader may always act out of order.
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
            : ctrl.recommendedSlot == slot);
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

/// The advisory bar rendered under the Active Digital Table. It reads the
/// single most relevant hint from [GuidedReadingController] (which is null
/// whenever guidance is off or nothing applies) and opens a detail sheet on
/// tap.
class ReadingGuide extends StatelessWidget {
  const ReadingGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final hint = context.watch<GuidedReadingController>().currentHint;
    if (hint == null) return const SizedBox.shrink();

    return TextButton.icon(
      key: const ValueKey('reading-guide'),
      icon: GuideMascot(mood: guideMascotMoodFor(hint)),
      label: Text(hint.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () {
        // Opening the sheet IS reading the lesson: record it so the mentor
        // never repeats what this reader already knows. The captured hint
        // keeps its lesson for the sheet being opened right now.
        context.read<GuidedReadingController>().learnCurrentLesson();
        showTaroGlassSheet<void>(
          context: context,
          builder: (sheet) => _GuideDetailSheet(
            hint: hint,
            ctrl: context.read<SpreadController>(),
            settings: context.read<AppSettingsController>(),
          ),
        );
      },
    );
  }
}

class _GuideDetailSheet extends StatefulWidget {
  const _GuideDetailSheet({
    required this.hint,
    required this.ctrl,
    required this.settings,
  });

  final GuideHint hint;
  final SpreadController ctrl;
  final AppSettingsController settings;

  @override
  State<_GuideDetailSheet> createState() => _GuideDetailSheetState();
}

class _GuideDetailSheetState extends State<_GuideDetailSheet> {
  String? _answer;
  bool _asking = false;

  /// The localized focus line of the active spread — one place, so the sheet
  /// body and the Oracle request can never disagree.
  String get _focus {
    final ctrl = widget.ctrl;
    return ctrl.guidePurpose(widget.settings.language) ?? ctrl.spreadFocusLine;
  }

  /// Deep explanation on the reader's EXPLICIT request (G4). The Oracle is
  /// never asked when the sheet opens, and the answer is kept once received.
  Future<void> _askOracle() async {
    if (_asking || _answer != null) return;
    HapticFeedback.selectionClick();
    setState(() => _asking = true);
    final ctrl = widget.ctrl;
    final text = await OracleSynthesisService().explainGuideMoment(
      moment: widget.hint.title,
      focus: _focus,
      slots: ctrl.slots,
      link: context.read<GuidedReadingController>().explainedRelationship,
      focusSlot: widget.hint.slotIndex,
    );
    if (!mounted) return;
    setState(() {
      _asking = false;
      _answer = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    final ctrl = widget.ctrl;
    final settings = widget.settings;
    final lang = settings.language;
    final i = hint.slotIndex;

    return TaroGlassSheet(
      title: hint.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_focus),
          if (i != null && i < ctrl.spreadCardCount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_slotQuestion(i)),
            ),
          // The conceptual lesson rides the hint: it disappears once read.
          if (hint.lesson != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(hint.lesson!),
            ),
          if (ctrl.system == DivinationSystem.tarot && ctrl.faceUpCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(GuideCopy.elementNote(lang)),
            )
          else if (ctrl.system != DivinationSystem.tarot)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(GuideCopy.methodNote(lang, ctrl.system)),
            ),
          const SizedBox(height: 12),
          Text(hint.body),
          if (ctrl.relationships.any((r) => r.influence != null))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(GuideCopy.goldenDawnNote(lang)),
            ),
          if (hint.eventType != GuideEventType.relationshipTapped &&
              ctrl.relationships.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(ctrl.relationships.first.localizedExplanation(lang)),
            ),
          if (ctrl.faceUpCount > 0) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('guide-ask-oracle'),
              onPressed: _asking || _answer != null ? null : _askOracle,
              child: Text(
                _asking
                    ? GuideCopy.oracleThinking(lang)
                    : GuideCopy.askOracle(lang),
              ),
            ),
            if (_answer != null) ...[
              Text(
                GuideCopy.oracleLabel(lang),
                style: AppTypography.label(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: TaroColors.lavender,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _answer!,
                key: const ValueKey('guide-oracle-answer'),
                style: AppTypography.body(
                  fontSize: 13,
                  color: TaroColors.textPrimary,
                  height: 1.55,
                ),
              ),
            ],
          ],
          if (hint.eventType == GuideEventType.relationshipTapped)
            TextButton(
              onPressed: () {
                context.read<GuidedReadingController>().clearRelationship();
                Navigator.pop(context);
              },
              child: Text(GuideCopy.backToSpread(lang)),
            ),
          TextButton(
            onPressed: () {
              settings.setAid(ReadingAid.guide, false);
              Navigator.pop(context);
            },
            child: Text(GuideCopy.turnOff(lang)),
          ),
        ],
      ),
    );
  }

  String _slotQuestion(int i) {
    final ctrl = widget.ctrl;
    if (ctrl.isCustomSpread) return ctrl.customSpread!.questions[i];
    if (ctrl.system == DivinationSystem.tarot &&
        ctrl.spreadType == SpreadType.three) {
      return intentionForSlot(i).question;
    }
    return GuideCopy.slotQuestion(widget.settings.language, role: ctrl.slots[i].role);
  }
}
