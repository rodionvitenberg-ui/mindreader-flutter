import 'package:flutter/material.dart';

import '../../shell/widgets/pro_subscription_sheet.dart';

/// ASTRAL PRO gate — delegates to the unified [ProSubscriptionSheet] with
/// ASTRAL-specific context so every PRO upgrade path shares the exact same
/// Early Supporter pricing, Solana web checkout, and status sync.
class AstralProPaywallSheet extends StatelessWidget {
  const AstralProPaywallSheet({
    super.key,
    this.reason = ProGateReason.astralProfiles,
  });

  final ProGateReason reason;

  static Future<void> show(
    BuildContext context, {
    ProGateReason reason = ProGateReason.astralProfiles,
  }) {
    return ProSubscriptionSheet.show(context, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return ProSubscriptionSheet(reason: reason);
  }
}
