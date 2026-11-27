import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/services/oracle_voice_service.dart';
import '../../../core/services/spread_check_in_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';
import '../../../state/session_history_controller.dart';
import '../../../state/spread_session_snapshot.dart';
import '../../../state/voice_input_controller.dart';
import '../../share/share_card_payload.dart';
import '../../share/share_card_preview_sheet.dart';
import '../spread_history_pane.dart'
    show cardNamesSummaryForSnapshot, formatSessionTime, spreadTitleForSnapshot;
import 'voice_mic_button.dart';

/// Calm Zeigarnik reflection sheet: lets the reader look back at a past spread
/// 3, 7, or 14 days later and record what shifted in reality.
class SpreadCheckInSheet extends StatefulWidget {
  const SpreadCheckInSheet({
    super.key,
    required this.snapshot,
    this.now,
  });

  final SpreadSessionSnapshot snapshot;
  final DateTime? now;

  static Future<void> show(
    BuildContext context, {
    required SpreadSessionSnapshot snapshot,
    DateTime? now,
  }) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => SpreadCheckInSheet(snapshot: snapshot, now: now),
    );
  }

  @override
  State<SpreadCheckInSheet> createState() => _SpreadCheckInSheetState();
}

class _SpreadCheckInSheetState extends State<SpreadCheckInSheet> {
  late SpreadOutcome _selected =
      widget.snapshot.outcome ?? SpreadOutcome.unfolded;
  late final TextEditingController _note = TextEditingController(
    text: widget.snapshot.reflectionNote ?? '',
  );
  VoiceInputController? _providedVoice;
  VoiceInputController? _ownedVoice;

  VoiceInputController _resolveVoice(BuildContext context) {
    final provided = context.read<VoiceInputController?>();
    if (provided != null) {
      _providedVoice = provided;
      return provided;
    }
    return _ownedVoice ??= VoiceInputController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providedVoice = context.read<VoiceInputController?>();
  }

  @override
  void dispose() {
    final voice = _providedVoice ?? _ownedVoice;
    if (voice != null && voice.isOwnedBy(this)) {
      unawaited(voice.cancel(owner: this));
    }
    unawaited(_ownedVoice?.cancel());
    _ownedVoice?.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _toggleReflectionMic(AppLanguage lang) async {
    final voice = _resolveVoice(context);
    if (voice.isRecordingFor(this)) {
      final result = await voice.stopAndTranscribe(owner: this);
      if (!mounted) return;
      if (result.isSuccess) {
        insertVoiceTranscript(_note, result.text!);
      } else {
        showVoiceInputFeedback(context, result, language: lang);
      }
      return;
    }

    unawaited(context.read<OracleVoiceService?>()?.stop());
    final early = await voice.startRecording(
      owner: this,
      onAutoStop: () => unawaited(_toggleReflectionMic(lang)),
    );
    if (!mounted || early == null) return;
    showVoiceInputFeedback(context, early, language: lang);
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final history = context.read<SessionHistoryController>();
    final lang =
        context.read<AppSettingsController?>()?.language ?? AppStrings.current;
    await history.saveReflection(
      widget.snapshot.timestamp,
      outcome: _selected,
      note: _note.text,
      now: widget.now,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showTaroGlassSnackbar(
      context,
      message: _selected == SpreadOutcome.stillUnfolding
          ? AppStrings.t(lang, 'checkin.snoozedSnackbar', {
              'days': history.defaultCheckInDays,
            })
          : AppStrings.t(lang, 'checkin.savedSnackbar'),
      tone: TaroGlassSnackbarTone.success,
    );
  }

  Future<void> _dismiss() async {
    HapticFeedback.selectionClick();
    final history = context.read<SessionHistoryController>();
    await history.dismissCheckIn(widget.snapshot.timestamp);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        context.watch<AppSettingsController?>()?.language ?? AppStrings.current;
    final title = spreadTitleForSnapshot(widget.snapshot);
    final cards = cardNamesSummaryForSnapshot(widget.snapshot);
    final prompt = SpreadCheckInService.promptFor(
      widget.snapshot,
      lang,
      now: widget.now,
    );

    return TaroGlassSheet(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.t(lang, 'checkin.sheetTitle'),
                    style: AppTypography.label(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.dawn,
                    ),
                  ),
                ),
                if (widget.snapshot.cards.any((c) => !c.faceDown))
                  IconButton(
                    tooltip: AppStrings.t(lang, 'share.button'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: TaroColors.lavender,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ShareCardPreviewSheet.show(
                        context,
                        payload: ShareCardPayload.fromSnapshot(
                          snapshot: widget.snapshot,
                          lang: lang,
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              prompt,
              style: AppTypography.display(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: TaroColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // Original spread summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TaroColors.surface.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${title.toUpperCase()}  ·  ${formatSessionTime(widget.snapshot.timestamp)}',
                    style: AppTypography.label(
                      fontSize: 9,
                      letterSpacing: 0.9,
                      color: TaroColors.lavender,
                    ),
                  ),
                  if (widget.snapshot.readingQuestion.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.snapshot.readingQuestion.trim(),
                      style: AppTypography.body(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: TaroColors.textPrimary,
                      ),
                    ),
                  ],
                  if (cards.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cards,
                      style: AppTypography.body(
                        fontSize: 11.5,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final outcome in SpreadOutcome.values)
                  TaroGlassChip(
                    key: ValueKey('checkin-outcome-${outcome.name}'),
                    label: SpreadCheckInService.outcomeLabel(outcome, lang),
                    selected: _selected == outcome,
                    compact: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = outcome);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('checkin-note-field'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              style: AppTypography.body(
                fontSize: 14,
                color: TaroColors.textPrimary,
              ),
              cursorColor: TaroColors.lavender,
              decoration: InputDecoration(
                hintText: AppStrings.t(lang, 'checkin.noteHint'),
                hintStyle: AppTypography.body(
                  fontSize: 13,
                  color: TaroColors.textSecondary.withValues(alpha: 0.72),
                ),
                suffixIcon: VoiceMicButton(
                  key: const ValueKey('checkin-note-mic'),
                  controller: context.watch<VoiceInputController?>() ??
                      (_ownedVoice ??= VoiceInputController()),
                  owner: this,
                  variant: VoiceMicButtonVariant.inline,
                  language: lang,
                  onTap: () => _toggleReflectionMic(lang),
                ),
                filled: true,
                fillColor: TaroColors.surface.withValues(alpha: 0.72),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: TaroColors.lavender),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  key: const ValueKey('checkin-dismiss-button'),
                  onPressed: _dismiss,
                  child: Text(
                    AppStrings.t(lang, 'checkin.dismiss'),
                    style: AppTypography.label(
                      fontSize: 10.5,
                      color: TaroColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TaroGlassLayer(
                    useBackdropGroup: false,
                    child: TaroGlassButton(
                      key: const ValueKey('checkin-save-button'),
                      label: AppStrings.t(lang, 'checkin.save'),
                      variant: TaroGlassButtonVariant.primary,
                      onPressed: _save,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
