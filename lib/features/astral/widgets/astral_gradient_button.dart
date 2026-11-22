import 'package:flutter/material.dart';

import '../../../design_system/taro.dart';

/// Primary Tarot Tree glass CTA shared across ASTRAL screens (Phase G5:
/// migrated to [TaroGlassButton] primary variant).
class AstralGradientButton extends StatelessWidget {
  const AstralGradientButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TaroGlassLayer(
      child: SizedBox(
        width: double.infinity,
        child: TaroGlassButton(
          label: label,
          variant: TaroGlassButtonVariant.primary,
          onPressed: onTap,
        ),
      ),
    );
  }
}
