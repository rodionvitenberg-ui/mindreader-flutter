import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_tokens.dart';

/// Тон уведомления [showTaroGlassSnackbar] / [TaroGlassToast].
enum TaroGlassSnackbarTone { info, success, warning, error }

/// Показывает стеклянное всплывающее уведомление Tarot Tree (Phase G5).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showTaroGlassSnackbar(
  BuildContext context, {
  required String message,
  TaroGlassSnackbarTone tone = TaroGlassSnackbarTone.info,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      content: TaroGlassToast(
        message: message,
        tone: tone,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
      ),
    ),
  );
}

/// Карточка-тост Tarot Tree (Phase G5): мягкое свечение, hairline-бордер,
/// семантика `liveRegion: true`, touch-target кнопки действия ≥ 44 px.
class TaroGlassToast extends StatelessWidget {
  const TaroGlassToast({
    required this.message,
    this.tone = TaroGlassSnackbarTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final TaroGlassSnackbarTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _accent => switch (tone) {
    TaroGlassSnackbarTone.info => TaroColors.lavender,
    TaroGlassSnackbarTone.success => TaroColors.dawn,
    TaroGlassSnackbarTone.warning => TaroColors.rose,
    TaroGlassSnackbarTone.error => TaroColors.error,
  };

  IconData get _defaultIcon => switch (tone) {
    TaroGlassSnackbarTone.info => Icons.auto_awesome_outlined,
    TaroGlassSnackbarTone.success => Icons.check_circle_outline,
    TaroGlassSnackbarTone.warning => Icons.info_outline,
    TaroGlassSnackbarTone.error => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TaroColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(TaroRadii.button),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          boxShadow: TaroGlow.soft(
            accent,
            alpha: 0.22,
            blur: 20,
            offset: const Offset(0, 6),
          ),
        ),
        child: Row(
          children: [
            Icon(icon ?? _defaultIcon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(
                  fontSize: 13,
                  height: 1.4,
                  color: TaroColors.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: actionLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          actionLabel!.toUpperCase(),
                          style: AppTypography.label(
                            fontSize: 10,
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
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
    );
  }
}
