/// The high-level phase of the Active Digital Table that a Guided Reading
/// hint is computed for. Pure Dart — no Flutter imports.
enum GuidePhase { dealing, revealing, interpreting, complete }

/// The discrete moments the educational mentor reacts to. The order is
/// conceptual; the urgency of each moment is encoded by
/// [GuideEventTypeX.priority].
enum GuideEventType {
  spreadSelected,
  dealingStarted,
  cardDealt,
  cardPlaced,
  revealingStarted,
  cardRevealed,
  relationshipTapped,
  spreadCompleted,
}

extension GuideEventTypeX on GuideEventType {
  /// Lower = more urgent. When several moments could fire at once, the mentor
  /// surfaces only the single most relevant one.
  int get priority => switch (this) {
        GuideEventType.spreadCompleted => 0,
        GuideEventType.relationshipTapped => 1,
        GuideEventType.cardRevealed => 2,
        GuideEventType.revealingStarted => 3,
        GuideEventType.cardPlaced => 4,
        GuideEventType.cardDealt => 5,
        GuideEventType.dealingStarted => 6,
        GuideEventType.spreadSelected => 7,
      };
}
