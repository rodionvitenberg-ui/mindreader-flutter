import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/spread_controller.dart';

/// Glassmorphic bottom sheet with two faces:
/// * `cardIndex != null` — the CARDS INSPECTOR SHEET for a tapped face-up
///   card: title + orientation, element badge, spread slot role, the
///   card's meaning & keywords, 3 single-select resonance pills, and a
///   compact personal-note input (text + mic) that auto-saves into
///   `slot.userContext`. NO reading-context chips, NO synthesize button.
/// * `cardIndex == null` — the classic Live Reading sheet (context chips,
///   streaming synthesis, local-first saving).
class ReadingBottomSheet extends StatefulWidget {
  const ReadingBottomSheet({super.key, this.cardIndex});

  final int? cardIndex; // set when opened from a face-up card tap

  static Future<void> show(BuildContext context, {int? cardIndex}) {
    return showTaroGlassSheet<void>(
      context: context,
      builder: (_) => ReadingBottomSheet(cardIndex: cardIndex),
    );
  }

  @override
  State<ReadingBottomSheet> createState() => _ReadingBottomSheetState();
}

class _ReadingBottomSheetState extends State<ReadingBottomSheet> {
  static const _contextChips = [
    'Love & Relationships',
    'Inner Crisis',
    'Career & Path',
    'Custom Question',
  ];

  /// The 3 mutually exclusive resonance pills of the Card Inspector.
  static const _resonancePills = ['Resonates', 'Challenging', 'Unclear'];

  String? _contextChip;
  String? _resonance;
  String _fullText = '';
  String _revealed = '';
  bool _synthesizing = false;
  bool _saved = false;
  Timer? _timer;

  /// The personal note for the tapped card — pre-filled from
  /// `slot.userContext` and auto-saved back on every change.
  late final TextEditingController _note;
  SpeechToText? _speech;
  bool _micListening = false;

  DealtCardSlot? _slotOf(SpreadController ctrl) {
    final i = widget.cardIndex;
    if (i == null || i < 0 || i >= ctrl.slots.length) return null;
    return ctrl.slots[i];
  }

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<SpreadController>();
    _note = TextEditingController(text: _slotOf(ctrl)?.userContext ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech?.stop();
    _note.dispose();
    super.dispose();
  }

  /// Auto-save: the typed/spoken note lands in `slot.userContext` as the
  /// reader types (blank input clears it).
  void _saveNote(String text) {
    final ctrl = context.read<SpreadController>();
    final i = widget.cardIndex;
    if (i == null) return;
    final trimmed = text.trim();
    ctrl.updateSlotUserContext(i, text: trimmed.isEmpty ? null : trimmed);
  }

  Future<void> _toggleNoteMic() async {
    if (_micListening) {
      await _speech?.stop();
      setState(() => _micListening = false);
      return;
    }
    _speech ??= SpeechToText();
    bool ok;
    try {
      ok = await _speech!.initialize();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is not available here — type your note instead.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _micListening = true);
    await _speech!.listen(
      onResult: (r) {
        _note.text = r.recognizedWords;
        _note.selection = TextSelection.collapsed(offset: _note.text.length);
        _saveNote(_note.text);
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
      ),
    );
    if (mounted) setState(() => _micListening = false);
  }

  void _pickContext(String chip) {
    HapticFeedback.selectionClick();
    setState(() => _contextChip = _contextChip == chip ? null : chip);
  }

