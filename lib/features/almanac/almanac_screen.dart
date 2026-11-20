import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/data/lenormand_data.dart';
import '../../core/data/runes_data.dart';
import '../../core/data/tarot_deck_data.dart';
import '../../core/data/zodiac_almanac_data.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/dealt_card_slot.dart';
import '../../core/models/divination_card.dart';
import '../../core/models/divination_system.dart';
import '../../core/models/lenormand_card.dart';
import '../../core/models/natal_chart.dart';
import '../../core/models/rune_stone.dart';
import '../../core/models/tarot_card_model.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_settings_controller.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import '../digital_table/widgets/deck_picker_sheet.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import '../profile/widgets/profile_header.dart';
import 'card_detail_sheet.dart';
import 'deck_cover.dart';
import 'deck_shop_screen.dart';
import 'zodiac_detail_sheet.dart';

/// The four Almanac tabs: three divination systems + the zodiac signs.
enum AlmanacTab { tarot, lenormand, runes, zodiac }

/// Pillar 4: the offline encyclopedia of FOUR systems — 78 tarot cards,
/// 36 Petit Lenormand cards, 24 Elder Futhark runes and the 12 zodiac signs.
class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({super.key, this.onOpenZodiacHoroscope});

  /// Shell callback: opens the sign's Horoscope in the ASTRAL window.
  final ValueChanged<ZodiacSign>? onOpenZodiacHoroscope;

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String get _query => _search.text;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  AlmanacTab _tab = AlmanacTab.tarot;

  // Tarot filters: arcana/suit + element.
  String? _filter; // null = all, 'major', or a suit name
  final _elements = <AlmanacTab, Element?>{};

  // Lenormand filter: playing-card suit (null = all).
  PlayingCardSuit? _lenormandSuitFilter;

  // Rune filters: element + aett.
  RuneAett? _runeAettFilter;

  // Zodiac filters: element + modality.
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
    if (_elements[AlmanacTab.zodiac] != null) {
      entries = [
        for (final e in entries)
          if (e.element == _elements[AlmanacTab.zodiac]) e,
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
        if (_elements[AlmanacTab.tarot] != null) {
          cards = [
            for (final c in cards)
              if (c.element == _elements[AlmanacTab.tarot]) c,
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
      case AlmanacTab.lenormand:
        var cards = [for (final c in lenormandDeck) LenormandDivinationCard(c)];
        if (_lenormandSuitFilter != null) {
          cards = [
            for (final c in cards)
              if (c.card.playingCard == _lenormandSuitFilter) c,
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
        if (_elements[AlmanacTab.runes] != null) {
          cards = [
            for (final c in cards)
              if (c.element == _elements[AlmanacTab.runes]) c,
          ];
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

  void _selectTab(AlmanacTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    _scroll.jumpTo(0);
    _search.clear();
    setState(() => _tab = tab);
    final system = _system;
    if (system != null) context.read<SpreadController>().setSystem(system);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppSettingsController>().language;
    final system = _system;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final bannerHeight = (bounds.maxHeight * 0.22).clamp(88.0, 166.0);
          final tabs = _AlmanacSystemSwitcher(
            tab: _tab,
            onChanged: _selectTab,
            language: language,
          );
          final navigation = ColoredBox(
            color: AppColors.canvas,
            child: Column(
              children: [
                if (bounds.maxHeight < 450)
                  ProfileHeader(child: tabs)
                else ...[
                  const ProfileHeader(
                    child: ProfileHeaderTitle('header.almanac'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: tabs,
                  ),
                ],
                if (system != null)
                  _DeckSelector(system: system, language: language),
              ],
            ),
          );
          return CustomScrollView(
            key: const ValueKey('almanac-scroll'),
            controller: _scroll,
            slivers: [
              PinnedHeaderSliver(child: navigation),
              if (system != null)
                SliverToBoxAdapter(
                  child: _DeckBanner(
                    system: system,
                    height: bannerHeight,
                    language: language,
                  ),
                ),
              PinnedHeaderSliver(
                child: ColoredBox(
                  key: const ValueKey('almanac-filters'),
                  color: AppColors.canvas,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: TextField(
                          key: const ValueKey('almanac-search'),
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          cursorColor: AppColors.lavender,
                          decoration: InputDecoration(
                            hintText: AppStrings.t(
                              language,
                              system == null
                                  ? 'almanac.searchSigns'
                                  : 'almanac.searchCards',
                            ),
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_outlined,
                              size: 18,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.surface,
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 9,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.lavender,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ..._filterBars(language, compact: bounds.maxHeight < 500),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
              _catalog(language, bounds.maxWidth),
              if (system != null)
                // Even a one-card search can scroll the banner fully offscreen.
                SliverLayoutBuilder(
                  builder: (_, constraints) {
                    final fill =
                        constraints.viewportMainAxisExtent +
                        bannerHeight -
                        constraints.precedingScrollExtent;
                    return SliverToBoxAdapter(
                      child: SizedBox(height: fill > 0 ? fill : 0),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _catalog(AppLanguage language, double width) {
    final zodiac = _tab == AlmanacTab.zodiac;
    final signs = zodiac ? _visibleZodiac : const <ZodiacSignEntry>[];
    final cards = zodiac ? const <DivinationCard>[] : _visible;
    final count = zodiac ? signs.length : cards.length;
    if (count == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              AppStrings.t(
                language,
                zodiac ? 'almanac.noSigns' : 'almanac.noCards',
              ),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }
    final columns = zodiac
        ? (width ~/ 170).clamp(2, 6)
        : ((width - 24) ~/ 112).clamp(2, 8);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: zodiac ? 0.8 : 0.54,
        ),
        itemCount: count,
        itemBuilder: (context, i) {
          if (!zodiac) return _AlmanacTile(card: cards[i]);
          final entry = signs[i];
          return _ZodiacTile(
            key: ValueKey('zodiac-tile-${entry.sign.name}'),
            entry: entry,
            onOpen: () => ZodiacDetailSheet.show(
              context,
              entry,
              onOpenHoroscope: widget.onOpenZodiacHoroscope,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _filterBars(AppLanguage language, {required bool compact}) {
    String label(String key) => AppStrings.t(language, 'almanac.$key');
    final groups = switch (_tab) {
      AlmanacTab.zodiac => [
        _FilterChip(
          label: '${label('all')} (12)',
          active: _zodiacModalityFilter == null,
          onTap: () => setState(() => _zodiacModalityFilter = null),
        ),
        for (final m in ZodiacModality.values)
          _FilterChip(
            key: ValueKey('zodiac-modality-${m.name}'),
            label:
                '${label(m.name)} '
                '(${zodiacEntriesForModality(m).length})',
            active: _zodiacModalityFilter == m,
            onTap: () => setState(() => _zodiacModalityFilter = m),
          ),
      ],
      AlmanacTab.tarot => [
        _FilterChip(
          label: '${label('all')} (78)',
          active: _filter == null,
          onTap: () => setState(() => _filter = null),
        ),
        _FilterChip(
          label: '${label('major')} (22)',
          active: _filter == 'major',
          onTap: () => setState(() => _filter = 'major'),
        ),
        for (final suit in Suit.values)
          _FilterChip(
            label:
                '${label(suit.name)} (${tarotDeck.where((c) => c.suit == suit).length})',
            active: _filter == suit.name,
            onTap: () => setState(() => _filter = suit.name),
          ),
      ],
      AlmanacTab.lenormand => [
        _FilterChip(
          label: '${label('all')} (36)',
          active: _lenormandSuitFilter == null,
          onTap: () => setState(() => _lenormandSuitFilter = null),
        ),
        for (final suit in PlayingCardSuit.values)
          _FilterChip(
            label:
                '${suit.glyph} ${label(suit.name)} (${lenormandDeck.where((c) => c.playingCard == suit).length})',
            active: _lenormandSuitFilter == suit,
            onTap: () => setState(() => _lenormandSuitFilter = suit),
          ),
      ],
      AlmanacTab.runes => [
        _FilterChip(
          label: '${label('all')} (24)',
          active: _runeAettFilter == null,
          onTap: () => setState(() => _runeAettFilter = null),
        ),
        for (final aett in RuneAett.values)
          _FilterChip(
            label:
                '${label(aett.name)} (${elderFuthark.where((r) => r.aett == aett).length})',
            active: _runeAettFilter == aett,
            onTap: () => setState(() => _runeAettFilter = aett),
          ),
      ],
    };
    final elements = _tab == AlmanacTab.lenormand
        ? null
        : _ElementFilterBar(
            language: language,
            active: _elements[_tab],
            onToggle: (e) {
              HapticFeedback.selectionClick();
              setState(() => _elements[_tab] = _elements[_tab] == e ? null : e);
            },
          );
    return [
      if (!compact && elements != null) elements,
      SizedBox(
        height: compact ? 40 : 36,
        child: ListView(
          key: ValueKey('almanac-chip-row-${_tab.name}'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: compact && elements != null ? 0 : 16,
          ),
          children: [
            if (compact && elements != null)
              SizedBox(width: 286, child: elements),
            ...groups,
          ],
        ),
      ),
    ];
  }
}

/// Row 1 — the 4-tab switcher, synced with the Digital Table for the three
/// divination systems (ZODIAC is an encyclopedia, not a spread system).
class _AlmanacSystemSwitcher extends StatelessWidget {
  const _AlmanacSystemSwitcher({
    required this.tab,
    required this.onChanged,
    required this.language,
  });

  final AppLanguage language;
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
                      AppStrings.t(language, 'almanac.${t.name}'),
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

class _DeckSelector extends StatelessWidget {
  const _DeckSelector({required this.system, required this.language});

  final DivinationSystem system;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final pack = context.watch<DeckPackController>().activeFor(system);
    return InkWell(
      key: const ValueKey('almanac-pack-pill'),
      onTap: () => DeckPickerSheet.show(context, system: system),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text(
                AppStrings.t(language, 'almanac.deck'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pack.name.toUpperCase(),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: AppColors.lavender,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckBanner extends StatelessWidget {
  const _DeckBanner({
    required this.system,
    required this.height,
    required this.language,
  });
  final DivinationSystem system;
  final double height;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final packs = context.watch<DeckPackController>();
    final pack = packs.activeFor(system);
    return SizedBox(
      key: const ValueKey('deck-banner'),
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: DeckCover(pack: pack, choice: packs.coverFor(pack)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(0xE009090D), Color(0x1809090D)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DeckShopScreen(system: system),
                  ),
                ),
                child: Text(AppStrings.t(language, 'almanac.shopLink')),
              ),
            ),
          ),
        ],
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
                          stone: (card as RuneDivinationCard).stone,
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
  const _ElementFilterBar({
    required this.active,
    required this.onToggle,
    required this.language,
  });

  final AppLanguage language;

  final Element? active;
  final ValueChanged<Element> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
                          AppStrings.t(
                            language,
                            'almanac.${Element.values[i].name}',
                          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
