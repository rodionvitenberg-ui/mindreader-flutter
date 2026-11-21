import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/reading_session_badge.dart';
import '../../core/models/reading_source.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/app_settings_controller.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../profile/widgets/profile_header.dart';

/// Pane 2 — SPREAD HISTORY & NOTEBOOKS: the local-first archive of saved
/// readings (Gemini sidebar/history inspired). One tap restores the exact
/// conversation AND the exact table. `PRO` badge marks unlimited local
/// storage.
class SpreadHistoryPane extends StatefulWidget {
  const SpreadHistoryPane({
    super.key,
    required this.history,
    required this.onNewSpread,
    required this.onRestore,
    required this.onBackToTable,
  });

  final SessionHistoryController history;
  final VoidCallback onNewSpread;
  final VoidCallback onBackToTable;
  final ValueChanged<SpreadSessionSnapshot> onRestore;

  @override
  State<SpreadHistoryPane> createState() => _SpreadHistoryPaneState();
}

class _SpreadHistoryPaneState extends State<SpreadHistoryPane> {
  static const _notebooks = ['All Readings', 'Relationships', 'Career & Path'];

  String _notebook = 'All Readings';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.history,
        builder: (context, _) {
          final sessions = [
            for (final s in widget.history.sessions)
              if (_notebook == 'All Readings' || s.notebook == _notebook) s,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                leading: BackButton(
                  color: AppColors.lavender,
                  onPressed: widget.onBackToTable,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SPREAD HISTORY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(
                          fontSize: 13,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ProBadge(
                      unlocked: context
                          .watch<AppSettingsController>()
                          .isProUnlocked,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _NewSpreadButton(onTap: widget.onNewSpread),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    for (var i = 0; i < _notebooks.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _NotebookChip(
                          label: _notebooks[i],
                          active: _notebook == _notebooks[i],
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _notebook = _notebooks[i]);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: !widget.history.loaded
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lavender,
                          ),
                        ),
                      )
                    : sessions.isEmpty
                    ? _EmptyArchive(filtered: _notebook != 'All Readings')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: sessions.length,
                        itemBuilder: (context, i) => _SessionTile(
                          session: sessions[i],
                          onTap: () => widget.onRestore(sessions[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge({required this.unlocked});

  /// Mirrors the shared PRO flag from [AppSettingsController].
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lavender, AppColors.indigo],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        unlocked ? 'PRO ∞' : 'PRO',
        style: AppTypography.label(
          fontSize: 9,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w800,
          color: AppColors.canvas,
        ),
      ),
    );
  }
}

class _NewSpreadButton extends StatelessWidget {
  const _NewSpreadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lavender.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lavender),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: AppColors.lavender),
            const SizedBox(width: 8),
            Text(
              'NEW SPREAD · НОВЫЙ РАСКЛАД',
              style: AppTypography.label(
                fontSize: 10,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookChip extends StatelessWidget {
  const _NotebookChip({
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.lavender : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 32,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'THIS NOTEBOOK IS EMPTY' : 'NO READINGS SAVED YET',
            style: AppTypography.label(
              fontSize: 10.5,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Synthesize your first spread and it will wait here.',
            style: AppTypography.body(
              fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}


class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final SpreadSessionSnapshot session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final snippet = session.synthesis?.narrative ??
        (session.messages.isNotEmpty
            ? session.messages.last.text
            : session.sessionNotes.isEmpty
                ? 'No context notes'
                : session.sessionNotes.join(' · '));
    final isAstral = session.kind != SessionKind.divinationSpread;
    final customCount = session.customQuestions.isNotEmpty
        ? session.customQuestions.length
        : session.cards.length;
    final title = session.astralSessionTitle ??
        (session.customSpread != null
            ? '$customCount · ${session.customSpread}'
            : session.spreadType.label);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardGlyphStack(cards: session.cards),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            fontSize: 10,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lavender,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isAstral)
                        _AstralBadge(kind: session.kind)
                      else ...[
                        if (session.readingSource == ReadingSource.physical)
                          _FlowBadge(
                            label: readingSessionBadge(
                              source: session.readingSource,
                              mode: session.readingMode,
                            ),
                          ),
                        const SizedBox(width: 4),
                        _NotebookTag(label: session.notebook),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatSessionTime(session.timestamp),
                    style: AppTypography.label(
                      fontSize: 8.5,
                      letterSpacing: 1.0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      fontSize: 10.5,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardGlyphStack extends StatelessWidget {
  const _CardGlyphStack({required this.cards});

  final List<RestoredSpreadCard> cards;

  @override
  Widget build(BuildContext context) {
    final preview = cards.take(4).toList();
    if (preview.isEmpty) {
      return Container(
        width: 40,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.lavender.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: Text(
            '✦',
            style: TextStyle(fontSize: 16, color: AppColors.lavender),
          ),
        ),
      );
    }
    return SizedBox(
      width: 40,
      height: 44,
      child: Stack(
        children: [
          for (var i = 0; i < preview.length; i++)
            Positioned(
              left: i * 4.0,
              top: i * 3.0,
              child: Container(
                width: 26,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.label(
                      fontSize: 9,
                      color: AppColors.lavender,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotebookTag extends StatelessWidget {
  const _NotebookTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label(
          fontSize: 7.5,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: AppColors.harmonyCyan,
        ),
      ),
    );
  }
}

/// The cosmic badge marking a saved Astral conversation.
class _AstralBadge extends StatelessWidget {
  const _AstralBadge({required this.kind});

  final SessionKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      SessionKind.natalChartReading => '☉ NATAL',
      SessionKind.horoscopeReading => '✦ HOROSCOPE',
      SessionKind.synastryReading => '☍ SYNASTRY',
      SessionKind.zodiacReading => '✦ ZODIAC',
      SessionKind.divinationSpread => 'SPREAD',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          fontSize: 7.5,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: AppColors.lavender,
        ),
      ),
    );
  }
}

/// The flow badge marking a physical reading's origin: GUIDED / LIVE /
/// PHYSICAL. Digital readings show no flow badge (DIGITAL is the implicit
/// default), keeping the common case uncluttered.
class _FlowBadge extends StatelessWidget {
  const _FlowBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          fontSize: 7.5,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
          color: AppColors.harmonyCyan,
        ),
      ),
    );
  }
}

/// 'Nov 17 · 14:32' — short local form, no year clutter.
String formatSessionTime(String iso) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  return '${months[parsed.month - 1]} ${parsed.day} · $hh:$mm';
}

