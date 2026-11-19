import '../core/models/chat_message.dart';
import '../core/models/reading_mode.dart';
import '../core/models/reading_source.dart';
import '../core/models/reading_status.dart';
import '../core/services/oracle_synthesis_service.dart';
import 'synthesis_session.dart';

/// The SINGLE source of truth for the Oracle dialogue, shared across the
/// Camera / Digital Table / Oracle Chat panes for ONE reading.
///
/// It ABSORBS [SynthesisSession] (the dialogue state model) by extending it,
/// so the whole `TableWorkspace` — which historically owned a private
/// `SynthesisSession` — keeps its exact behavior while this controller adds
/// the session-level identity + provenance + lifecycle that the physical
/// flows need:
///
/// * a stable [sessionId] (fallback = the archive timestamp, see
///   [effectiveSessionId]); tab switches never change it;
/// * [readingSource] / [readingMode] / [readingStatus].
class OracleSessionController extends SynthesisSession {
  String? _sessionId;
  String? get sessionId => _sessionId;

  ReadingSource _readingSource = ReadingSource.digital;
  ReadingSource get readingSource => _readingSource;

  ReadingMode _readingMode = ReadingMode.standard;
  ReadingMode get readingMode => _readingMode;

  ReadingStatus _readingStatus = ReadingStatus.idle;
  ReadingStatus get readingStatus => _readingStatus;

  /// Monotonic session epoch. Bumped on every [reset] and [beginSession] so a
  /// late async response (captured before a reset/restart) is rejected instead
  /// of mutating the session that replaced it. This is the stale-response
  /// guard the resource lifecycle requires: sessionId alone cannot cover the
  /// synthesis path where the id is assigned AFTER the async answer returns.
  int _epoch = 0;
  int get epoch => _epoch;

  /// True while [epoch] still identifies THIS live session. An async answer
  /// that started under an older epoch must not write into the current one.
  bool isCurrentSession(int epoch) => _epoch == epoch;

  /// Runtime identity: [sessionId] when set, else the archive timestamp —
  /// old and new sessions share one fallback.
  String effectiveSessionId(String fallbackTimestamp) =>
      _sessionId ?? fallbackTimestamp;

  /// Assigns the stable id ONCE — the first writer wins; a later call never
  /// overwrites an existing id (switching tabs must not change it).
  void ensureSessionId(String fallbackTimestamp) {
    _sessionId ??= fallbackTimestamp;
  }

  void setReadingSource(ReadingSource value) {
    if (_readingSource == value) return;
    _readingSource = value;
    notifyListeners();
  }

  void setReadingMode(ReadingMode value) {
    if (_readingMode == value) return;
    _readingMode = value;
    notifyListeners();
  }

  /// Starts a fresh session: stable id + provenance + lifecycle = active.
  void beginSession({
    String? sessionId,
    ReadingSource? source,
    ReadingMode? mode,
  }) {
    _epoch++;
    if (sessionId != null) _sessionId = sessionId;
    _sessionId ??= DateTime.now().toIso8601String();
    _readingSource = source ?? _readingSource;
    _readingMode = mode ?? _readingMode;
    _readingStatus = ReadingStatus.active;
    notifyListeners();
  }

  /// Legal lifecycle transition; returns false (state unchanged) when
  /// [next] is not reachable from the current status.
  bool transitionTo(ReadingStatus next) {
    if (_readingStatus == next) return true;
    if (!_readingStatus.canTransitionTo(next)) return false;
    _readingStatus = next;
    notifyListeners();
    return true;
  }

  /// Force-sets the status (restore/legacy paths) without FSM validation.
  void setStatus(ReadingStatus next) {
    if (_readingStatus == next) return;
    _readingStatus = next;
    notifyListeners();
  }

  /// 1-tap session restore: dialogue AND session metadata in one atomic
  /// update (a single `notifyListeners` after every field is consistent).
  void restoreSession({
    required StructuredSynthesis? initial,
    required List<ClarifierChapter> chapters,
    required List<ChatMessage> messages,
    String? sessionId,
    ReadingSource? readingSource,
    ReadingMode? readingMode,
    ReadingStatus? readingStatus,
  }) {
    // Restoring a different conversation is a session replacement: bump the
    // epoch so a late async answer from the conversation being left is
    // rejected instead of mutating the restored one (same guard as reset /
    // beginSession).
    _epoch++;
    _sessionId = sessionId;
    _readingSource = readingSource ?? ReadingSource.digital;
    _readingMode = readingMode ?? ReadingMode.standard;
    _readingStatus = readingStatus ?? ReadingStatus.completed;
    // super.restore notifies once, after the metadata above is consistent.
    super.restore(initial: initial, chapters: chapters, messages: messages);
  }

  @override
  void reset() {
    _epoch++;
    _sessionId = null;
    _readingSource = ReadingSource.digital;
    _readingMode = ReadingMode.standard;
    _readingStatus = ReadingStatus.idle;
    super.reset(); // clears dialogue + notifies
  }
}
