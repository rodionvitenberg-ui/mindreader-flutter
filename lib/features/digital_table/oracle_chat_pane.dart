import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_colors.dart';
import '../../state/spread_controller.dart';
import '../../state/synthesis_session.dart';

/// Pane 1 — ORACLE AI CHAT: a full-width Gemini-style conversation. The
/// pinned spread header strip (mini card icons + elemental badges) sits on
/// top and slides back to the Digital Table on tap; below it streams the
/// structured synthesis, the AI-generated +1 Clarifier questions, the
/// clarifier expansions and the free dialog.
class OracleChatPane extends StatefulWidget {
  const OracleChatPane({
    super.key,
    required this.session,
    required this.capsuleText,
    required this.onBackToTable,
    required this.onSynthesize,
    required this.onClarifierQuestion,
    required this.onFocusInput,
    required this.onScanClarifier,
  });

  final SynthesisSession session;

  /// The shared input capsule's text — the `+1 CARD FOR MY QUESTION` chip
  /// reads the reader's own typed follow-up from it.
  final TextEditingController capsuleText;
  final VoidCallback onBackToTable;

  /// Runs the AI synthesis (used by the empty-state call to action).
  final VoidCallback onSynthesize;

  /// Arms the deck for ONE +1 Clarifier Card with the tapped AI question
  /// or the reader's own question (then slides back to the table).
  final ValueChanged<String> onClarifierQuestion;

  /// Pulls the keyboard focus to the shared input capsule.
  final VoidCallback onFocusInput;
  final VoidCallback onScanClarifier;

  @override
  State<OracleChatPane> createState() => _OracleChatPaneState();
}

class _OracleChatPaneState extends State<OracleChatPane> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// The reader's own follow-up from the shared input capsule: arms the
  /// deck for ONE +1 Clarifier Card with it. Empty input → gentle prompt
  /// + keyboard focus on the capsule.
  void _onCustomClarifierQuestion() {
    final text = widget.capsuleText.text.trim();
    if (text.isEmpty) {
      HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 3),
            backgroundColor: AppColors.surface,
            content: Text(
              'Type your question in the input bar first, then tap +1 CARD.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ));
      }
      widget.onFocusInput();
      return;
    }
    widget.capsuleText.clear();
    widget.onClarifierQuestion(text);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final session = widget.session;
    final hasContent = session.generatingInitial ||
        session.hasSynthesis ||
        session.chapters.isNotEmpty ||
        session.messages.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _SpreadHeaderStrip(ctrl: ctrl, onTap: widget.onBackToTable),
          Expanded(
            child: hasContent
                ? _chatStream(ctrl, session)
                : _emptyState(ctrl),
          ),
          // Suggested clarifier actions: a fixed footer of the chat pane
          // (Gemini-style suggestion chips) — always reachable, never
          // buried inside the lazy stream.
          if (session.hasSynthesis && !session.generatingInitial)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _ChatActionChip(
                      label: '🃏 +1 CARD FOR MY QUESTION',
                      onTap: _onCustomClarifierQuestion,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ChatActionChip(
                    label: '📷 · CAMERA CLARIFIER',
                    onTap: widget.onScanClarifier,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chatStream(SpreadController ctrl, SynthesisSession session) {
    final children = <Widget>[];
    if (session.generatingInitial) {
      children.add(_OracleBubble.typing('The Oracle is weaving the reading…'));
    }
    if (session.hasSynthesis) {
      children.add(_SynthesisBubble(synthesis: session.initial!));
    }
    for (final chapter in session.chapters) {
      children.add(_UserBubble(
        text: 'You asked: ${chapter.question} — pulled '
            '${chapter.cardName}${chapter.isReversed ? ' (reversed)' : ''}',
      ));
      children.add(
        _OracleBubble(
          text: chapter.text,
          typing: chapter.generating,
          header: chapter.generating ? null : 'CLARIFIER EXPANSION',
        ),
      );
    }
    // The AI-generated follow-up Clarifier questions: attached right after
    // the synthesis (or the latest clarifier reading) and recomputed from
    // the live table — at the 10-card ceiling they become a lock note.
    if (session.hasSynthesis && !session.generatingInitial) {
      children.add(_ClarifierSuggestions(
        slots: ctrl.slots,
        onSelect: widget.onClarifierQuestion,
      ));
    }
    for (final message in session.messages) {
      switch (message.role) {
        case 'user':
          children.add(_UserBubble(text: message.text));
        case 'oracle':
          children.add(_OracleBubble(text: message.text));
        default:
          children.add(_SystemBubble(text: message.text));
      }
    }
    if (session.generatingAnswer) {
      children.add(_OracleBubble.typing('Thinking…'));
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
  Widget _emptyState(SpreadController ctrl) {
    final ready = ctrl.initialSpreadAllFaceUp;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 34,
            color: AppColors.lavender.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 14),
          Text(
            ready ? 'YOUR SPREAD IS READY' : 'NO READING YET',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              ready
                  ? 'Synthesize the spread and the Oracle will speak.'
                  : 'Deal and flip your spread on the table, then come back — '
                      'or just swipe left.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (ready) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onSynthesize();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lavender.withValues(alpha: 0.24),
                      AppColors.indigo.withValues(alpha: 0.14),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lavender, width: 1.2),
                ),
                child: Text(
                  '✦ SYNTHESIZE IN CHAT →',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lavender,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// Pinned spread header strip: mini icons of the dealt cards + elemental
/// balance badges. Tapping it (or swiping back) slides to the table.
class _SpreadHeaderStrip extends StatelessWidget {
  const _SpreadHeaderStrip({required this.ctrl, required this.onTap});

  final SpreadController ctrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dealt = [for (final s in ctrl.slots) if (s.card != null) s];
    final balance = elementalBalance(ctrl.slots);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 62,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.chevron_left,
              size: 18,
              color: AppColors.lavender,
            ),
            const SizedBox(width: 2),
            Text(
              'CURRENT SPREAD',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in dealt)
                      _MiniCardGlyph(card: s.card!, reversed: s.isReversed),
                    if (dealt.isEmpty)
                      Text(
                        'NO CARDS ON THE TABLE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            for (final e in Element.values)
              if ((balance[e] ?? 0) > 0) ...[
                const SizedBox(width: 4),
                _ElementMiniBadge(element: e, count: balance[e]!),
              ],
          ],
        ),
      ),
    );
  }
}

