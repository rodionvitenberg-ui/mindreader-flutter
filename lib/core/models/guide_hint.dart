import 'package:flutter/foundation.dart';

import 'guide_event.dart';

/// Where a hint points on the table.
enum GuideHintAnchorKind { deck, slot, whole }

/// One localized educational hint the mentor can show.
///
/// The [title]/[body] are already localized by the producing controller; the
/// stable [id] is what the mentor uses to de-duplicate conceptual lessons.
@immutable
class GuideHint {
  const GuideHint({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    this.anchor = GuideHintAnchorKind.whole,
    this.slotIndex,
    this.lessonId,
    this.lesson,
  });

  /// Stable id for de-duplication (`completed:tarot:three`, `dealing:2`, …).
  final String id;

  final GuideEventType eventType;
  final String title;
  final String body;

  /// What the hint should point at / highlight on the table.
  final GuideHintAnchorKind anchor;
  final int? slotIndex;

  /// Stable id of the conceptual lesson attached to this hint (e.g.
  /// `slot:tarot:3 · Three Cards:1`). Null when the moment has nothing new to
  /// teach — the mentor never repeats a lesson the reader has already read.
  final String? lessonId;

  /// Localized teaching for this moment. Non-null exactly when [lessonId] is.
  final String? lesson;

  /// Urgency (lower = shown first). Mirrors [GuideEventTypeX.priority].
  int get priority => eventType.priority;
}
