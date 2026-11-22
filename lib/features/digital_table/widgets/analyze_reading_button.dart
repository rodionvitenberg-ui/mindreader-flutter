import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

/// Compact glass navigation button anchored above the bottom dock on the
/// Digital Table. Opens the Oracle screen without triggering synthesis or
/// mutating reading state.
class AnalyzeReadingButton extends StatefulWidget {
  const AnalyzeReadingButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final bool enabled;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;

  @override
  State<AnalyzeReadingButton> createState() => _AnalyzeReadingButtonState();
}

class _AnalyzeReadingButtonState extends State<AnalyzeReadingButton> {
  bool _pressed = false;

  void _onTap() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    final label = AppStrings.t(lang, 'table.analyzeReading');
    final enabled = widget.enabled;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: enabled ? TaroColors.lavender : TaroColors.textDisabled,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: AppTypography.label(
                  fontSize: 11,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? TaroColors.textPrimary
                      : TaroColors.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final pill = enabled
        ? TaroGlassSurface(
            radius: 22,
            tint: TaroColors.lavender.withValues(alpha: 0.16),
            // Keep visibility at 1.0 on press so tapping or starting a swipe
            // never spawns a separate SeededBackdropPassLayer (prevents dark
            // flash on Impeller OpenGLES).
            visibility: 1.0,
            fillColor: TaroColors.surface,
            borderColor: TaroColors.lavender.withValues(alpha: 0.65),
            glow: TaroGlow.soft(TaroColors.lavender, alpha: 0.24, blur: 14),
            child: const SizedBox.expand(),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: TaroColors.surface.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                width: 1.0,
              ),
            ),
          );

    return Padding(
      padding: widget.padding,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? _onTap : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: pill),
              AnimatedScale(
                duration: TaroMotion.fast,
                curve: Curves.easeOutCubic,
                scale: enabled && _pressed ? 0.97 : 1.0,
                child: AnimatedOpacity(
                  duration: TaroMotion.fast,
                  opacity: enabled && _pressed ? .84 : 1,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Companion glass button anchored alongside [AnalyzeReadingButton] above the
/// bottom dock on the Digital Table. Resets the active spread once all initial
/// cards or runes have been dealt.
class ResetTableButton extends StatefulWidget {
  const ResetTableButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;

  @override
  State<ResetTableButton> createState() => _ResetTableButtonState();
}

class _ResetTableButtonState extends State<ResetTableButton> {
  bool _pressed = false;

  void _onTap() {
    if (!widget.enabled) return;
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.g('table.tapToReset');
    final enabled = widget.enabled;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh_rounded,
            size: 14,
            color: enabled ? TaroColors.lavender : TaroColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: AppTypography.label(
                  fontSize: 10.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? TaroColors.lavender
                      : TaroColors.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final pill = enabled
        ? TaroGlassSurface(
            radius: 22,
            tint: TaroColors.surface.withValues(alpha: 0.16),
            visibility: 1.0,
            fillColor: TaroColors.surface,
            borderColor: TaroColors.lavender.withValues(alpha: 0.50),
            child: const SizedBox.expand(),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: TaroColors.surface.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: TaroColors.mist.withValues(alpha: TaroOpacity.border),
                width: 1.0,
              ),
            ),
          );

    return Padding(
      padding: widget.padding,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? _onTap : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: pill),
              AnimatedScale(
                duration: TaroMotion.fast,
                curve: Curves.easeOutCubic,
                scale: enabled && _pressed ? 0.97 : 1.0,
                child: AnimatedOpacity(
                  duration: TaroMotion.fast,
                  opacity: enabled && _pressed ? .84 : 1,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
