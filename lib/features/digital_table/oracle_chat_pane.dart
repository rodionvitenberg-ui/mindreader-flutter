import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/dealt_card_slot.dart';
import '../../core/services/oracle_synthesis_service.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/oracle_session_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/synthesis_session.dart';
import '../profile/widgets/profile_header.dart';
import 'widgets/oracle_session_meta_bar.dart';
import 'widgets/oracle_card_rail.dart';
import 'widgets/reading_subject_toggle.dart';

/// Preparation and conversation share the same Oracle session and header.
class OracleChatPane extends StatefulWidget {
  const OracleChatPane({
    super.key,
    required this.session,
    required this.inConversation,
    required this.showReadingCards,
    required this.readingKey,
    required this.composer,
    required this.capsuleText,
    required this.onBackToTable,
    required this.onSynthesize,
    required this.onClarifierQuestion,
    required this.onFocusInput,
    required this.onScanClarifier,
    required this.onResumeCamera,
  });

  final OracleSessionController session;
  final bool inConversation;
  final bool showReadingCards;
  final Object readingKey;
  final Widget? composer;

  /// The shared input capsule's text — the `+1 CARD FOR MY QUESTION` chip
  /// reads the reader's own typed follow-up from it.
  final TextEditingController capsuleText;
  final VoidCallback onBackToTable;

  /// Runs the AI synthesis (used by the empty-state call to action).
  final VoidCallback onSynthesize;

  /// Draws a visible clarifier in the current conversation.
  final bool Function(String) onClarifierQuestion;

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
  bool _followScheduled = false;
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
    if (_followScheduled || !_scroll.hasClients ||
        _scroll.position.extentAfter > 24) {
      return;
    }
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted || !_scroll.hasClients || _scroll.position.extentAfter < 1) {
        return;
      }
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
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
    if (widget.onClarifierQuestion(text)) widget.capsuleText.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SpreadController>();
    final session = widget.session;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ProfileHeader(
            leading: BackButton(
              color: TaroColors.lavender,
              onPressed: widget.onBackToTable,
            ),
            child: const ProfileHeaderTitle('header.oracle'),
          ),
          OracleSessionMetaBar(
            session: session,
            onResumeCamera: widget.onResumeCamera,
          ),
          Expanded(
            child: widget.inConversation
                ? OracleMessageViewport(
                    key: ValueKey(session.epoch),
                    readingKey: widget.readingKey,
                    showCards:
                        widget.showReadingCards &&
                        ctrl.slots.any((slot) => slot.card != null),
                    messages: _chatStream(ctrl, session),
                  )
                : _preparation(ctrl),
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
          ?widget.composer,
        ],
      ),
    );
  }

  Widget _chatStream(SpreadController ctrl, SynthesisSession session) {
    final children = <Widget>[];
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
    // the live table. At the card limit the suggestions become a status note.
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
      key: PageStorageKey(('oracle-messages', widget.readingKey)),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _preparation(SpreadController ctrl) {
    final ready = ctrl.canSynthesize;
    final waiting = widget.session.generatingInitial;
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
                    ExcludeFocus(
                      excluding: waiting,
                      child: IgnorePointer(
                        ignoring: waiting,
                        child: const ReadingSubjectToggle(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.session.initialFailed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Semantics(
                          liveRegion: true,
                          child: const Text(
                            'The Oracle could not finish this reading. Try again.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    TaroGlassButton(
                      label: waiting
                          ? 'CONNECTING TO THE ORACLE…'
                          : widget.session.initialFailed
                          ? 'RETRY SYNTHESIS'
                          : '✦ SYNTHESIZE IN CHAT →',
                      loading: waiting,
                      variant: TaroGlassButtonVariant.primary,
                      onPressed: waiting ? null : widget.onSynthesize,
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
        Flexible(
          child: Text(
            label,
            style: AppTypography.label(
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: TaroColors.lavender,
            ),
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

/// Follow-up questions drawn from the cards already in the reading.
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
            'MAXIMUM OF $maxCards CARDS REACHED · YOU CAN STILL CHAT',
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
    final questions = buildClarifierSuggestions(slots, hardMax: maxCards, relationships: context.read<SpreadController>().relationships);
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
