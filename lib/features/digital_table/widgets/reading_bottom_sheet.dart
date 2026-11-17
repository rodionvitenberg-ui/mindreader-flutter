import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/divination_card.dart';
import '../../../core/models/divination_system.dart';
import '../../../core/models/spread_type.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xEB13131A), // surface @ 0.92
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (slot != null && card != null) ...[
                    // ---- Card Inspector Sheet (tapped face-up card) ----
                    _CardInspectorHeader(slot: slot, card: card),
                    const SizedBox(height: 18),
                    Text(
                      slot.isReversed && card.reversed != null
                          ? 'REVERSED MEANING'
                          : 'UPRIGHT MEANING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meaningFor(slot),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      card.keywords.map((k) => k.toUpperCase()).join(' · '),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: AppColors.lavender,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'RESONANCE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final pill in _resonancePills)
                          _SheetChip(
                            label: pill,
                            active: _resonance == pill,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _resonance =
                                  _resonance == pill ? null : pill);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PERSONAL NOTE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
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
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'READING CONTEXT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final chip in _contextChips)
                          _SheetChip(
                            label: chip,
                            active: _contextChip == chip,
                            onTap: () => _pickContext(chip),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  if (!canSynthesize)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Flip at least one card on the table to synthesize the spread.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    )
                  else if (_synthesizing && _revealed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lavender,
                          ),
                        ),
                      ),
                    )
                  else if (_revealed.isEmpty)
                    _PrimaryAction(
                      label: 'SYNTHESIZE SPREAD',
                      onTap: _startSynthesis,
                    ),
                  if (_revealed.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        '$_revealed${_synthesizing ? '\u258c' : ''}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_synthesizing)
                      _PrimaryAction(
                        label: _saved ? 'SAVED \u2713' : 'SAVE LOCALLY',
                        active: _saved,
                        onTap: _saved ? () {} : _save,
                      ),
                  ],
                  ],
                ],
              ),
            ),
          ),
        ),
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: card.element.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: card.element.accent.withValues(alpha: 0.6)),
          ),
          child: Text(
            '${card.element.label.toUpperCase()} ${card.element.glyph}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: card.element.accent,
            ),
          ),
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
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              cursorColor: AppColors.lavender,
              decoration: const InputDecoration(
                hintText: 'Add a personal note or thought for this card...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMicTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                micListening ? Icons.mic : Icons.mic_none,
                size: 20,
                color: micListening
                    ? AppColors.lavender
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? [
                    AppColors.harmonyEmerald.withValues(alpha: 0.2),
                    AppColors.harmonyEmerald.withValues(alpha: 0.1),
                  ]
                : [
                    AppColors.lavender.withValues(alpha: 0.22),
                    AppColors.indigo.withValues(alpha: 0.12),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.harmonyEmerald : AppColors.lavender,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.harmonyEmerald : AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
