import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Интерактивный стеклянный чип / пилюля (Phase G4): интеншн-промпты,
/// фильтры, резонанс-пилюли, действия чата.
///
/// По умолчанию использует лёгкую полупрозрачную поверхность на токенах
/// [TaroColors], чтобы группы из 3–8 чипов не исчерпывали лимит в 16 форм на
/// один [TaroGlassLayer]. Для одиночного hero-чипа передайте `useGlass: true`.
class TaroGlassChip extends StatelessWidget {
  const TaroGlassChip({
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.accentColor,
    this.expanded = false,
    this.compact = false,
    this.useGlass = false,
    this.uppercase = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Color? accentColor;

  /// Растянуть чип по ширине родителя (например, в `Row` из `Expanded`).
  final bool expanded;

  /// Компактная высота (для плотных горизонтальных панелей над полем ввода);
  /// по умолчанию интерактивный чип гарантирует touch-target ≥ 44 px.
  final bool compact;

  /// Включает реальный [TaroGlassSurface] для одиночных акцентных пилюль.
  final bool useGlass;
  final bool uppercase;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? TaroColors.lavender;
    final interactive = onTap != null;
    final fg = selected ? accent : TaroColors.textSecondary;
    final display = uppercase ? label.toUpperCase() : label;
    final minH = interactive && !compact ? 44.0 : 0.0;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    final text = Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.label(
        fontSize: compact ? 10.5 : 11.5,
        letterSpacing: uppercase ? 0.7 : 0.2,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? accent : TaroColors.textPrimary,
      ),
    );

    final inner = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 13 : 15, color: fg),
          const SizedBox(width: 6),
        ],
        if (expanded)
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: text),
          )
        else
          Flexible(child: text),
      ],
    );

    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Padding(padding: pad, child: Center(widthFactor: expanded ? null : 1.0, child: inner)),
    );

    final surface = useGlass
        ? TaroGlassSurface(
            radius: TaroRadii.chip,
            tint: selected
                ? accent.withValues(alpha: 0.22)
                : TaroColors.mist.withValues(alpha: 0.08),
            fillColor: TaroColors.surface,
            borderColor: selected
                ? accent.withValues(alpha: TaroOpacity.borderStrong)
                : TaroColors.mist.withValues(alpha: TaroOpacity.border),
            child: body,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.20)
                  : TaroColors.surface.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(TaroRadii.chip),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.85)
                    : TaroColors.mist.withValues(alpha: TaroOpacity.border),
                width: selected ? 1.2 : 1.0,
              ),
              boxShadow: selected
                  ? TaroGlow.soft(accent, alpha: 0.18, blur: 12)
                  : null,
            ),
            child: body,
          );

    if (!interactive) {
      return Semantics(
        label: semanticLabel ?? label,
        child: surface,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: surface,
      ),
    );
  }
}

/// Статический бейдж-пилюля Tarot Tree (Phase G4): источник расклада, стихия,
/// статус сессии (`PHYSICAL SYNC`, `DIGITAL`, `PRO ∞`).
class TaroGlassPill extends StatelessWidget {
  const TaroGlassPill({
    required this.label,
    this.icon,
    this.accentColor,
    this.accent = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? accentColor;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color =
        accentColor ?? (accent ? TaroColors.lavender : TaroColors.textSecondary);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: accent || accentColor != null ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