  Future<void> _startSynthesis() async {
    final ctrl = context.read<SpreadController>();
    _timer?.cancel();
    setState(() {
      _fullText = '';
      _revealed = '';
      _synthesizing = true;
      _saved = false;
    });
    // Dual AI pipeline: RTX 3080 worker → Gemini Flash → local engine.
    // Never throws — the local synthesis is the guaranteed fallback.
    final text = await OracleSynthesisService().synthesize(
      slots: ctrl.slots,
      type: ctrl.spreadType,
      contextChip: _contextChip,
    );
    if (!mounted) return;
    setState(() => _fullText = text);
    HapticFeedback.mediumImpact();
    // Typewriter reveal: streaming feel for both remote and local text.
    _timer = Timer.periodic(const Duration(milliseconds: 14), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _revealed = _fullText.substring(
          0,
          math.min(_revealed.length + 3, _fullText.length),
        );
        if (_revealed.length >= _fullText.length) {
          t.cancel();
          _synthesizing = false;
        }
      });
    });
  }

  Future<void> _save() async {
    final ctrl = context.read<SpreadController>();
    final storage = LocalStorageService();
    await storage.saveSpread(
      ctrl.buildHistoryEntry(
        synthesis: _fullText,
        contextChip: _contextChip,
      ),
    );
    // Ritual streak: today counts as a day with a completed reading.
    try {
      await storage.recordReadingDay();
    } catch (_) {
      // Streak bookkeeping is best-effort.
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spread saved on this device')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final slot = _slotOf(ctrl);
    final card = slot?.card;
    final canSynthesize = ctrl.faceUpCount > 0;

    return TaroGlassSheet(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slot != null && card != null) ...[
            // ---- Card Inspector Sheet (tapped face-up card) ----
            _CardInspectorHeader(slot: slot, card: card),
            const SizedBox(height: 18),
            Text(
              slot.isReversed && card.reversed != null
                  ? 'REVERSED MEANING'
                  : 'UPRIGHT MEANING',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meaningFor(slot),
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: TaroColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              card.keywords.map((k) => k.toUpperCase()).join(' · '),
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.8,
                color: TaroColors.lavender,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'RESONANCE',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pill in _resonancePills)
                  TaroGlassChip(
                    label: pill,
                    selected: _resonance == pill,
                    onTap: () => setState(
                      () => _resonance = _resonance == pill ? null : pill,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'PERSONAL NOTE',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _CardNoteField(
              controller: _note,
              micListening: _micListening,
              onChanged: _saveNote,
              onMicTap: _toggleNoteMic,
            ),
          ] else ...[
            Text(
              'Live Reading',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              ctrl.spreadType.label.toUpperCase(),
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'READING CONTEXT',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 1.1,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in _contextChips)
                  TaroGlassChip(
                    label: chip,
                    selected: _contextChip == chip,
                    onTap: () => _pickContext(chip),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (!canSynthesize)
              TaroGlassPanel(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Flip at least one card on the table to synthesize the spread.',
                  style: TextStyle(
                    fontSize: 13,
                    color: TaroColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else if (_synthesizing && _revealed.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: TaroGlassProgress(linear: false, size: 22)),
              )
            else if (_revealed.isEmpty)
              TaroGlassButton(
                label: 'SYNTHESIZE SPREAD',
                variant: TaroGlassButtonVariant.primary,
                onPressed: _startSynthesis,
              ),
            if (_revealed.isNotEmpty) ...[
              const SizedBox(height: 4),
              TaroGlassPanel(
                radius: 16,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  '$_revealed${_synthesizing ? '\u258c' : ''}',
                  style: AppTypography.label(
                    fontSize: 12,
                    height: 1.7,
                    color: TaroColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_synthesizing)
                TaroGlassButton(
                  label: _saved ? 'SAVED \u2713' : 'SAVE LOCALLY',
                  variant: _saved
                      ? TaroGlassButtonVariant.secondary
                      : TaroGlassButtonVariant.primary,
                  onPressed: _saved ? () {} : _save,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Card Inspector header: large title + orientation, the element badge
/// (`EARTH ▫ / WATER ▽ / FIRE △ / AIR ◇`) and the spread slot role.
class _CardInspectorHeader extends StatelessWidget {
  const _CardInspectorHeader({required this.slot, required this.card});

  final DealtCardSlot slot;
  final DivinationCard card;

  @override
  Widget build(BuildContext context) {
    final reverseWord =
        card.system == DivinationSystem.runes ? 'MERKSTAVE' : 'REVERSED';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.isReversed
                    ? '${card.name.toUpperCase()} · $reverseWord'
                    : card.name.toUpperCase(),
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'SLOT ${slot.index + 1} · ${slot.role.toUpperCase()} · '
                '${card.categoryLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  color: TaroColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TaroGlassPill(
          label: '${card.element.label.toUpperCase()} ${card.element.glyph}',
          accentColor: card.element.accent,
        ),
      ],
    );
  }
}

/// Compact personal-note input (text + mic dictation) — auto-saves into
/// `slot.userContext` on every change.
class _CardNoteField extends StatelessWidget {
  const _CardNoteField({
    required this.controller,
    required this.micListening,
    required this.onChanged,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final bool micListening;
  final ValueChanged<String> onChanged;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('card-note-field'),
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13,
                color: TaroColors.textPrimary,
              ),
              cursorColor: TaroColors.lavender,
              decoration: const InputDecoration(
                hintText: 'Add a personal note or thought for this card...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: TaroColors.textSecondary,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMicTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                micListening ? Icons.mic : Icons.mic_none,
                size: 20,
                color: micListening
                    ? TaroColors.rose
                    : TaroColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
