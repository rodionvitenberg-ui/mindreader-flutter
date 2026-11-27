import 'dart:math';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/micro_learning_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/training_controller.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import '../digital_table/widgets/wisp_mascot.dart';
import '../digital_table/widgets/wisp_mood.dart';

/// Offline 2-minute micro-learning experience on the forest table
/// (Labyrinthos-style, zero API cost): card meanings, elements, and 2-card pairs.
class MicroLearningScreen extends StatefulWidget {
  const MicroLearningScreen({
    super.key,
    this.initialSystem = DivinationSystem.tarot,
    this.initialMode = DrillMode.mixed,
    this.tarotPairsOverride,
    this.randomSeed,
  });

  final DivinationSystem initialSystem;
  final DrillMode initialMode;
  final List<TarotPairDrill>? tarotPairsOverride;
  final int? randomSeed;

  static Future<void> open(
    BuildContext context, {
    DivinationSystem system = DivinationSystem.tarot,
    DrillMode mode = DrillMode.mixed,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MicroLearningScreen(
          initialSystem: system,
          initialMode: mode,
        ),
      ),
    );
  }

  @override
  State<MicroLearningScreen> createState() => _MicroLearningScreenState();
}

class _MicroLearningScreenState extends State<MicroLearningScreen> {
  late DivinationSystem _system = widget.initialSystem;
  late DrillMode _mode = widget.initialMode;
  List<TarotPairDrill> _tarotPairs = const [];
  List<MicroLearningQuestion> _questions = const [];
  int _index = 0;
  int? _selectedOption;
  int _correctCount = 0;
  final Set<String> _masteredThisSession = <String>{};
  bool _completed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pairs =
        widget.tarotPairsOverride ??
        await MicroLearningService.loadTarotPairs();
    if (!mounted) return;
    _tarotPairs = pairs;
    _startFreshSession();
  }

  void _startFreshSession() {
    final lang =
        context.read<AppSettingsController?>()?.language ?? AppStrings.current;
    setState(() {
      _questions = MicroLearningService.generateSession(
        system: _system,
        mode: _mode,
        lang: lang,
        tarotPairs: _tarotPairs,
        rng: widget.randomSeed != null ? Random(widget.randomSeed) : null,
      );
      _index = 0;
      _selectedOption = null;
      _correctCount = 0;
      _masteredThisSession.clear();
      _completed = false;
      _ready = true;
    });
  }

  void _selectOption(int optionIndex) {
    if (_selectedOption != null || _completed) return;
    final q = _questions[_index];
    final right = optionIndex == q.correctIndex;
    if (right) {
      HapticFeedback.mediumImpact();
      _correctCount++;
      _masteredThisSession.add(q.primaryCardKey);
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() => _selectedOption = optionIndex);
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index + 1 >= _questions.length) {
      context.read<TrainingController?>()?.recordSession(
        correct: _correctCount,
        total: _questions.length,
        newlyMasteredKeys: _masteredThisSession,
      );
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final training = context.watch<TrainingController?>();

    return Stack(
      children: [
        const Positioned.fill(
          child: TaroDuskBackground(imageAsset: TaroBackgroundAssets.forest),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      BackButton(
                        color: TaroColors.lavender,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          AppStrings.t(lang, 'training.title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: TaroColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_ready && !_completed && _questions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: TaroColors.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: TaroColors.lavender.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${_index + 1} / ${_questions.length}',
                            style: AppTypography.label(
                              fontSize: 10,
                              letterSpacing: 0.9,
                              color: TaroColors.lavender,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // System + Mode selectors
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final sys in DivinationSystem.values) ...[
                          TaroGlassChip(
                            key: ValueKey('training-system-${sys.name}'),
                            label: sys.label,
                            selected: _system == sys,
                            compact: true,
                            onTap: () {
                              if (_system == sys) return;
                              HapticFeedback.selectionClick();
                              _system = sys;
                              _startFreshSession();
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          width: 1,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: TaroColors.mist.withValues(alpha: 0.25),
                        ),
                        for (final m in DrillMode.values) ...[
                          if (!(m == DrillMode.elementMatch &&
                              _system == DivinationSystem.lenormand)) ...[
                            TaroGlassChip(
                              key: ValueKey('training-mode-${m.name}'),
                              label: AppStrings.t(lang, 'training.mode.${m.name}'),
                              selected: _mode == m,
                              compact: true,
                              onTap: () {
                                if (_mode == m) return;
                                HapticFeedback.selectionClick();
                                _mode = m;
                                _startFreshSession();
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: !_ready
                      ? const Center(
                          child: TaroGlassProgress(linear: false, size: 24),
                        )
                      : _completed
                      ? _CompletionView(
                          language: lang,
                          correct: _correctCount,
                          total: _questions.length,
                          mastered: training?.masteredCount ??
                              _masteredThisSession.length,
                          onAgain: _startFreshSession,
                          onDone: () => Navigator.of(context).pop(),
                        )
                      : _QuestionStage(
                          question: _questions[_index],
                          language: lang,
                          selectedOption: _selectedOption,
                          isLast: _index + 1 == _questions.length,
                          onSelect: _selectOption,
                          onNext: _next,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionStage extends StatelessWidget {
  const _QuestionStage({
    required this.question,
    required this.language,
    required this.selectedOption,
    required this.isLast,
    required this.onSelect,
    required this.onNext,
  });

  final MicroLearningQuestion question;
  final AppLanguage language;
  final int? selectedOption;
  final bool isLast;
  final ValueChanged<int> onSelect;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final answered = selectedOption != null;
    final isRight = answered && selectedOption == question.correctIndex;
    final mood = !answered
        ? WispMood.curious
        : (isRight ? WispMood.greeting : WispMood.empathetic);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual cards on the table
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < question.cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  _TrainingCardArt(
                    card: question.cards[i],
                    isReversed: question.reversedFlags[i],
                    compact: question.cards.length > 1,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              for (var i = 0; i < question.cards.length; i++)
                question.reversedFlags[i]
                    ? '${question.cards[i].name} ↺'
                    : question.cards[i].name,
            ].join('  +  '),
            textAlign: TextAlign.center,
            style: AppTypography.display(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Wisp prompt bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TaroColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: TaroColors.lavender.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                WispMascot(size: 30, mood: mood),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    answered ? question.explanation : question.prompt,
                    style: AppTypography.body(
                      fontSize: 13,
                      height: 1.35,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 4 Answer options
          for (var i = 0; i < question.options.length; i++) ...[
            _AnswerOptionTile(
              key: ValueKey('training-option-$i'),
              label: question.options[i],
              element: question.elementOptions != null
                  ? question.elementOptions![i]
                  : null,
              state: !answered
                  ? _OptionState.idle
                  : i == question.correctIndex
                  ? _OptionState.correct
                  : i == selectedOption
                  ? _OptionState.wrong
                  : _OptionState.muted,
              onTap: answered ? null : () => onSelect(i),
            ),
            const SizedBox(height: 8),
          ],
          if (answered) ...[
            const SizedBox(height: 6),
            TaroGlassLayer(
              useBackdropGroup: false,
              child: TaroGlassButton(
                key: const ValueKey('training-next-button'),
                label: AppStrings.t(
                  language,
                  isLast ? 'training.finish' : 'training.next',
                ),
                variant: TaroGlassButtonVariant.primary,
                onPressed: onNext,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, muted }

class _AnswerOptionTile extends StatelessWidget {
  const _AnswerOptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.element,
  });

  final String label;
  final Element? element;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (state) {
      _OptionState.correct => TaroColors.emerald,
      _OptionState.wrong => TaroColors.conflictRose,
      _OptionState.idle => TaroColors.mist.withValues(alpha: 0.28),
      _OptionState.muted => TaroColors.mist.withValues(alpha: 0.14),
    };
    final fillColor = switch (state) {
      _OptionState.correct => TaroColors.emerald.withValues(alpha: 0.18),
      _OptionState.wrong => TaroColors.conflictRose.withValues(alpha: 0.18),
      _OptionState.idle => TaroColors.surface.withValues(alpha: 0.72),
      _OptionState.muted => TaroColors.surface.withValues(alpha: 0.36),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (element != null) ...[
              ElementIcon(element!, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(
                  fontSize: 13.5,
                  height: 1.35,
                  color: state == _OptionState.muted
                      ? TaroColors.textSecondary.withValues(alpha: 0.65)
                      : TaroColors.textPrimary,
                ),
              ),
            ),
            if (state == _OptionState.correct)
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: TaroColors.emerald,
              )
            else if (state == _OptionState.wrong)
              const Icon(
                Icons.cancel_outlined,
                size: 18,
                color: TaroColors.conflictRose,
              ),
          ],
        ),
      ),
    );
  }
}

class _TrainingCardArt extends StatelessWidget {
  const _TrainingCardArt({
    required this.card,
    required this.isReversed,
    required this.compact,
  });

  final DivinationCard card;
  final bool isReversed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = compact ? 104.0 : 124.0;
    final h = w * 360 / 220;
    return switch (card.system) {
      DivinationSystem.tarot => TarotCard3DWidget(
        card: (card as TarotDivinationCard).card,
        isReversed: isReversed,
        state: SlotState.faceUp,
        width: w,
        height: h,
        tilt: false,
        interactive: false,
      ),
      DivinationSystem.lenormand => LenormandCard3DWidget(
        card: (card as LenormandDivinationCard).card,
        isReversed: false,
        state: SlotState.faceUp,
        width: w,
        height: h,
        tilt: false,
        interactive: false,
      ),
      DivinationSystem.runes => SizedBox(
        width: w,
        height: w * 1.15,
        child: RuneStoneView(
          stone: (card as RuneDivinationCard).stone,
          pack: context.watch<DeckPackController>().activeRunePack,
          faceUp: true,
          merkstave: isReversed,
          ignite: 1.0,
          seed: card.id + 7,
        ),
      ),
    };
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.language,
    required this.correct,
    required this.total,
    required this.mastered,
    required this.onAgain,
    required this.onDone,
  });

  final AppLanguage language;
  final int correct;
  final int total;
  final int mastered;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TaroGlassPanel(
          key: const ValueKey('training-completion-card'),
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WispMascot(size: 64, mood: WispMood.greeting),
              const SizedBox(height: 14),
              Text(
                AppStrings.t(language, 'training.completeTitle'),
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: TaroColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t(language, 'training.scoreLine', {
                  'correct': correct,
                  'total': total,
                  'mastered': mastered,
                }),
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  fontSize: 14,
                  color: TaroColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TaroGlassLayer(
                  useBackdropGroup: false,
                  child: TaroGlassButton(
                    key: const ValueKey('training-again-button'),
                    label: AppStrings.t(language, 'training.again'),
                    variant: TaroGlassButtonVariant.primary,
                    onPressed: onAgain,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const ValueKey('training-done-button'),
                onPressed: onDone,
                child: Text(
                  AppStrings.t(language, 'training.done'),
                  style: AppTypography.label(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: TaroColors.lavender,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
