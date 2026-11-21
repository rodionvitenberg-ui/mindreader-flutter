import 'package:flutter/material.dart';

import '../../../core/models/divination_card.dart';
import '../../../core/services/spread_inference_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';

/// The finalized Recognition Review outcome: the reader-confirmed ORDER of
/// physical cards + the chosen spread. `spread == null` means Freeform — the
/// handoff must keep ALL cards (never drop silently).
class RecognitionReviewResult {
  const RecognitionReviewResult({
    required this.cards,
    required this.reversed,
    required this.spread,
  });

  final List<DivinationCard> cards;
  final List<bool> reversed;

  /// The chosen spread candidate; null → Freeform/Custom.
  final SpreadCandidate? spread;
}

/// Phase 2.2 — the Recognition Review bottom sheet shown between a camera
/// scan and the table handoff. It lets the reader:
///   * confirm or change the proposed spread (compact choice on ambiguity);
///   * toggle orientation (never for Lenormand — `supportsReversal` per card);
///   * reorder cards (order confirmation is REQUIRED when no geometry);
///   * remove a false positive.
/// Confidence is never invented — only what the engine actually reported is
/// shown (a card is recognized or it is not).
class RecognitionReviewSheet extends StatefulWidget {
  const RecognitionReviewSheet({
    super.key,
    required this.cards,
    required this.reversed,
    required this.inference,
  });

  final List<DivinationCard> cards;
  final List<bool> reversed;
  final SpreadInferenceResult inference;

  static Future<RecognitionReviewResult?> show(
    BuildContext context, {
    required List<DivinationCard> cards,
    required List<bool> reversed,
    required SpreadInferenceResult inference,
  }) {
    return showTaroGlassSheet<RecognitionReviewResult>(
      context: context,
      builder: (_) => RecognitionReviewSheet(
        cards: cards,
        reversed: reversed,
        inference: inference,
      ),
    );
  }

  @override
  State<RecognitionReviewSheet> createState() => _RecognitionReviewSheetState();
}

class _ReviewItem {
  _ReviewItem(this.card, this.reversed);
  final DivinationCard card;
  bool reversed;
}

class _RecognitionReviewSheetState extends State<RecognitionReviewSheet> {
  late final List<_ReviewItem> _items = [
    for (var i = 0; i < widget.cards.length; i++)
      _ReviewItem(
        widget.cards[i],
        i < widget.reversed.length ? widget.reversed[i] : false,
      ),
  ];

  /// Index into `widget.inference.candidates`, or null → Freeform.
  late int? _selected = widget.inference.candidates.isEmpty ? null : 0;

  void _toggleReversed(int i) {
    setState(() => _items[i].reversed = !_items[i].reversed);
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _items.length) return;
    setState(() {
      final tmp = _items[i];
      _items[i] = _items[j];
      _items[j] = tmp;
    });
  }

  void _confirm() {
    final spread = _selected == null
        ? null
        : widget.inference.candidates[_selected!];
    Navigator.of(context).pop(
      RecognitionReviewResult(
        cards: [for (final it in _items) it.card],
        reversed: [for (final it in _items) it.reversed],
        spread: spread,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inference = widget.inference;
    final showCandidates = inference.candidates.length > 1;
    final freeform = inference.isFreeform;

    return TaroGlassSheet(
      title: '${_items.length} RECOGNIZED',
      subtitle: freeform
          ? 'FREEFORM — no template matches; every card is kept'
          : 'PROPOSED: ${inference.top!.label}',
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCandidates) ...[
            Text(
              'CHOOSE SPREAD',
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.9,
                color: TaroColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < inference.candidates.length; i++)
              _CandidateRow(
                label: inference.candidates[i].label,
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
            const SizedBox(height: 10),
          ],
          Text(
            'CONFIRM ORDER & CARDS',
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.9,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _items.length; i++)
            _CardRow(
              index: i,
              item: _items[i],
              canToggle: _items[i].card.supportsReversal,
              onToggle: () => _toggleReversed(i),
              onUp: i > 0 ? () => _move(i, -1) : null,
              onDown: i < _items.length - 1 ? () => _move(i, 1) : null,
              onRemove: () => _remove(i),
            ),
          const SizedBox(height: 14),
          TaroGlassButton(
            label: 'CONFIRM & PLACE ON TABLE',
            variant: TaroGlassButtonVariant.primary,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? TaroColors.lavender.withValues(alpha: 0.18)
                : TaroColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? TaroColors.lavender.withValues(
                      alpha: TaroOpacity.borderStrong,
                    )
                  : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.body(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? TaroColors.lavender : TaroColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.index,
    required this.item,
    required this.canToggle,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final int index;
  final _ReviewItem item;
  final bool canToggle;
  final VoidCallback onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final card = item.card;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: TaroColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Row(
        children: [
          _Thumb(card: card),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1} · ${card.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TaroColors.textPrimary,
                  ),
                ),
                if (item.reversed)
                  Text(
                    'REVERSED',
                    style: AppTypography.label(
                      fontSize: 8.5,
                      letterSpacing: 0.7,
                      color: TaroColors.amber,
                    ),
                  ),
              ],
            ),
          ),
          if (canToggle)
            _IconBtn(
              icon: item.reversed ? Icons.undo : Icons.flip,
              tooltip: 'Toggle orientation',
              onTap: onToggle,
            ),
          _IconBtn(
            icon: Icons.arrow_upward,
            tooltip: 'Move up',
            enabled: onUp != null,
            onTap: onUp ?? () {},
          ),
          _IconBtn(
            icon: Icons.arrow_downward,
            tooltip: 'Move down',
            enabled: onDown != null,
            onTap: onDown ?? () {},
          ),
          _IconBtn(icon: Icons.close, tooltip: 'Remove', onTap: onRemove),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.card});

  final DivinationCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TaroColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
        ),
      ),
      child: Text(
        card.shortLabel,
        textAlign: TextAlign.center,
        style: AppTypography.display(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: TaroColors.lavender,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? TaroColors.textSecondary : TaroColors.textDisabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 34,
            height: 44,
            child: Center(child: Icon(icon, size: 17, color: color)),
          ),
        ),
      ),
    );
  }
}
