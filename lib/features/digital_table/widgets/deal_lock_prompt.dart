import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/taro.dart';
import '../../../state/spread_controller.dart';

void showDealLockPrompt(BuildContext context, SpreadController ctrl) {
  HapticFeedback.heavyImpact();
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          ctrl.dealLockMessage,
          style: const TextStyle(color: TaroColors.textPrimary, fontSize: 12),
        ),
        backgroundColor: TaroColors.surface.withValues(alpha: 0.96),
      ),
    );
}
