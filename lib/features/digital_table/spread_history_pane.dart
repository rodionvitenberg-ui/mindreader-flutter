import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/session_history_controller.dart';
import '../../state/spread_session_snapshot.dart';
import '../profile/widgets/profile_header.dart';
import '../../core/l10n/app_strings.dart';

/// Pane 2 — SPREAD HISTORY & NOTEBOOKS: the local-first archive of saved
/// readings (Gemini sidebar/history inspired). One tap restores the exact
/// conversation AND the exact table with unlimited local storage.
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
  static const _notebooks = ['all', 'relationships', 'career'];

  String _notebook = 'all';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.history,
        builder: (context, _) {
          final sessions = [
            for (final s in widget.history.sessions)
              if (_notebook == 'all' || s.notebook == _notebook) s,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                leading: BackButton(
                  color: TaroColors.lavender,
                  onPressed: widget.onBackToTable,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(AppStrings.g('ui.spread_history_pane.spread_history'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 13,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.textPrimary,
                    ),
                  ),
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
                          label: AppStrings.g('history.notebook.${_notebooks[i]}'),
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
                        child: TaroGlassProgress(linear: false, size: 22),
                      )
                    : sessions.isEmpty
                    ? _EmptyArchive(filtered: _notebook != 'all')
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

class _NewSpreadButton extends StatelessWidget {
  const _NewSpreadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TaroGlassLayer(
        child: TaroGlassButton(
          label: AppStrings.g('ui.spread_history_pane.new_spread'),
          icon: Icons.add,
          variant: TaroGlassButtonVariant.primary,
          onPressed: onTap,
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
    return TaroGlassChip(
      label: label,
      selected: active,
      expanded: true,
      compact: true,
      uppercase: true,
      onTap: onTap,
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
            color: TaroColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? AppStrings.g('ui.spread_history_pane.this_notebook_is_empty') : AppStrings.g('ui.spread_history_pane.no_readings_saved_yet'),
            style: AppTypography.label(
              fontSize: 10.5,
              letterSpacing: 1.0,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(AppStrings.g('ui.spread_history_pane.synthesize_your_first_spread_and_it_will_wait_he'),
            style: AppTypography.body(
              fontSize: 11,
              color: TaroColors.textSecondary.withValues(alpha: 0.8),
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
                ? AppStrings.g('history.noContextNotes')
                : session.sessionNotes.join(' · '));
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
          color: TaroColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
          ),
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
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w700,
                      color: TaroColors.lavender,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatSessionTime(session.timestamp),
                    style: AppTypography.label(
                      fontSize: 8.5,
                      letterSpacing: 1.0,
                      color: TaroColors.textSecondary,
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
                      color: TaroColors.textSecondary,
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
                color: TaroColors.textSecondary,
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
          color: TaroColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TaroColors.lavender.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: Text(
            '✦',
            style: TextStyle(fontSize: 16, color: TaroColors.lavender),
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
                  color: TaroColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TaroColors.border),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.label(
                      fontSize: 9,
                      color: TaroColors.lavender,
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

/// 'Nov 17 · 14:32' — short local form, no year clutter.
String formatSessionTime(String iso) {

  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  return '${AppStrings.g('common.month.${parsed.month}')} ${parsed.day} · $hh:$mm';
}

