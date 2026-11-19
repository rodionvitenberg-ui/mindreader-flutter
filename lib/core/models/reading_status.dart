/// Lifecycle of one reading session. Mirrors the Guided reading finite
/// state machine so the live state and the persisted state share one
/// vocabulary.
enum ReadingStatus {
  idle,
  preparing,
  active,
  paused,
  completed,
  cancelled,
  failed,
}

extension ReadingStatusX on ReadingStatus {
  /// Whether [next] is a legal transition from this state. Terminal states
  /// ([completed], [cancelled], [failed]) accept no further transition.
  bool canTransitionTo(ReadingStatus next) => switch (this) {
    ReadingStatus.idle => next == ReadingStatus.preparing,
    ReadingStatus.preparing =>
      next == ReadingStatus.active ||
          next == ReadingStatus.cancelled ||
          next == ReadingStatus.failed,
    ReadingStatus.active =>
      next == ReadingStatus.paused ||
          next == ReadingStatus.completed ||
          next == ReadingStatus.cancelled ||
          next == ReadingStatus.failed,
    ReadingStatus.paused =>
      next == ReadingStatus.active || next == ReadingStatus.cancelled,
    ReadingStatus.completed ||
    ReadingStatus.cancelled ||
    ReadingStatus.failed => false,
  };

  /// True once the session can no longer change state.
  bool get isTerminal =>
      this == ReadingStatus.completed ||
      this == ReadingStatus.cancelled ||
      this == ReadingStatus.failed;
}
