import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro_glass.dart';
import '../taro_tokens.dart';

/// Стеклянное поле ввода: состояния normal / focus / error.
///
/// Настоящий [TextField] (реальная семантика, `FocusNode`, `onChanged`),
/// обёрнутый в стеклянную поверхность с акцентным бордером.
class TaroGlassInput extends StatefulWidget {
  const TaroGlassInput({
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<TaroGlassInput> createState() => _TaroGlassInputState();
}

class _TaroGlassInputState extends State<TaroGlassInput> {
  final FocusNode _internalFocus = FocusNode();
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? _internalFocus;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = TaroPalette.of(context);
    final hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? TaroColors.error.withValues(alpha: TaroOpacity.borderStrong)
        : _focused
        ? palette.activeOutline
        : palette.borderHairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!.toUpperCase(),
            style: AppTypography.label(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: TaroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TaroGlassSurface(
          radius: TaroRadii.input,
          fillColor: palette.surface,
          borderColor: borderColor,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: TaroColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.body(
                fontSize: 14,
                color: TaroColors.textSecondary.withValues(
                  alpha: TaroOpacity.textMuted,
                ),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: AppTypography.body(
              fontSize: 11.5,
              color: TaroColors.error,
            ),
          ),
        ],
      ],
    );
  }
}
