import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/tarot_deck_data.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../../state/deck_pack_controller.dart';
import '../digital_table/widgets/deck_picker_sheet.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import 'card_detail_sheet.dart';

/// Pillar 4: offline encyclopedia of all 78 RWS cards + element legend.
class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({super.key});

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  String _query = '';
  String? _filter; // null = all, 'major', or a suit name
  Element? _elementFilter; // null = all, else the tapped element

  List<TarotCard> get _filtered {
    var cards = tarotDeck;
    if (_filter == 'major') {
      cards = cards.where((c) => c.arcana == Arcana.major).toList();
    } else if (_filter != null) {
      final suit = Suit.values.firstWhere((s) => s.name == _filter);
      cards = cards.where((c) => c.suit == suit).toList();
    }
    if (_elementFilter != null) {
      cards = cards.where((c) => c.element == _elementFilter).toList();
    }
    final q = _query.toLowerCase().trim();
    if (q.isNotEmpty) {
      cards = cards
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.keywords.any((k) => k.toLowerCase().contains(q)))
          .toList();
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _filtered;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  'ALMANAC',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${cards.length} OF ${tarotDeck.length}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                _AlmanacDeckPill(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              cursorColor: AppColors.lavender,
              decoration: InputDecoration(
                hintText: 'Search card or keyword',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surface.withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.lavender),
                ),
              ),
            ),
          ),
          _ElementFilterBar(
            active: _elementFilter,
            onToggle: (e) {
              HapticFeedback.selectionClick();
              setState(() => _elementFilter = _elementFilter == e ? null : e);
            },
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All (78)',
                  active: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  label: 'Major (22)',
                  active: _filter == 'major',
                  onTap: () => setState(() => _filter = 'major'),
                ),
                for (final suit in Suit.values)
                  _FilterChip(
                    label:
                        '${suit.label} (${tarotDeck.where((c) => c.suit == suit).length})',
                    active: _filter == suit.name,
                    onTap: () => setState(() => _filter = suit.name),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cards.isEmpty
                ? const Center(
                    child: Text(
                      'No cards match',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.52,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, i) =>
                        _AlmanacTile(card: cards[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlmanacTile extends StatelessWidget {
  const _AlmanacTile({required this.card});

  final TarotCard card;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        CardDetailSheet.show(context, card);
      },
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return TarotCard3DWidget(
                  card: card,
                  isReversed: false,
                  state: SlotState.faceUp,
                  width: w,
                  height: w / 0.6,
                  tilt: false,
                  interactive: false,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.lavender.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.lavender : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppColors.lavender : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// 4 equal-width interactive Element Filter Buttons in one full-width Row
/// (`Expanded` children, 8 px gaps): `△ Fire · ▽ Water · ◇ Air · ▫ Earth`.
/// Tapping an element highlights it with a soft elemental glow and filters
/// the card grid to that element; tapping the active one clears the
/// filter. No static `ELEMENTS` label — the row IS the legend.
class _ElementFilterBar extends StatelessWidget {
  const _ElementFilterBar({required this.active, required this.onToggle});

  final Element? active;
  final ValueChanged<Element> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < Element.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                key: ValueKey('element-filter-${Element.values[i].name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggle(Element.values[i]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active == Element.values[i]
                        ? Element.values[i].accent.withValues(alpha: 0.14)
                        : AppColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active == Element.values[i]
                          ? Element.values[i].accent
                          : AppColors.border,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Element.values[i].glyph,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Element.values[i].accent,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          Element.values[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            color: active == Element.values[i]
                                ? Element.values[i].accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
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

/// Deck pill in the Almanac header — same switcher as the Digital Table.
class _AlmanacDeckPill extends StatelessWidget {
  const _AlmanacDeckPill();

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activePack;
    return GestureDetector(
      onTap: () => DeckPickerSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined,
                size: 12, color: AppColors.lavender),
            const SizedBox(width: 6),
            Text(
              pack.name.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                letterSpacing: 1.4,
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

