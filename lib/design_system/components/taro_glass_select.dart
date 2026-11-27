import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';
import 'taro_glass_sheet.dart';

/// Один вариант выбора (колода или расклад).
class TaroSelectOption<T> {
  const TaroSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
  final T value;
  final String label;
  final String? subtitle;
}

/// Стеклянный селектор (выбор колоды/расклада) с bottom-sheet списком.
///
/// Переиспользует семантику выбора (`Semantics(button)` + список с `selected`),
/// а не подменяет реальный интерактив неинтерактивным контейнером.
class TaroGlassSelect<T> extends StatelessWidget {
  const TaroGlassSelect({
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    super.key,
  });

  final T value;
  final List<TaroSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? label;

  TaroSelectOption<T> get _current => options.firstWhere(
    (o) => o.value == value,
    orElse: () => options.first,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          button: true,
          label: _current.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _open(context);
            },
            child: TaroGlassSurface(
              radius: TaroRadii.input,
              fillColor: TaroPalette.of(context).surface,
              borderColor: TaroPalette.of(context).borderHairline,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _current.label,
                        style: AppTypography.body(
                          fontSize: 14,
                          color: TaroColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: TaroColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showTaroGlassSheet<T>(
      context: context,
      builder: (context) => _SelectSheet<T>(
        options: options,
        value: value,
        title: label,
      ),
    );
    if (result != null) onChanged(result);
  }
}

class _SelectSheet<T> extends StatelessWidget {
  const _SelectSheet({
    required this.options,
    required this.value,
    this.title,
  });

  final List<TaroSelectOption<T>> options;
  final T value;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return TaroGlassSheet(
      title: title,
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _OptionTile<T>(
              option: option,
              selected: option.value == value,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TaroSelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: option.label,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: AppTypography.body(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? TaroColors.lavender
                            : TaroColors.textPrimary,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: AppTypography.body(
                          fontSize: 12,
                          color: TaroColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check,
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
