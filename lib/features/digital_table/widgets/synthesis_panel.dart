import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/intention_prompts.dart';
import '../../../core/models/dealt_card_slot.dart';
import '../../../core/models/tarot_card_model.dart';
import '../../../core/services/oracle_synthesis_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/spread_controller.dart';
import '../../../state/synthesis_session.dart';
import 'elemental_threads_painter.dart';
import 'shuffle_physics.dart';

/// The rich, structured synthesis reading rendered directly on the table:
/// a glassmorphic panel with three sections — Core Narrative Synthesis,
/// Elemental Alchemy, Actionable Verdict — plus the endless single-card
/// clarifier loop (+1 card follow-up prompts and camera-sync actions).
class SynthesisPanel extends StatefulWidget {
  const SynthesisPanel({
    super.key,
    required this.session,
    required this.ctrl,
    required this.onClarifierPull,
    required this.onClarifierCamera,
  });

  final SynthesisSession session;
  final SpreadController ctrl;

  /// Pull the clarifier from the digital deck.
  final void Function(String question) onClarifierPull;

  /// Photograph the clarifier via the camera pipeline.
  final void Function(String question) onClarifierCamera;

  @override
  State<SynthesisPanel> createState() => _SynthesisPanelState();
}

class _SynthesisPanelState extends State<SynthesisPanel> {
  final TextEditingController _customQuestion = TextEditingController();
  String _revealed = '';
  Timer? _typewriter;

  @override
  void dispose() {
    _typewriter?.cancel();
    _customQuestion.dispose();
    super.dispose();
  }

  void _reveal(String fullText) {
    _typewriter?.cancel();
    _revealed = '';
    _typewriter = Timer.periodic(const Duration(milliseconds: 12), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _revealed = fullText.substring(
          0,
          math.min(_revealed.length + 3, fullText.length),
        );
        if (_revealed.length >= fullText.length) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Container(
      width: deckWidth,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '✦',
                style: TextStyle(fontSize: 14, color: AppColors.lavender),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYNTHESIZE READING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavender,
                      ),
                    ),
                    Text(
                      'СИНТЕЗИРОВАТЬ ПРОГНОЗ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7.5,
                        letterSpacing: 1.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (session.generatingInitial) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.lavender,
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'READING THE THREADS...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.8,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (session.initial != null) ...[
            _buildSections(session.initial!),
            const SizedBox(height: 12),
            _buildClarifierActions(session),
            if (session.chapters.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SectionDivider(),
              const SizedBox(height: 10),
              for (var i = 0; i < session.chapters.length; i++) ...[
                _buildChapter(session.chapters[i], i + 1),
                if (i < session.chapters.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSections(StructuredSynthesis s) {
    final fullText = s.narrative;
    if (_revealed.isEmpty && fullText.isNotEmpty) _reveal(fullText);
    final showing = _revealed.length < fullText.length;
    final balance = elementalBalance(widget.ctrl.slots);
    final dominant = dominantElements(balance);
    final missing = missingElements(balance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('1 · CORE NARRATIVE SYNTHESIS'),
        const SizedBox(height: 6),
        SelectableText(
          showing ? '$_revealed\u258c' : fullText,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.65,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        const _SectionHeader('2 · ELEMENTAL ALCHEMY'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in [
              Element.fire,
              Element.water,
              Element.air,
              Element.earth,
            ])
              _ElementBadge(
                element: e,
                count: balance[e] ?? 0,
                dominant: dominant.contains(e),
                missing: missing.contains(e),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          s.elementalAlchemy,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.65,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        const _SectionHeader('3 · ACTIONABLE VERDICT'),
        const SizedBox(height: 6),
        SelectableText(
          s.verdict,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.65,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lavender.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'The question to sit with: ${s.followUp}',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 15,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: AppColors.lavender,
            ),
          ),
        ),
      ],
    );
  }

  void _pullFollowUp(String question) {
    HapticFeedback.selectionClick();
    widget.onClarifierPull(question);
  }


  Widget _buildClarifierActions(SynthesisSession session) {
    final cameraSync =
        widget.ctrl.sourceMode == TableSourceMode.physicalCameraSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('EXPAND THE READING · +1 CARD'),
        const SizedBox(height: 8),
        for (final question in clarifierFollowUpQuestions) ...[
          _ClarifierPrompt(
            label: '+ Pull 1 Card: $question',
            onTap: () => _pullFollowUp(question),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.canvas.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _customQuestion,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: InputBorder.none,
                    hintText: 'Ask my own question...',
                    hintStyle: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _PullButton(
              label: 'PULL',
              onTap: () {
                final q = _customQuestion.text.trim();
                if (q.isEmpty) return;
                _customQuestion.clear();
                _pullFollowUp(q);
              },
            ),
          ],
        ),
        if (cameraSync) ...[
          const SizedBox(height: 8),
          _ClarifierPrompt(
            icon: Icons.photo_camera_outlined,
            label: '📷 Photograph Next Physical Card',
            onTap: () {
              final q = _customQuestion.text.trim();
              final question = q.isEmpty
                  ? 'What does the next physical card reveal?'
                  : q;
              _customQuestion.clear();
              HapticFeedback.selectionClick();
              widget.onClarifierCamera(question);
            },
          ),
          const SizedBox(height: 6),
          _ClarifierPrompt(
            icon: Icons.style_outlined,
            label: '🃏 Draw from Digital Deck',
            onTap: () {
              final q = _customQuestion.text.trim();
              final question = q.isEmpty
                  ? 'What does the digital deck clarify?'
                  : q;
              _customQuestion.clear();
              _pullFollowUp(question);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildChapter(ClarifierChapter chapter, int number) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLARIFIER EXPANSION $number',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: AppColors.harmonyCyan,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${chapter.cardName} '
          '${chapter.isReversed ? '(reversed)' : '(upright)'} · '
          '${chapter.question}',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        if (chapter.generating)
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.lavender,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'READING THE EXPANSION...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  letterSpacing: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          )
        else
          SelectableText(
            chapter.text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.65,
              color: AppColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 8.5,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w700,
        color: AppColors.lavender,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.border);
  }
}

class _ElementBadge extends StatelessWidget {
  const _ElementBadge({
    required this.element,
    required this.count,
    required this.dominant,
    required this.missing,
  });

  final Element element;
  final int count;
  final bool dominant;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final colors = elementalThreadColors(element);
    final color = missing
        ? AppColors.textMuted.withValues(alpha: 0.5)
        : dominant
            ? colors.last
            : colors.first.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '${element.glyph} ${element.label[0]}×$count',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ClarifierPrompt extends StatelessWidget {
  const _ClarifierPrompt({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.lavender),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              size: 15,
              color: AppColors.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

class _PullButton extends StatelessWidget {
  const _PullButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}

