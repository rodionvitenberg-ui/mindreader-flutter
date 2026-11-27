import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';
import '../../core/l10n/app_strings.dart';

/// Открывает модальный стеклянный bottom-sheet [TaroGlassSheet].
Future<T?> showTaroGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: builder,
  );
}

/// Универсальный стеклянный bottom-sheet (Phase G3): drag-handle + контент.
///
/// Создаёт собственный [TaroGlassLayer] (один на модальный экран, так как
/// `showModalBottomSheet` рисуется в root `Overlay` поверх `MainNavigationShell`).
/// Учитывает `SafeArea` и высоту клавиатуры.
class TaroGlassSheet extends StatelessWidget {
  const TaroGlassSheet({
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 24),
    this.showDragHandle = true,
    this.scrollable = true,
    this.avoidKeyboard = true,
    this.mode = TaroGlassMode.auto,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;
  final bool scrollable;
  final bool avoidKeyboard;
  final TaroGlassMode mode;

  @override
  Widget build(BuildContext context) {
    final bottomInset = avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle) ...[
          Center(
            child: Semantics(
              label: AppStrings.g('ui.taro_glass_sheet.drag_handle'),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TaroColors.mist.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (title != null) ...[
          Text(
            title!,
            style: Theme.of(context).textTheme.displayMedium ??
                AppTypography.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: TaroColors.textPrimary,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.label(
                fontSize: 9,
                letterSpacing: 0.9,
                color: TaroColors.lavender,
              ),
            ),
          ],
          const SizedBox(height: 18),
        ],
        child,
      ],
    );

    final content = SafeArea(
      top: false,
      child: scrollable
          ? SingleChildScrollView(padding: padding, child: body)
          : Padding(padding: padding, child: body),
    );

    final palette = TaroPalette.of(context);
    final sheetFill = palette.isMoonlit ? palette.surface : TaroColors.background;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset + 8),
      child: TaroGlassLayer(
        mode: mode,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TaroRadii.pill),
          child: Stack(
            children: [
              Positioned.fill(
                child: TaroGlassSurface(
                  radius: TaroRadii.pill,
                  tint: palette.isMoonlit
                      ? palette.glassTint
                      : TaroColors.background.withValues(alpha: 0.62),
                  fillColor: sheetFill,
                  borderColor: palette.isMoonlit
                      ? palette.borderHairline
                      : TaroColors.mist.withValues(
                          alpha: TaroOpacity.borderStrong,
                        ),
                  glow: TaroGlow.soft(
                    palette.lanternGlow,
                    alpha: 0.22,
                    blur: 32,
                    offset: const Offset(0, -6),
                  ),
                  child: palette.isMoonlit
                      ? const SizedBox.expand()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: TaroColors.background.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(TaroRadii.pill),
                          ),
                        ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );
  }
}
