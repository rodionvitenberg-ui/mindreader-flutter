import 'package:flutter/foundation.dart';

import '../core/models/oracle_action.dart';
import '../core/l10n/app_strings.dart';

/// One proposed role reassignment when moving freely-laid cards into a
/// structured spread. The app NEVER applies this silently.
class GuidedRoleAssignment {
  const GuidedRoleAssignment({
    required this.cardIndex,
    required this.role,
    required this.isGeneric,
  });

  /// The 0-based index of the existing free card.
  final int cardIndex;

  /// The target slot role, or a generic `Card N` label past the template.
  final String role;

  /// True when the card falls beyond the template's role list.
  final bool isGeneric;
}

/// The result of planning a freeform → Guided transition. Cards are NEVER
/// dropped ([keptCards] always equals the existing count); the mapping is a
/// PROPOSAL that the reader must confirm before it is applied.
class GuidedTransitionPlan {
  const GuidedTransitionPlan({
    required this.requiresConfirmation,
    required this.assignments,
    required this.keptCards,
  });

  final bool requiresConfirmation;
  final List<GuidedRoleAssignment> assignments;
  final int keptCards;
}

/// Plans a freeform → Guided transition WITHOUT mutating anything. Existing
/// cards are never silently reassigned: whenever there is at least one card to
/// remap, [GuidedTransitionPlan.requiresConfirmation] is true so the reader
/// confirms the role assignment before the app applies it.
GuidedTransitionPlan planGuidedTransition({
  required int existingCardCount,
  required List<String> targetRoles,
}) {
  final assignments = <GuidedRoleAssignment>[
    for (var i = 0; i < existingCardCount; i++)
      GuidedRoleAssignment(
        cardIndex: i,
        role: i < targetRoles.length
            ? targetRoles[i]
            : '${AppStrings.g('table.cardWord')} ${i + 1}',
        isGeneric: i >= targetRoles.length,
      ),
  ];
  return GuidedTransitionPlan(
    requiresConfirmation: existingCardCount > 0,
    assignments: assignments,
    keptCards: existingCardCount,
  );
}

/// The state of a Live Oracle FREEFORM session — the camera flow where the
/// reader states an intention and lays cards freely, with no mandatory spread.
///
/// It holds NO cards of its own (the [SpreadController] is the card source of
/// truth) and NO dialogue (the [OracleSessionController] is the dialogue source
/// of truth). It only tracks the freeform intent + the last action the Oracle
/// requested, and exposes the non-destructive guided-transition plan.
class LiveOracleController extends ChangeNotifier {
  bool _active = false;
  String? _intention;
  OracleAction? _pendingAction;

  bool get isActive => _active;
  String? get intention => _intention;

  /// The last action the Oracle requested (set by the caller after an
  /// `interpretFreeform` turn). Null before the first turn or after [reset].
  OracleAction? get pendingAction => _pendingAction;

  /// Starts (or restarts) a freeform live session with an optional [intention].
  void begin({String? intention}) {
    _active = true;
    _intention = intention;
    _pendingAction = null;
    notifyListeners();
  }

  void setIntention(String value) {
    final trimmed = value.trim();
    if (_intention == trimmed) return;
    _intention = trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  /// Records the action the Oracle requested on its last turn.
  void recordAction(OracleAction action) {
    if (_pendingAction == action) return;
    _pendingAction = action;
    notifyListeners();
  }

  void reset() {
    _active = false;
    _intention = null;
    _pendingAction = null;
    notifyListeners();
  }
}
