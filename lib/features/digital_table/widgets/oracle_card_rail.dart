import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dealt_card_slot.dart';
import '../../../core/services/oracle_synthesis_service.dart'
    show orientationWord;
import '../../../design_system/taro.dart';
import '../../../state/spread_controller.dart';
import 'shuffle_physics.dart';
import 'slotted_divination_card.dart';
import '../../../core/l10n/app_strings.dart';

/// The rail and the scrollable dialogue share only the message area's width.
class OracleMessageViewport extends StatefulWidget {
  const OracleMessageViewport({
    super.key,
    required this.showCards,
    required this.readingKey,
    required this.messages,
  });

  final bool showCards;
  final Object readingKey;
  final Widget messages;

  @override
  State<OracleMessageViewport> createState() => _OracleMessageViewportState();
}

class _OracleMessageViewportState extends State<OracleMessageViewport> {
  final _cards = ScrollController();
  bool _expanded = false;

  Object get _storageKey => ('oracle-rail', widget.readingKey);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.maybeOf(context)
                ?.readState(context, identifier: _storageKey)
            as bool? ??
        false;
  }

  void _toggleRail() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(context)
        ?.writeState(context, _expanded, identifier: _storageKey);
  }

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final collapsedWidth = math.min(32.0, bounds.maxWidth * .14);
        final expandedWidth = math.min(76.0, bounds.maxWidth * .22);
        return Row(
          key: const ValueKey('oracle-message-viewport'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showCards)
              AnimatedContainer(
                width: _expanded ? expandedWidth : collapsedWidth,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: _expanded ? expandedWidth : collapsedWidth,
                    maxWidth: _expanded ? expandedWidth : collapsedWidth,
                    child: _buildRail(context),
                  ),
                ),
              ),
            Expanded(child: widget.messages),
          ],
        );
      },
    );
  }

  Widget _buildRail(BuildContext context) {
    final label = _expanded ? AppStrings.g('ui.oracle_card_rail.hide_reading_cards') : AppStrings.g('ui.oracle_card_rail.show_reading_cards');
    final handle = Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        expanded: _expanded,
        child: IconButton(
          key: const ValueKey('oracle-rail-toggle'),
          tooltip: label,
          icon: Icon(
            _expanded ? Icons.chevron_left : Icons.chevron_right,
            size: 20,
            color: TaroColors.lavender,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 44),
          onPressed: _toggleRail,
        ),
      ),
    );
    if (!_expanded) {
      return Align(
        alignment: Alignment.topLeft,
        child: SizedBox(height: 44, child: handle),
      );
    }

    final slots = context
        .watch<SpreadController>()
        .slots
        .where((slot) => slot.card != null)
        .toList();
    return TaroGlassLayer(
      child: TaroGlassSurface(
        radius: 14,
        fillColor: TaroColors.surface.withValues(alpha: .68),
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              SizedBox(height: math.min(44, bounds.maxHeight), child: handle),
              Expanded(
                child: ScrollConfiguration(
                  key: PageStorageKey(('oracle-rail-scroll', widget.readingKey)),
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView.builder(
                    key: const ValueKey('oracle-card-rail'),
                    controller: _cards,
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      final faceUp = slot.state == SlotState.faceUp;
                      final name = faceUp ? slot.card!.name : AppStrings.g('table.faceDownCard');
                      final description = faceUp
                          ? '$name, ${orientationWord(slot)}'
                          : name;
                      return Padding(
                        key: ValueKey('oracle-rail-slot-${slot.index}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          button: true,
                          label: '${slot.index + 1}. ${slot.role}. $description',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _preview(context, slot, name),
                            child: ExcludeSemantics(
                              child: _OracleCardArt(slot: slot),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _preview(BuildContext context, DealtCardSlot slot, String name) {
    FocusManager.instance.primaryFocus?.unfocus();
    showTaroGlassSheet<void>(
      context: context,
      builder: (_) => TaroGlassSheet(
        key: const ValueKey('oracle-card-preview'),
        title: name,
        subtitle: slot.role,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: deckWidth * 1.25),
            child: _OracleCardArt(slot: slot),
          ),
        ),
      ),
    );
  }
}

/// Reuses the table renderer for the active deck, including the original
/// aspect ratio, face state, and reversed or merkstave orientation.
class _OracleCardArt extends StatelessWidget {
  const _OracleCardArt({required this.slot});

  final DealtCardSlot slot;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: deckWidth / deckHeight,
      child: LayoutBuilder(
        builder: (context, size) => SlottedDivinationCard(
          slot: slot,
          width: size.maxWidth,
          height: size.maxHeight,
          tilt: false,
          interactive: false,
          onFlip: () {},
          onTapFaceUp: () {},
        ),
      ),
    );
  }
}
