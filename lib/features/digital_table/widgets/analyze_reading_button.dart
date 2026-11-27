import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design_system/taro.dart';
import '../../../state/app_settings_controller.dart';

const double _tableActionButtonHeight = 40;

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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SeerEyeIcon(
            size: 16,
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
          child: SizedBox(
            height: _tableActionButtonHeight,
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
      ),
    );
  }
}

/// Compact glass side action button used on the left (Share) and right (Reset)
/// flanks of the central [AnalyzeReadingButton] above the bottom dock.
class _CompactTableFlankButton extends StatefulWidget {
  const _CompactTableFlankButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onPressed,
    this.accentTint = false,
    this.padding = EdgeInsets.zero,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final bool accentTint;
  final EdgeInsetsGeometry padding;

  @override
  State<_CompactTableFlankButton> createState() =>
      _CompactTableFlankButtonState();
}

class _CompactTableFlankButtonState extends State<_CompactTableFlankButton> {
  bool _pressed = false;

  void _onTap() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final pill = enabled
        ? TaroGlassSurface(
            radius: 22,
            tint: (widget.accentTint ? TaroColors.lavender : TaroColors.surface)
                .withValues(alpha: 0.16),
            visibility: 1.0,
            fillColor: TaroColors.surface,
            borderColor: TaroColors.lavender.withValues(
              alpha: widget.accentTint ? 0.56 : 0.46,
            ),
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
      child: Tooltip(
        message: widget.semanticLabel,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            onTap: enabled ? _onTap : null,
            child: SizedBox(
              width: 48,
              height: _tableActionButtonHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: pill),
                  AnimatedScale(
                    duration: TaroMotion.fast,
                    curve: Curves.easeOutCubic,
                    scale: enabled && _pressed ? 0.94 : 1.0,
                    child: AnimatedOpacity(
                      duration: TaroMotion.fast,
                      opacity: enabled && _pressed ? .80 : 1,
                      child: Icon(
                        widget.icon,
                        size: 17,
                        color: enabled
                            ? TaroColors.lavender
                            : TaroColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left flank glass button on the Digital Table Step 2 footer: opens the 9:16
/// editorial Story share studio once the spread cards are revealed.
class ShareSpreadButton extends StatelessWidget {
  const ShareSpreadButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return _CompactTableFlankButton(
      icon: Icons.ios_share_rounded,
      semanticLabel: AppStrings.t(lang, 'share.button'),
      enabled: enabled,
      onPressed: onPressed,
      accentTint: true,
      padding: padding,
    );
  }
}

/// Right flank glass button anchored alongside [AnalyzeReadingButton] above the
/// bottom dock on the Digital Table. Resets the active spread once all initial
/// cards or runes have been dealt.
class ResetTableButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lang = context.watch<AppSettingsController>().language;
    return _CompactTableFlankButton(
      icon: Icons.refresh_rounded,
      semanticLabel: AppStrings.t(lang, 'table.tapToReset'),
      enabled: enabled,
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      padding: padding,
    );
  }
}
