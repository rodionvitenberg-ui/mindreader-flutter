import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
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
import '../../core/theme/element_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../design_system/taro.dart';
import '../../state/app_settings_controller.dart';
import '../../state/deck_pack_controller.dart';
import '../../state/spread_controller.dart';
import '../../state/user_profile_controller.dart';
import '../digital_table/widgets/deck_picker_sheet.dart';
import '../digital_table/widgets/lenormand_card_3d_widget.dart';
import '../digital_table/widgets/rune_stone_3d_widget.dart';
import '../digital_table/widgets/tarot_card_3d_widget.dart';
import '../profile/widgets/profile_header.dart';
import '../training/micro_learning_screen.dart';
import 'card_detail_sheet.dart';
import 'deck_cover.dart';
import 'deck_shop_screen.dart';
import 'widgets/zodiac_sky_planetarium.dart';
import 'zodiac_detail_sheet.dart';

/// The four Almanac tabs: three divination systems + the zodiac signs.
enum AlmanacTab { tarot, lenormand, runes, zodiac }

/// Pillar 4: the offline encyclopedia of FOUR systems — 78 tarot cards,
/// 36 Petit Lenormand cards, 24 Elder Futhark runes and the 12 zodiac signs.
class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({
    super.key,
    this.onOpenZodiacHoroscope,
    this.onTabChanged,
  });

  /// Shell callback: opens the sign's Horoscope in the ASTRAL window.
  final ValueChanged<ZodiacSign>? onOpenZodiacHoroscope;

  /// Shell callback: notifies when the active Almanac tab changes so the shell
  /// background stays synced (forest on divination tabs, sky atlas on Zodiac).
  final ValueChanged<AlmanacTab>? onTabChanged;

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

  ZodiacSign? _selectedSign;

  /// The divination system of the current tab (null on the ZODIAC tab).
  DivinationSystem? get _system => switch (_tab) {
    AlmanacTab.tarot => DivinationSystem.tarot,
    AlmanacTab.lenormand => DivinationSystem.lenormand,
    AlmanacTab.runes => DivinationSystem.runes,
    AlmanacTab.zodiac => null,
  };

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
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _search.clear();
    setState(() => _tab = tab);
    widget.onTabChanged?.call(tab);
    final system = _system;
    if (system != null) context.read<SpreadController>().setSystem(system);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppSettingsController>().language;
    final system = _system;
    final topInset = MediaQuery.paddingOf(context).top;
    return SafeArea(
      top: false,
      bottom: false,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final contentHeight = (bounds.maxHeight - topInset).clamp(
              0.0,
              double.infinity,
            );
            final bannerHeight = (contentHeight * 0.22).clamp(88.0, 166.0);
            final tabs = _AlmanacSystemSwitcher(
              tab: _tab,
              onChanged: _selectTab,
              language: language,
            );
            final topBarContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contentHeight < 450)
                  ProfileHeader(child: tabs)
                else ...[
                  ProfileHeader(
                    trailing: system != null
                        ? TaroGlassChip(
                            key: const ValueKey('almanac-training-button'),
                            label: AppStrings.t(language, 'training.entryChip'),
                            icon: Icons.school_outlined,
                            selected: true,
                            compact: true,
                            onTap: () => MicroLearningScreen.open(
                              context,
                              system: system,
                            ),
                          )
                        : null,
                    child: const ProfileHeaderTitle('header.almanac'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: tabs,
                  ),
                ],
              ],
            );
            final topBar = _tab == AlmanacTab.zodiac
                ? Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: ColoredBox(
                      key: const ValueKey('almanac-top-bar'),
                      color: TaroColors.background.withValues(alpha: 0.92),
                      child: topBarContent,
                    ),
                  )
                : ColoredBox(
                    key: const ValueKey('almanac-top-bar'),
                    color: TaroColors.background.withValues(alpha: 0.64),
                    child: Padding(
                      padding: EdgeInsets.only(top: topInset),
                      child: topBarContent,
                    ),
                  );
          final Widget body;
          if (_tab == AlmanacTab.zodiac) {
            final birthDate = context
                .read<UserProfileController?>()
                ?.birthDate;
            final sign = _selectedSign ??= birthDate == null
                ? ZodiacSign.aries
                : almanacBirthSign(birthDate);
            body = ZodiacSkyPlanetarium(
              sign: sign,
              header: const SizedBox.shrink(),
              language: language,
              onChanged: (next) => setState(() => _selectedSign = next),
              onExplore: () => ZodiacDetailSheet.show(
                context,
                zodiacEntryFor(sign),
                onOpenHoroscope: widget.onOpenZodiacHoroscope,
              ),
            );
          } else {
            body = CustomScrollView(
              key: const ValueKey('almanac-scroll'),
              controller: _scroll,
              slivers: [
                if (system != null)
                  PinnedHeaderSliver(
                    child: ColoredBox(
                      color: TaroColors.background.withValues(alpha: 0.64),
                      child: _DeckSelector(system: system, language: language),
                    ),
                  ),
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
                    color: TaroColors.background.withValues(alpha: 0.64),
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
                              color: TaroColors.textPrimary,
                            ),
                            cursorColor: TaroColors.lavender,
                            decoration: InputDecoration(
                              hintText: AppStrings.t(
                                language,
                                'almanac.searchCards',
                              ),
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: TaroColors.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_outlined,
                                size: 18,
                                color: TaroColors.textSecondary,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: TaroColors.surface.withValues(
                                alpha: 0.78,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 9,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: TaroColors.mist.withValues(
                                    alpha: TaroOpacity.border,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: TaroColors.lavender,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ..._filterBars(
                          language,
                          compact: contentHeight < 500,
                        ),
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
          }
          return Column(
            children: [
              topBar,
              Expanded(child: body),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _catalog(AppLanguage language, double width) {
    final cards = _visible;
    final count = cards.length;
    if (count == 0) {
      return SliverToBoxAdapter(
        child: TaroGlassEmptyState(
          icon: Icons.search_off_outlined,
          title: AppStrings.t(language, 'almanac.noCards'),
        ),
      );
    }
    final columns = ((width - 24) ~/ 112).clamp(2, 8);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.54,
        ),
        itemCount: count,
        itemBuilder: (context, i) => _AlmanacTile(card: cards[i]),
      ),
    );
  }

  List<Widget> _filterBars(AppLanguage language, {required bool compact}) {
    String label(String key) => AppStrings.t(language, 'almanac.$key');
    final groups = switch (_tab) {
      AlmanacTab.zodiac => <Widget>[],
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
    return TaroGlassSegmentedControl<AlmanacTab>(
      segments: [
        for (final t in AlmanacTab.values)
          TaroGlassSegment<AlmanacTab>(
            key: ValueKey('almanac-system-${t.name}'),
            value: t,
            label: AppStrings.t(language, 'almanac.${t.name}'),
          ),
      ],
      value: tab,
      onChanged: onChanged,
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
                    color: TaroColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: TaroColors.lavender,
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
            child: DeckCover(
              pack: pack,
              promoUrl: packs.promoImageUrlFor(system, pack),
            ),
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
                      width: w * 0.84,
                      height: w * 0.98,
                      child: RuneStoneView(
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
            style: AppTypography.label(
              fontSize: 9,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: TaroColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row 3 — the 4-element affinity filter bar (Tarot & Runes), styled as a
/// Tarot Tree glass segmented strip while keeping toggle-off semantics.
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
      child: TaroGlassSurface(
        radius: TaroRadii.segment,
        fillColor: TaroColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (var i = 0; i < Element.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: active == Element.values[i],
                    label: AppStrings.t(
                      language,
                      'almanac.${Element.values[i].name}',
                    ),
                    child: GestureDetector(
                      key: ValueKey('element-filter-${Element.values[i].name}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onToggle(Element.values[i]),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: active == Element.values[i]
                              ? Element.values[i].accent.withValues(alpha: 0.20)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            TaroRadii.segment - 3,
                          ),
                          border: active == Element.values[i]
                              ? Border.all(
                                  color: Element.values[i].accent.withValues(
                                    alpha: 0.8,
                                  ),
                                )
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElementIcon(
                                Element.values[i],
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                AppStrings.t(
                                  language,
                                  'almanac.${Element.values[i].name}',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active == Element.values[i]
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active == Element.values[i]
                                      ? TaroColors.textPrimary
                                      : TaroColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TaroGlassChip(
        label: label,
        selected: active,
        compact: true,
        onTap: onTap,
      ),
    );
  }
}
