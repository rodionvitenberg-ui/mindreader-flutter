import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/custom_spread.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/spread_controller.dart';
import 'shuffle_physics.dart';
import 'spread_blueprint_grid.dart';

/// Builder bottom sheet for "Свой расклад" / "Custom Spread":
/// * User writes or dictates questions (1 question = 1 position, 1..12).
/// * User can edit, reorder, or delete any question before starting.
/// * Position count is strictly determined by the questions list, with a live
///   row-layout miniature preview.
class CustomSpreadSheet extends StatefulWidget {
  const CustomSpreadSheet({
    super.key,
    this.launchContext = SpreadLaunchContext.digitalTable,
    this.onSpreadSelected,
  });

  final SpreadLaunchContext launchContext;
  final void Function(int cardCount)? onSpreadSelected;

  static Future<void> show(
    BuildContext context, {
    SpreadLaunchContext launchContext = SpreadLaunchContext.digitalTable,
    void Function(int cardCount)? onSpreadSelected,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => CustomSpreadSheet(
        launchContext: launchContext,
        onSpreadSelected: onSpreadSelected,
      ),
    );
  }

  @override
  State<CustomSpreadSheet> createState() => _CustomSpreadSheetState();
}

class _QuestionEntry {
  _QuestionEntry({required this.id, required String text})
      : controller = TextEditingController(text: text);

  final int id;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _CustomSpreadSheetState extends State<CustomSpreadSheet>
    with WidgetsBindingObserver {
  late final TextEditingController _nameController;
  final TextEditingController _composerController = TextEditingController();
  final List<_QuestionEntry> _entries = [];
  int _nextId = 0;

  final SpeechToText _speech = SpeechToText();
  int _speechRequest = 0;
  bool _dictating = false;
  bool _stopping = false;
  Completer<void>? _speechDone;
  SpeechStatusListener? _previousStatus;
  SpeechErrorListener? _previousError;
  SpeechStatusListener? _statusListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final existing = context.read<SpreadController>().customSpread;
    _nameController = TextEditingController(text: existing?.name ?? '');
    if (existing != null) {
      for (final q in existing.questions) {
        _entries.add(_QuestionEntry(id: _nextId++, text: q));
      }
    }
  }

