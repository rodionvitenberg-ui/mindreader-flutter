import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Live captions for the Oracle's spoken answer. Long answers stay inside a
/// bounded, internally-scrollable box ("длинный ответ — компактные
/// прокручиваемые субтитры") so the overlay never grows to cover the camera
/// viewfinder. Renders nothing when there is no caption.
class OracleSubtitles extends StatelessWidget {
  const OracleSubtitles({super.key, required this.text, this.maxLines = 3});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxLines * 18.0),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: AppTypography.body(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
