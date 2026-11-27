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
import 'guide_bubble.dart';
import 'wisp_mascot.dart';
import 'wisp_mood.dart';

/// A lavender outline on the slot (or deck) Wisp currently recommends.
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

/// Wisp's floating speech bubble rendered under the Digital Table (both Step 1
/// spread selection and Step 2 active table). Reads the single most relevant
/// hint from [GuidedReadingController] (null whenever guidance is off) and
/// opens Wisp's detail sheet on tap.
class ReadingGuide extends StatelessWidget {
  const ReadingGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = context.watch<GuidedReadingController>();
    final lang = context.watch<AppSettingsController>().language;
    final hint = guide.currentHint;
    if (hint == null) return const SizedBox.shrink();

    final mood = wispMoodFor(hint, tension: guide.hasTension);

    return GuideBubble(
      hint: hint,
      mood: mood,
      lang: lang,
      onBackToSpread: hint.eventType == GuideEventType.relationshipTapped
          ? () {
              HapticFeedback.selectionClick();
              guide.clearRelationship();
            }
          : null,
      onOpenDetail: () {
        // Opening the sheet IS reading the lesson: record it so Wisp never
        // repeats what this reader already knows. The captured hint keeps its
        // lesson for the sheet being opened right now.
        guide.learnCurrentLesson();
        showTaroGlassSheet<void>(
          context: context,
          builder: (sheet) => _GuideDetailSheet(
            hint: hint,
            mood: mood,
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
    required this.mood,
    required this.ctrl,
    required this.settings,
  });

  final GuideHint hint;
  final WispMood mood;
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
    final isChooseStep = hint.eventType == GuideEventType.spreadSelected;
    final accent = widget.mood == WispMood.empathetic
        ? TaroColors.dawn
        : TaroColors.lavender;

    return TaroGlassSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wisp speech-bubble header inside the sheet.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WispMascot(
                size: 62,
                mood: widget.mood,
                glowColor: accent,
                gazeTarget: const Offset(0.3, 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GuideCopy.mascotName(lang),
                      style: AppTypography.label(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hint.title,
                      style: AppTypography.display(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: TaroColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Wisp's immediate guidance in a subtle tinted speech card.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.09),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint.body,
                  style: AppTypography.body(
                    fontSize: 13.5,
                    color: TaroColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                if (!isChooseStep && _focus.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _focus,
                    style: AppTypography.body(
                      fontSize: 12.5,
                      color: TaroColors.textSecondary,
                      height: 1.48,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (hint.eventType == GuideEventType.relationshipTapped) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: TaroColors.lavender,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  context.read<GuidedReadingController>().clearRelationship();
                  Navigator.pop(context);
                },
                label: Text(
                  GuideCopy.backToSpread(lang),
                  style: AppTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TaroColors.lavender,
                  ),
                ),
              ),
            ),
          ],

          if (!isChooseStep && i != null && i < ctrl.spreadCardCount) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionPosition(lang),
              body: _slotQuestion(i),
            ),
          ],

          // The conceptual lesson rides the hint: it disappears once read.
          if (hint.lesson != null) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionLesson(lang),
              body: hint.lesson!,
              highlight: true,
            ),
          ],

          if (!isChooseStep &&
              ctrl.system == DivinationSystem.tarot &&
              ctrl.faceUpCount > 0) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionMethod(lang),
              body: GuideCopy.elementNote(lang),
            ),
          ] else if (ctrl.system != DivinationSystem.tarot) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionMethod(lang),
              body: GuideCopy.methodNote(lang, ctrl.system),
            ),
          ],

          if (!isChooseStep &&
              ctrl.relationships.any((r) => r.influence != null)) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionLink(lang),
              body: GuideCopy.goldenDawnNote(lang),
              extra: hint.eventType != GuideEventType.relationshipTapped &&
                      ctrl.relationships.isNotEmpty
                  ? ctrl.relationships.first.localizedExplanation(lang)
                  : null,
            ),
          ] else if (!isChooseStep &&
              hint.eventType != GuideEventType.relationshipTapped &&
              ctrl.relationships.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SheetSection(
              label: GuideCopy.sectionLink(lang),
              body: ctrl.relationships.first.localizedExplanation(lang),
            ),
          ],

          if (!isChooseStep && ctrl.faceUpCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: TaroColors.surface.withValues(alpha: 0.6),
                border: Border.all(
                  color: TaroColors.lavender.withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Mimicry where it is clearly visible: thinking while
                      // composing, warm smile once the answer arrives.
                      WispMascot(
                        key: const ValueKey('guide-oracle-mascot'),
                        size: 46,
                        mood: _asking
                            ? WispMood.thinking
                            : (_answer != null
                                  ? WispMood.greeting
                                  : WispMood.curious),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('guide-ask-oracle'),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: TaroColors.lavender,
                          ),
                          onPressed: _asking || _answer != null
                              ? null
                              : _askOracle,
                          child: Text(
                            _asking
                                ? GuideCopy.oracleThinking(lang)
                                : GuideCopy.askOracle(lang),
                            style: AppTypography.body(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _asking || _answer != null
                                  ? TaroColors.textSecondary
                                  : TaroColors.lavender,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_answer != null) ...[
                    const SizedBox(height: 8),
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
              ),
            ),
          ],

          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                settings.setAid(ReadingAid.guide, false);
                Navigator.pop(context);
              },
              child: Text(
                GuideCopy.turnOff(lang),
                style: AppTypography.body(
                  fontSize: 13,
                  color: TaroColors.textSecondary,
                ),
              ),
            ),
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
    return GuideCopy.slotQuestion(
      widget.settings.language,
      role: ctrl.slots[i].role,
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.label,
    required this.body,
    this.extra,
    this.highlight = false,
  });

  final String label;
  final String body;
  final String? extra;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: highlight ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: TaroColors.lavender.withValues(alpha: 0.08),
              border: Border.all(
                color: TaroColors.lavender.withValues(alpha: 0.22),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: TaroColors.lavender,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: AppTypography.body(
              fontSize: 13,
              color: TaroColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 6),
            Text(
              extra!,
              style: AppTypography.body(
                fontSize: 12.5,
                color: TaroColors.textSecondary,
                height: 1.48,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
