import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
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
          ctrl.dealtCount >= SpreadController.maxTableCards
              ? SpreadController.maxTableCardsPrompt
              : SpreadController.dealLockedPrompt,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: AppColors.surface.withValues(alpha: 0.96),
      ),
    );
}