import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/lenormand_data.dart';
import '../../core/data/runes_data.dart';
import '../../core/data/tarot_deck_data.dart';
import '../../core/data/zodiac_almanac_data.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/lenormand_card.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/rune_stone.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import '../digital_table/widgets/deck_picker_sheet.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import '../profile/widgets/profile_header.dart';
import 'card_detail_sheet.dart';
import 'zodiac_detail_sheet.dart';

/// The four Almanac tabs: three divination systems + the zodiac signs.
enum AlmanacTab { tarot, lenormand, runes, zodiac }

extension AlmanacTabX on AlmanacTab {
  String get label => switch (this) {
    AlmanacTab.tarot => 'TAROT',
    AlmanacTab.lenormand => 'LENORMAND',
    AlmanacTab.runes => 'RUNES',
    AlmanacTab.zodiac => 'ZODIAC',
  };
}

/// Pillar 4: the offline encyclopedia of FOUR systems — 78 tarot cards,
/// 36 Petit Lenormand cards, 24 Elder Futhark runes and the 12 zodiac signs.
/// Row 1 hosts the 4-tab switcher, Row 2 the search bar + pack pill,
/// Rows 3/4 the context-aware per-system filters.
class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({super.key, this.onOpenZodiacHoroscope});

  /// Shell callback: opens the sign's Horoscope in the ASTRAL window.
  final ValueChanged<ZodiacSign>? onOpenZodiacHoroscope;

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  String _query = '';
  AlmanacTab _tab = AlmanacTab.tarot;

  // Tarot filters: arcana/suit + element.
  String? _filter; // null = all, 'major', or a suit name
  Element? _elementFilter;

  // Lenormand filter: playing-card suit (null = all).
  PlayingCardSuit? _lenormandSuitFilter;

  // Rune filters: element + aett.
  Element? _runeElementFilter;
  RuneAett? _runeAettFilter;

  // Zodiac filters: element + modality.
  Element? _zodiacElementFilter;
  ZodiacModality? _zodiacModalityFilter;

  /// The divination system of the current tab (null on the ZODIAC tab).
  DivinationSystem? get _system => switch (_tab) {
        AlmanacTab.tarot => DivinationSystem.tarot,
        AlmanacTab.lenormand => DivinationSystem.lenormand,
        AlmanacTab.runes => DivinationSystem.runes,
        AlmanacTab.zodiac => null,
      };

  List<ZodiacSignEntry> get _visibleZodiac {
    final query = _query.toLowerCase().trim();
    var entries = zodiacAlmanac;
    if (_zodiacElementFilter != null) {
      entries = [
        for (final e in entries)
          if (e.element == _zodiacElementFilter) e,
      ];
    }
    if (_zodiacModalityFilter != null) {
      entries = [
        for (final e in entries)
          if (e.modality == _zodiacModalityFilter) e,
      ];
    }
    if (query.isNotEmpty) {
      entries = [
        for (final e in entries)
          if (e.name.toLowerCase().contains(query) ||
              e.keywords.any((k) => k.toLowerCase().contains(query)) ||
              e.archetype.toLowerCase().contains(query))
            e,
      ];
    }
    return entries;
  }

  List<DivinationCard> get _visible {
    final query = _query.toLowerCase().trim();
    switch (_tab) {
      case AlmanacTab.zodiac:
        return const [];
      case AlmanacTab.tarot:
        var cards = [for (final c in tarotDeck) TarotDivinationCard(c)];
        if (_filter == 'major') {
          cards = [
            for (final c in cards)
              if (c.card.arcana == Arcana.major) c,
          ];
        } else if (_filter != null) {
          final suit = Suit.values.firstWhere((s) => s.name == _filter);
          cards = [
            for (final c in cards)
              if (c.card.suit == suit) c,
          ];
        }
        if (_elementFilter != null) {
          cards = [for (final c in cards) if (c.element == _elementFilter) c];
        }
        if (query.isNotEmpty) {
          cards = [
            for (final c in cards)
              if (c.name.toLowerCase().contains(query) ||
                  c.keywords.any((k) => k.toLowerCase().contains(query)))
                c,
          ];
        }
        return cards;
      case AlmanacTab.lenormand:
        var cards = [
          for (final c in lenormandDeck) LenormandDivinationCard(c),
        ];
        if (_lenormandSuitFilter != null) {
          cards = [
            for (final c in cards)
              if (c.card.playingCard ==
                  _lenormandSuitFilter)
                c,
          ];
        }
        if (query.isNotEmpty) {
          cards = [
            for (final c in cards)
              if (c.name.toLowerCase().contains(query) ||
                  c.shortLabel.toLowerCase().contains(query) ||
                  c.keywords.any((k) => k.toLowerCase().contains(query)))
                c,
          ];
        }
        return cards;
      case AlmanacTab.runes:
        var cards = [for (final r in elderFuthark) RuneDivinationCard(r)];
        if (_runeElementFilter != null) {
          cards = [for (final c in cards) if (c.element == _runeElementFilter) c];
        }
        if (_runeAettFilter != null) {
          cards = [
            for (final c in cards)
              if (c.stone.aett == _runeAettFilter) c,
          ];
        }
        if (query.isNotEmpty) {
          cards = [
            for (final c in cards)
              if (c.name.toLowerCase().contains(query) ||
                  c.keywords.any((k) => k.toLowerCase().contains(query)))
                c,
          ];
        }
        return cards;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _visible;
    final zodiacEntries = _visibleZodiac;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileHeader(child: ProfileHeaderTitle('header.almanac')),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.60,
              ),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    // System switcher above the search and filters.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Center(
                        child: _AlmanacSystemSwitcher(
                          tab: _tab,
                          onChanged: (t) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _tab = t;
                              _filter = null;
                              _elementFilter = null;
                              _lenormandSuitFilter = null;
                              _runeElementFilter = null;
                              _runeAettFilter = null;
                              _zodiacElementFilter = null;
                              _zodiacModalityFilter = null;
                            });
                            // Keep the Digital Table in sync with the browsing system;
                            // ZODIAC is not a divination system, so it is untouched.
                            final s = _system;
                            if (s != null) {
                              context.read<SpreadController>().setSystem(s);
                            }
                          },
                        ),
                      ),
                    ),
                    // Row 2 — search bar (~62%) + the pack pill directly to its right.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              key: const ValueKey('almanac-search'),
                              onChanged: (v) => setState(() => _query = v),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              cursorColor: AppColors.lavender,
                              decoration: InputDecoration(
                                hintText: _tab == AlmanacTab.zodiac
                                    ? 'Search sign, keyword or archetype'
                                    : 'Search card, keyword or glyph',
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
                                fillColor: AppColors.surface.withValues(
                                  alpha: 0.6,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.lavender,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_system != null)
                            _AlmanacPackPill(system: _system!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rows 3/4 — context-aware per-system filter bars.
                    ..._filterBars(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tab == AlmanacTab.zodiac
                  ? _zodiacGrid(zodiacEntries)
                  : cards.isEmpty
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
                      itemBuilder: (context, i) => _AlmanacTile(card: cards[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _filterBars() {
    switch (_tab) {
      case AlmanacTab.zodiac:
        return [
          _ElementFilterBar(
            active: _zodiacElementFilter,
            onToggle: (e) {
              HapticFeedback.selectionClick();
              setState(() =>
                  _zodiacElementFilter = _zodiacElementFilter == e ? null : e);
            },
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All (12)',
                  active: _zodiacModalityFilter == null,
                  onTap: () => setState(() => _zodiacModalityFilter = null),
                ),
                for (final m in ZodiacModality.values)
                  _FilterChip(
                    key: ValueKey('zodiac-modality-${m.name}'),
                    label: '${_modalityLabel(m)} '
                        '(${zodiacEntriesForModality(m).length})',
                    active: _zodiacModalityFilter == m,
                    onTap: () => setState(() => _zodiacModalityFilter = m),
                  ),
              ],
            ),
          ),
        ];
      case AlmanacTab.tarot:
        return [
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
        ];
      case AlmanacTab.lenormand:
        return [
          const SizedBox(height: 2),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All (36)',
                  active: _lenormandSuitFilter == null,
                  onTap: () =>
                      setState(() => _lenormandSuitFilter = null),
                ),
                for (final suit in PlayingCardSuit.values)
                  _FilterChip(
                    label:
                        '${suit.glyph} ${suit.label} (${lenormandDeck.where((c) => c.playingCard == suit).length})',
                    active: _lenormandSuitFilter == suit,
                    onTap: () =>
                        setState(() => _lenormandSuitFilter = suit),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'LENORMAND IS READ IN PAIRS · ALWAYS UPRIGHT · '
              'TIMING: ${_timingLine()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                letterSpacing: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ];
      case AlmanacTab.runes:
        return [
          _ElementFilterBar(
            active: _runeElementFilter,
            onToggle: (e) {
              HapticFeedback.selectionClick();
              setState(() =>
                  _runeElementFilter = _runeElementFilter == e ? null : e);
            },
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All (24)',
                  active: _runeAettFilter == null,
                  onTap: () => setState(() => _runeAettFilter = null),
                ),
                for (final aett in RuneAett.values)
                  _FilterChip(
                    label:
                        '${aett.title} (${elderFuthark.where((r) => r.aett == aett).length})',
                    active: _runeAettFilter == aett,
                    onTap: () => setState(() => _runeAettFilter = aett),
                  ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _zodiacGrid(List<ZodiacSignEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No signs match',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) => _ZodiacTile(
        key: ValueKey('zodiac-tile-${entries[i].sign.name}'),
        entry: entries[i],
        onOpen: () => ZodiacDetailSheet.show(
          context,
          entries[i],
          onOpenHoroscope: widget.onOpenZodiacHoroscope,
        ),
      ),
    );
  }

  String _modalityLabel(ZodiacModality m) => switch (m) {
        ZodiacModality.cardinal => 'Cardinal',
        ZodiacModality.fixed => 'Fixed',
        ZodiacModality.mutable => 'Mutable',
      };

  String _timingLine() {
    final cards = _visible;
    if (cards.isEmpty) return '—';
    final first = (cards.first as LenormandDivinationCard).card;
    return first.timing.toUpperCase();
  }
}

/// Row 1 — the 4-tab switcher, synced with the Digital Table for the three
/// divination systems (ZODIAC is an encyclopedia, not a spread system).
class _AlmanacSystemSwitcher extends StatelessWidget {
  const _AlmanacSystemSwitcher({required this.tab, required this.onChanged});

  final AlmanacTab tab;
  final ValueChanged<AlmanacTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final t in AlmanacTab.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('almanac-system-${t.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(t),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: tab == t
                        ? AppColors.lavender.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t.label,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: tab == t
                            ? AppColors.lavender
                            : AppColors.textMuted,
                      ),
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

/// Row 2 right — the pack/style selector pill for the active system.
class _AlmanacPackPill extends StatelessWidget {
  const _AlmanacPackPill({required this.system});

  final DivinationSystem system;

  @override
  Widget build(BuildContext context) {
    final packs = context.watch<DeckPackController>();
    final label = switch (system) {
      DivinationSystem.tarot => packs.activePack.name.toUpperCase(),
      DivinationSystem.lenormand =>
        packs.activeLenormandPack.name.toUpperCase(),
      DivinationSystem.runes => packs.activeRunePack.name.toUpperCase(),
    };
    return GestureDetector(
      key: const ValueKey('almanac-pack-pill'),
      onTap: () => DeckPickerSheet.show(context, system: system),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(system.packGlyph, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lavender,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 13,
              color: AppColors.lavender,
            ),
          ],
        ),
      ),
    );
  }
}

/// One almanac grid tile — rendered by its own system's widget.
class _AlmanacTile extends StatelessWidget {
  const _AlmanacTile({required this.card});

  final DivinationCard card;

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
                return switch (card.system) {
                  DivinationSystem.tarot => TarotCard3DWidget(
                      card: (card as TarotDivinationCard).card,
                      isReversed: false,
                      state: SlotState.faceUp,
                      width: w,
                      height: w * 360 / 220,
                      tilt: false,
                      interactive: false,
                    ),
                  DivinationSystem.lenormand => LenormandCard3DWidget(
                      card: (card as LenormandDivinationCard).card,
                      isReversed: false,
                      state: SlotState.faceUp,
                      width: w,
                      height: w * 360 / 220,
                      tilt: false,
                      interactive: false,
                    ),
                  DivinationSystem.runes => Center(
                      child: SizedBox(
                        width: w * 0.8,
                        height: w * 0.94,
                        child: CustomPaint(
                          painter: RuneStonePainter(
                            stone:
                                (card as RuneDivinationCard).stone,
                            pack: context
                                .watch<DeckPackController>()
                                .activeRunePack,
                            faceUp: true,
                            ignite: 1,
                            seed: card.id + 5,
                          ),
                        ),
                      ),
                    ),
                };
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row 3 — the 4-element affinity filter bar (Tarot & Runes).
class _ElementFilterBar extends StatelessWidget {
  const _ElementFilterBar({required this.active, required this.onToggle});

  final Element? active;
  final ValueChanged<Element> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.lavender.withValues(alpha: 0.16)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.lavender : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.lavender : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// One bespoke obsidian-lavender zodiac card.
class _ZodiacTile extends StatelessWidget {
  const _ZodiacTile({required this.entry, required this.onOpen, super.key});

  final ZodiacSignEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final element = entry.element;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onOpen();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: element.accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry.glyph,
                  style: TextStyle(fontSize: 26, color: element.accent),
                ),
                const Spacer(),
                Text(
                  element.glyph,
                  style: TextStyle(fontSize: 12, color: element.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.05,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.dateRange,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7.5,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              entry.keywords.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                height: 1.3,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.modality.name.toUpperCase()} · '
              '${entry.rulersLabel.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                letterSpacing: 0.8,
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

