import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/data/tarot_deck_data.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
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

  List<TarotCard> get _filtered {
    var cards = tarotDeck;
    if (_filter == 'major') {
      cards = cards.where((c) => c.arcana == Arcana.major).toList();
    } else if (_filter != null) {
      final suit = Suit.values.firstWhere((s) => s.name == _filter);
      cards = cards.where((c) => c.suit == suit).toList();
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
          const _ElementLegendBanner(),
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

/// The 4 elements and how they interact — the reading lens of the app.
class _ElementLegendBanner extends StatelessWidget {
  const _ElementLegendBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Text(
            'ELEMENTS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in Element.values)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            e.glyph,
                            style: TextStyle(
                              fontSize: 11,
                              color: e.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            e.trait,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
