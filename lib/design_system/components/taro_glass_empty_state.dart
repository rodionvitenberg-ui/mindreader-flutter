import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_tokens.dart';
import 'taro_glass_button.dart';
import 'taro_glass_panel.dart';

/// Универсальное пустое состояние Tarot Tree (Phase G5): мягкий медальон с
/// иконкой, заголовок, пояснение и опциональная основная кнопка [TaroGlassButton].
class TaroGlassEmptyState extends StatelessWidget {
  const TaroGlassEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.framed = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Оборачивает контент в [TaroGlassPanel].
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                TaroColors.lavender.withValues(alpha: 0.24),
                TaroColors.indigo.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: TaroColors.lavender.withValues(alpha: 0.36),
            ),
          ),
          child: Icon(icon, size: 22, color: TaroColors.lavender),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.label(
            fontSize: 11.5,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: TaroColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                fontSize: 12.5,
                height: 1.45,
                color: TaroColors.textSecondary,
              ),
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          TaroGlassButton(
            label: actionLabel!,
            variant: TaroGlassButtonVariant.primary,
            onPressed: onAction,
          ),
        ],
      ],
    );

    if (framed) {
      return TaroGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: content),
    );
  }
}
