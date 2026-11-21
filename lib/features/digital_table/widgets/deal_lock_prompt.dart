import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/taro.dart';
import '../../../state/spread_controller.dart';

/// The subtle haptic/visual prompt shown when the reader tries to draw
/// from a locked deck (base spread complete, no clarifier armed) or hits
/// the hard 10-card ceiling. One shared implementation for the tactile
/// deck widget and the overview mini-deck.
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
          ctrl.isClarifierLimitReached
              ? SpreadController.maxTableCardsPrompt
              : SpreadController.dealLockedPrompt,
          style: const TextStyle(color: TaroColors.textPrimary, fontSize: 12),
        ),
        backgroundColor: TaroColors.surface.withValues(alpha: 0.96),
      ),
    );
}