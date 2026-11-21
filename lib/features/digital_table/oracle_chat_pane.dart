import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/services/oracle_voice_service.dart';
import '../../core/theme/element_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/synthesis_session.dart';
import '../profile/widgets/profile_header.dart';
import 'widgets/oracle_session_meta_bar.dart';
import 'widgets/reading_subject_toggle.dart';

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
    required this.onResumeCamera,
  });

  final OracleSessionController session;

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

  /// Switches back to the Camera tab for the physical flows (Resume Camera /
  /// Return to Physical Spread / Continue Guided Session).
  final VoidCallback onResumeCamera;

  @override
  State<OracleChatPane> createState() => _OracleChatPaneState();
}

class _OracleChatPaneState extends State<OracleChatPane> {
  final ScrollController _scroll = ScrollController();
  late final OracleVoiceService _voice = context.read<OracleVoiceService>();
  int _spokenOracleCount = 0;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _voice.addListener(_onVoiceChanged);
    // Lazy TTS probe — a missing engine just reports unavailable and the
    // text Oracle continues unaffected.
    _voice.initialize();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _voice.removeListener(_onVoiceChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSessionChanged() {
    if (!mounted) return;
    _speakNewestAnswer();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// Auto-speaks the newest free-dialog Oracle answer when voice is enabled
  /// (available + unmuted). Never re-speaks an answer already spoken.
  void _speakNewestAnswer() {
    final oracle = widget.session.messages
        .where((m) => m.role == 'oracle')
        .toList();
    if (oracle.length <= _spokenOracleCount) return;
    _spokenOracleCount = oracle.length;
    final text = oracle.last.text.trim();
    if (text.isNotEmpty && _voice.isAvailable && !_voice.isMuted) {
      _voice.speak(text);
    }
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
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              backgroundColor: TaroColors.surface,
              content: Text(
                'Type your question in the input bar first, then tap +1 CARD.',
                style: AppTypography.body(fontSize: 13.5, color: Colors.white),
              ),
            ),
          );
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
    final hasContent =
        session.generatingInitial ||
        session.hasSynthesis ||
        session.chapters.isNotEmpty ||
        session.messages.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ProfileHeader(
            leading: BackButton(
              color: TaroColors.lavender,
              onPressed: widget.onBackToTable,
            ),
            child: _SpreadHeaderStrip(ctrl: ctrl, onTap: widget.onBackToTable),
          ),
          OracleSessionMetaBar(
            session: session,
            voice: _voice,
            onResumeCamera: widget.onResumeCamera,
          ),
          Expanded(
            child: hasContent ? _chatStream(ctrl, session) : _emptyState(ctrl),
          ),
          // Suggested clarifier actions: a fixed footer of the chat pane
          // (Gemini-style suggestion chips) — always reachable, never
          // buried inside the lazy stream.
          if (session.hasSynthesis && !session.generatingInitial)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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
                  Flexible(
                    child: _ChatActionChip(
                      label: '📷 · CAMERA CLARIFIER',
                      onTap: widget.onScanClarifier,
                    ),
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
      children.add(_OracleResponse.typing('The Oracle is weaving the reading…'));
    }
    if (session.hasSynthesis) {
      children.add(_SynthesisResponse(synthesis: session.initial!));
    }
    for (final chapter in session.chapters) {
      children.add(
        _UserBubble(
          text:
              'You asked: ${chapter.question} — pulled '
              '${chapter.cardName}${chapter.isReversed ? ' (reversed)' : ''}',
        ),
      );
      children.add(
        _OracleResponse(
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
      children.add(
        _ClarifierSuggestions(
          slots: ctrl.slots,
          clarifierLimitReached: ctrl.isClarifierLimitReached,
          maxCards: ctrl.maxCardsForCurrentSpread,
          onSelect: widget.onClarifierQuestion,
        ),
      );
    }
    for (final message in session.messages) {
      switch (message.role) {
        case 'user':
          children.add(_UserBubble(text: message.text));
        case 'oracle':
          children.add(_OracleResponse(text: message.text));
        default:
          children.add(_SystemBubble(text: message.text));
      }
    }
    if (session.generatingAnswer) {
      children.add(_OracleResponse.typing('Thinking…'));
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _emptyState(SpreadController ctrl) {
    final ready = ctrl.canSynthesize;
    // Scrollable + centered: on a tall screen the empty state is vertically
    // centered, and on a short/landscape screen it scrolls instead of
    // overflowing the Column.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          TaroColors.lavender.withValues(alpha: 0.24),
                          TaroColors.indigo.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: TaroColors.lavender.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 26,
                      color: TaroColors.lavender,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    ready ? 'YOUR SPREAD IS READY' : 'NO READING YET',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: TaroColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      ready
                          ? 'Synthesize the spread and the Oracle will speak.'
                          : 'Deal and flip your spread on the table, then come back — '
                                'or just swipe left.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        fontSize: 14.5,
                        height: 1.5,
                        color: TaroColors.textSecondary,
                      ),
                    ),
                  ),
                  if (ready) ...[
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ReadingSubjectToggle(),
                    ),
                    const SizedBox(height: 14),
                    TaroGlassButton(
                      label: '✦ SYNTHESIZE IN CHAT →',
                      variant: TaroGlassButtonVariant.primary,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onSynthesize();
                      },
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

/// Pinned spread header strip: mini icons of the dealt cards + elemental
/// balance badges. Tapping it (or swiping back) slides to the table.
class _SpreadHeaderStrip extends StatelessWidget {
  const _SpreadHeaderStrip({required this.ctrl, required this.onTap});

  final SpreadController ctrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dealt = [
      for (final s in ctrl.slots)
        if (s.card != null) s,
    ];
    final balance = elementalBalance(ctrl.slots);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ProfileHeader.actionSize,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: TaroColors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TaroColors.border),
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'CURRENT SPREAD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  fontSize: 9.5,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: TaroColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
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
                        style: AppTypography.label(
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w500,
                          color: TaroColors.textSecondary.withValues(alpha: 0.75),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCardGlyph extends StatelessWidget {
  const _MiniCardGlyph({required this.card, required this.reversed});

  final DivinationCard card;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final accent = card.element.accent;
    final glyph = card.system == DivinationSystem.runes
        ? (card as RuneDivinationCard).stone.glyph
        : card.element.glyph;
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
          Text(
            glyph,
            style: TextStyle(
              fontSize: card.system == DivinationSystem.runes ? 13 : 10,
              color: accent,
            ),
          ),
          if (reversed) Text('↓', style: TextStyle(fontSize: 7, color: accent)),
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
        style: AppTypography.label(
          fontSize: 8.5,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Gemini-style subtle sparkle header shared by Oracle answers and synthesis.
class _OracleSpeakerHeader extends StatelessWidget {
  const _OracleSpeakerHeader({this.label = 'ORACLE'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TaroColors.lavender.withValues(alpha: 0.28),
                TaroColors.indigo.withValues(alpha: 0.18),
              ],
            ),
          ),
          child: const Text(
            '✦',
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: TaroColors.lavender,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.label(
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: TaroColors.lavender,
          ),
        ),
      ],
    );
  }
}

/// Gemini-style user prompt bubble: right-aligned soft pill with asymmetric
/// bottom-right corner and larger readable copy.
class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: TaroColors.surface.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
            border: Border.all(
              color: TaroColors.lavender.withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            text,
            style: AppTypography.chatUser(
              fontSize: 15,
              height: 1.48,
              color: TaroColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gemini-style open full-width Oracle response — no enclosing card box,
/// allowing long-form readings to breathe cleanly across the canvas.
class _OracleResponse extends StatelessWidget {
  const _OracleResponse({required this.text, this.typing = false, this.header});

  final String text;
  final bool typing;
  final String? header;

  factory _OracleResponse.typing(String label) =>
      _OracleResponse(text: label, typing: true);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OracleSpeakerHeader(label: header ?? 'ORACLE'),
          const SizedBox(height: 10),
          if (typing)
            TaroGlassProgress(label: '$text · · ·')
          else
            Text(
              text,
              style: AppTypography.chatOracle(
                fontSize: 15.5,
                height: 1.62,
                color: TaroColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Align(
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            height: 1.4,
            color: TaroColors.textSecondary.withValues(alpha: 0.85),
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
  const _ClarifierSuggestions({
    required this.slots,
    required this.clarifierLimitReached,
    required this.maxCards,
    required this.onSelect,
  });

  final List<DealtCardSlot> slots;
  final bool clarifierLimitReached;
  final int maxCards;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (clarifierLimitReached) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            'MAXIMUM OF ${SpreadController.maxClarifierCards} CLARIFIER CARDS '
            'REACHED — THE CONVERSATION STAYS OPEN',
            textAlign: TextAlign.center,
            style: AppTypography.label(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: TaroColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final questions = buildClarifierSuggestions(slots, hardMax: maxCards);
    if (questions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WOULD YOU LIKE TO DRAW A +1 CLARIFIER CARD TO UNCOVER:',
            style: AppTypography.label(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
          ),
          const SizedBox(height: 10),
          for (final q in questions) ...[
            _SuggestionCard(label: '🃏 +1 CARD: $q', onTap: () => onSelect(q)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// One tappable AI clarifier question card (Gemini-style follow-up chip).
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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: TaroColors.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TaroColors.lavender.withValues(alpha: 0.36)),
        ),
        child: Text(
          label,
          style: AppTypography.chatUser(
            fontSize: 14,
            height: 1.4,
            color: TaroColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The structured AI synthesis rendered as a full-width Gemini-style answer.
class _SynthesisResponse extends StatelessWidget {
  const _SynthesisResponse({required this.synthesis});

  final StructuredSynthesis synthesis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 18, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OracleSpeakerHeader(label: 'ORACLE'),
          const SizedBox(height: 14),
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
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: TaroColors.lavender.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: TaroColors.lavender.withValues(alpha: 0.7),
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              'The question to sit with: ${synthesis.followUp}',
              style: AppTypography.chatOracle(
                fontSize: 14.5,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: TaroColors.textPrimary.withValues(alpha: 0.88),
              ),
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
          style: AppTypography.heading(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: TaroColors.lavender,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: AppTypography.chatOracle(
            fontSize: 15.5,
            height: 1.62,
            color: TaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
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
    return TaroGlassChip(
      label: label,
      selected: true,
      compact: true,
      onTap: onTap,
    );
  }
}