  @override
  void dispose() {
    _cancelDictation();
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _composerController.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_dictating &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      setState(_cancelDictation);
    }
  }

  bool _isCurrentSpeech(int request) =>
      mounted && _dictating && request == _speechRequest;

  void _releaseDictation() {
    if (_statusListener != null &&
        identical(_speech.statusListener, _statusListener)) {
      _speech.statusListener = _previousStatus;
      _speech.errorListener = _previousError;
    }
    _statusListener = null;
    _speechDone?.complete();
    _speechDone = null;
    _stopping = false;
    _dictating = false;
    _speechRequest++;
  }

  void _cancelDictation() {
    if (!_dictating) return;
    final ownsMic =
        _statusListener != null &&
        identical(_speech.statusListener, _statusListener);
    _releaseDictation();
    if (ownsMic) unawaited(_speech.cancel().catchError((Object _) {}));
  }

  void _finishDictation({bool unavailable = false, AppLanguage? lang}) {
    if (!mounted) return;
    setState(_releaseDictation);
    if (unavailable) {
      final resolvedLang =
          lang ?? context.read<AppSettingsController>().language;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(resolvedLang, 'table.noDictation')),
        ),
      );
    }
  }

  Future<void> _stopDictation() async {
    final done = _speechDone;
    if (done == null) return;
    if (_statusListener == null) {
      setState(_cancelDictation);
      return;
    }
    final request = _speechRequest;
    if (!_stopping) {
      _stopping = true;
      try {
        await _speech.stop();
      } catch (_) {
        if (_isCurrentSpeech(request)) _finishDictation(unavailable: true);
      }
    }
    await done.future.timeout(
      SpeechToText.defaultFinalTimeout + const Duration(milliseconds: 300),
      onTimeout: () {
        if (_isCurrentSpeech(request)) _finishDictation();
      },
    );
  }

  Future<void> _toggleDictation(AppLanguage lang) async {
    if (_dictating) {
      await _stopDictation();
      return;
    }
    if (_entries.length >= CustomSpreadConfig.maxPositions) return;
    final request = ++_speechRequest;
    final base = _composerController.value;
    final selection = base.selection.isValid
        ? base.selection
        : TextSelection.collapsed(offset: base.text.length);
    _speechDone = Completer<void>();
    setState(() => _dictating = true);
    try {
      if (_speech.isListening || !await _speech.initialize()) {
        if (_isCurrentSpeech(request)) {
          _finishDictation(unavailable: true, lang: lang);
        }
        return;
      }
      if (!_isCurrentSpeech(request)) return;
      _previousStatus = _speech.statusListener;
      _previousError = _speech.errorListener;
      _statusListener = (status) {
        if (_isCurrentSpeech(request) && status == SpeechToText.doneStatus) {
          _finishDictation();
        }
      };
      _speech.statusListener = _statusListener;
      _speech.errorListener = (_) {
        if (_isCurrentSpeech(request)) {
          _finishDictation(unavailable: true, lang: lang);
        }
      };
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: lang == AppLanguage.ru ? 'ru_RU' : 'en_US',
        ),
        onResult: (result) {
          if (!_isCurrentSpeech(request)) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            final before = base.text.substring(0, selection.start);
            final after = base.text.substring(selection.end);
            final prefix = before.isEmpty || before.trimRight() != before
                ? before
                : '$before ';
            final suffix = after.isEmpty || after.trimLeft() != after
                ? after
                : ' $after';
            final text = '$prefix$words$suffix';
            setState(() {
              _composerController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(
                  offset: prefix.length + words.length,
                ),
              );
            });
          }
          if (result.finalResult) _finishDictation();
        },
      );
    } catch (_) {
      if (_isCurrentSpeech(request)) {
        _finishDictation(unavailable: true, lang: lang);
      }
    }
  }

  /// Splits non-empty lines from the composer into positions (up to 12).
  void _addFromComposer() {
    if (_dictating) _cancelDictation();
    final lines = _composerController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final remaining = CustomSpreadConfig.maxPositions - _entries.length;
    if (remaining <= 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      for (final line in lines.take(remaining)) {
        _entries.add(_QuestionEntry(id: _nextId++, text: line));
      }
      _composerController.clear();
    });
  }

  void _removeAt(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final removed = _entries.removeAt(index);
      removed.dispose();
    });
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _entries.length || from == to) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _entries.removeAt(from);
      _entries.insert(to, item);
    });
  }

  List<String> _collectQuestions() {
    final out = <String>[];
    for (final entry in _entries) {
      final t = entry.controller.text.trim();
      if (t.isNotEmpty) {
        out.add(t);
        if (out.length >= CustomSpreadConfig.maxPositions) return out;
      }
    }
    final pendingLines = _composerController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in pendingLines) {
      if (out.length >= CustomSpreadConfig.maxPositions) break;
      out.add(line);
    }
    return out;
  }

  Future<void> _openTable(AppLanguage lang) async {
    if (_dictating) await _stopDictation();
    if (!mounted) return;
    final questions = _collectQuestions();
    if (questions.isEmpty) return;
    HapticFeedback.mediumImpact();
    final ctrl = context.read<SpreadController>();
    final config = CustomSpreadConfig.fromQuestions(
      questions: questions,
      name: _nameController.text,
      defaultName: AppStrings.t(lang, 'spread.custom'),
    );
    ctrl.setCustomSpread(config);
    Navigator.of(context).pop();
    if (widget.launchContext == SpreadLaunchContext.guidedSpread) {
      widget.onSpreadSelected?.call(config.cardCount);
    } else {
      ctrl.activateSpread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final system = context.watch<SpreadController>().system;
    final isRune = system == DivinationSystem.runes;
    final collected = _collectQuestions();
    final effectiveCount = collected.length;
    final atLimit = _entries.length >= CustomSpreadConfig.maxPositions;
    final geometry = spreadBoardGeometryForCustom(
      effectiveCount == 0 ? 1 : effectiveCount,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: TaroGlassSheet(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.t(lang, 'spread.custom'),
                        style: AppTypography.display(
                          fontSize: 26,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$effectiveCount / ${CustomSpreadConfig.maxPositions}',
                        key: const ValueKey('custom-position-counter'),
                        style: AppTypography.label(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: TaroColors.lavender,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 68,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TaroColors.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: TaroColors.mist.withValues(
                        alpha: TaroOpacity.border,
                      ),
                    ),
                  ),
                  child: CustomPaint(
                    painter: SpreadMiniaturePainter(
                      geometry: geometry,
                      isRune: isRune,
                      active: effectiveCount > 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('custom-spread-name-field'),
              controller: _nameController,
              textInputAction: TextInputAction.next,
              cursorColor: TaroColors.lavender,
              style: const TextStyle(
                color: TaroColors.textPrimary,
                fontSize: 13.5,
              ),
              decoration: _fieldDecoration(
                AppStrings.t(lang, 'spread.customTitleLabel'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppStrings.t(lang, 'spread.customQuestionsLabel'),
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.9,
                color: TaroColors.lavender,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('custom-question-input'),
                    controller: _composerController,
                    enabled: !atLimit,
                    textInputAction: TextInputAction.done,
                    cursorColor: TaroColors.lavender,
                    onChanged: (_) {
                      if (_dictating) setState(_cancelDictation);
                      setState(() {});
                    },
                    onSubmitted: (_) => _addFromComposer(),
                    style: const TextStyle(
                      color: TaroColors.textPrimary,
                      fontSize: 13.5,
                    ),
                    decoration: _fieldDecoration(
                      atLimit
                          ? AppStrings.t(lang, 'spread.customLimitReached')
                          : AppStrings.t(lang, 'spread.customQuestionInput'),
                      suffixIcon: IconButton(
                        key: const ValueKey('custom-question-mic'),
                        tooltip: AppStrings.t(
                          lang,
                          _dictating ? 'table.stopDictation' : 'table.dictate',
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            atLimit ? null : () => _toggleDictation(lang),
                        icon: Icon(
                          _dictating
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none,
                          size: 19,
                          color: atLimit
                              ? TaroColors.textSecondary
                              : (_dictating
                                  ? TaroColors.rose
                                  : TaroColors.lavender),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('custom-question-add'),
                  tooltip: AppStrings.t(lang, 'spread.customAddQuestion'),
                  onPressed:
                      atLimit || _composerController.text.trim().isEmpty
                      ? null
                      : _addFromComposer,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        atLimit || _composerController.text.trim().isEmpty
                        ? TaroColors.background.withValues(alpha: 0.45)
                        : TaroColors.lavender.withValues(alpha: 0.20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            atLimit ||
                                _composerController.text.trim().isEmpty
                            ? TaroColors.mist.withValues(
                                alpha: TaroOpacity.border,
                              )
                            : TaroColors.lavender.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.add_rounded,
                    color:
                        atLimit || _composerController.text.trim().isEmpty
                        ? TaroColors.textSecondary
                        : TaroColors.lavender,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  AppStrings.t(lang, 'spread.customEmptyHint'),
                  style: AppTypography.body(
                    fontSize: 12,
                    height: 1.4,
                    color: TaroColors.textSecondary,
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _entries.length; i++) ...[
                    _QuestionRow(
                      key: ValueKey('custom-question-item-${_entries[i].id}'),
                      index: i,
                      total: _entries.length,
                      controller: _entries[i].controller,
                      lang: lang,
                      decoration: _fieldDecoration('${i + 1}'),
                      onChanged: () => setState(() {}),
                      onMoveUp: i > 0 ? () => _move(i, i - 1) : null,
                      onMoveDown:
                          i < _entries.length - 1 ? () => _move(i, i + 1) : null,
                      onDelete: () => _removeAt(i),
                    ),
                    if (i < _entries.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            TaroGlassButton(
              key: const ValueKey('custom-spread-open-button'),
              label: effectiveCount > 0
                  ? '${AppStrings.t(lang, 'spread.customOpenTable')} ($effectiveCount)'
                  : AppStrings.t(lang, 'spread.customOpenTable'),
              variant: TaroGlassButtonVariant.primary,
              onPressed: effectiveCount > 0 ? () => _openTable(lang) : null,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
      ),
    );
    return InputDecoration(
      filled: true,
      fillColor: TaroColors.surface.withValues(alpha: 0.72),
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(
        color: TaroColors.textSecondary,
        fontSize: 12.5,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: TaroColors.lavender),
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 38),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    super.key,
    required this.index,
    required this.total,
    required this.controller,
    required this.lang,
    required this.decoration,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final int index;
  final int total;
  final TextEditingController controller;
  final AppLanguage lang;
  final InputDecoration decoration;
  final VoidCallback onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TaroColors.lavender.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${index + 1}',
            style: AppTypography.label(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: ValueKey('custom-question-edit-$index'),
            controller: controller,
            onChanged: (_) => onChanged(),
            cursorColor: TaroColors.lavender,
            style: const TextStyle(color: TaroColors.textPrimary, fontSize: 13),
            decoration: decoration,
          ),
        ),
        if (total > 1) ...[
          IconButton(
            key: ValueKey('custom-question-up-$index'),
            tooltip: AppStrings.t(lang, 'spread.customMoveUp'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
            onPressed: onMoveUp,
            icon: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: onMoveUp != null
                  ? TaroColors.textSecondary
                  : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
          IconButton(
            key: ValueKey('custom-question-down-$index'),
            tooltip: AppStrings.t(lang, 'spread.customMoveDown'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
            onPressed: onMoveDown,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: onMoveDown != null
                  ? TaroColors.textSecondary
                  : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
        ],
        IconButton(
          key: ValueKey('custom-question-delete-$index'),
          tooltip: AppStrings.t(lang, 'spread.customDelete'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
          onPressed: onDelete,
          icon: const Icon(
            Icons.close_rounded,
            size: 17,
            color: TaroColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
