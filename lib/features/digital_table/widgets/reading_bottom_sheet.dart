import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/spread_type.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/spread_controller.dart';

/// Glassmorphic bottom sheet: context chips, card-specific Socratic prompt,
/// streaming (typewriter) oracle synthesis, local-first saving.
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
  static const _emotionChips = ['Resonates', 'Challenging', 'Not yet'];

  String? _contextChip;
  String? _emotion;
  String _fullText = '';
  String _revealed = '';
  bool _synthesizing = false;
  bool _saved = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    final slots = ctrl.slots;
    final card = (widget.cardIndex != null && widget.cardIndex! < slots.length)
        ? slots[widget.cardIndex!].card
        : null;
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
                  Text(
                    card != null ? 'Card Reflection' : 'Live Reading',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card != null
                        ? '${card.name.toUpperCase()} · SOCRATIC PROMPT'
                        : ctrl.spreadType.label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (card != null) ...[
                    Text(
                      card.socratic,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final e in _emotionChips)
                          _SheetChip(
                            label: e,
                            active: _emotion == e,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() =>
                                  _emotion = _emotion == e ? null : e);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
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
              ),
            ),
          ),
        ),
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