class _MiniCardGlyph extends StatelessWidget {
  const _MiniCardGlyph({required this.card, required this.reversed});

  final TarotCard card;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final accent = card.element.accent;
    return Container(
      width: 24,
      height: 38,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.element.glyph, style: TextStyle(fontSize: 10, color: accent)),
          if (reversed)
            Text('↓', style: TextStyle(fontSize: 7, color: accent)),
        ],
      ),
    );
  }
}

class _ElementMiniBadge extends StatelessWidget {
  const _ElementMiniBadge({required this.element, required this.count});

  final Element element;
  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = element.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${element.glyph}×$count',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}


/// Full-width chat bubbles — no narrow boxed modals.
class _BubbleShell extends StatelessWidget {
  const _BubbleShell({required this.child, required this.align});

  final Widget child;
  final AlignmentGeometry align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: align,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.86,
          ),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lavender.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lavender.withValues(alpha: 0.6)),
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OracleBubble extends StatelessWidget {
  const _OracleBubble({required this.text, this.typing = false, this.header});

  final String text;
  final bool typing;
  final String? header;

  factory _OracleBubble.typing(String label) =>
      _OracleBubble(text: label, typing: true);

  @override
  Widget build(BuildContext context) {
    return _BubbleShell(
      align: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✦', style: TextStyle(fontSize: 11, color: AppColors.lavender)),
              const SizedBox(width: 6),
              Text(
                header ?? 'ORACLE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lavender,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (typing)
            Text(
              '$text · · ·',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            )
          else
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}



/// The AI-generated +1 Clarifier questions: 2-3 spread-specific probes
/// that dynamically reference the ACTUAL cards and elemental tensions on
/// the table. Tapping one arms the deck for exactly ONE card (the
/// workspace slides back to the Digital Table). At the 10-card ceiling
/// the block becomes a permanent lock note — the conversation stays open.
class _ClarifierSuggestions extends StatelessWidget {
  const _ClarifierSuggestions({required this.slots, required this.onSelect});

  final List<DealtCardSlot> slots;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final dealtCount = slots.where((s) => s.card != null).length;
    if (dealtCount >= SpreadController.maxTableCards) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            'MAXIMUM OF 10 CARDS REACHED FOR THIS READING — '
            'THE CONVERSATION STAYS OPEN',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }
    final questions = buildClarifierSuggestions(slots);
    if (questions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WOULD YOU LIKE TO DRAW A +1 CLARIFIER CARD TO UNCOVER:',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 8),
          for (final q in questions) ...[
            _SuggestionCard(
              label: '🃏 +1 CARD: $q',
              onTap: () => onSelect(q),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// One tappable AI clarifier question card (full-width, left-aligned).
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The structured AI synthesis rendered as the first oracle message.
class _SynthesisBubble extends StatelessWidget {
  const _SynthesisBubble({required this.synthesis});

  final StructuredSynthesis synthesis;

  @override
  Widget build(BuildContext context) {
    return _BubbleShell(
      align: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SynthesisSection(
            title: '1 · CORE NARRATIVE SYNTHESIS',
            body: synthesis.narrative,
          ),
          _SynthesisSection(
            title: '2 · ELEMENTAL ALCHEMY',
            body: synthesis.elementalAlchemy,
          ),
          _SynthesisSection(
            title: '3 · ACTIONABLE VERDICT',
            body: synthesis.verdict,
          ),
          const SizedBox(height: 4),
          Text(
            'The question to sit with: ${synthesis.followUp}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SynthesisSection extends StatelessWidget {
  const _SynthesisSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ChatActionChip extends StatelessWidget {
  const _ChatActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: AppColors.lavender,
          ),
        ),
      ),
    );
  }
}
