import 'dart:async';
import 'dart:typed_data';

import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/services/vision/vision_engine.dart';

/// Deterministic, scriptable [VisionEngine] for tests and explicit debug
/// mode only. It can script the full physical-reading scenario space:
/// appearance / confirmation / unknown / reversed / face-down / occlusion /
/// disappearance / repeat / many cards / failure / delay / cancellation.
class FakeVisionEngine implements VisionEngine {
  FakeVisionEngine({
    this.capabilities = const VisionCapabilities(),
    this.delay = Duration.zero,
  });

  @override
  final VisionCapabilities capabilities;

  /// Added before each async hop, to script delayed/late answers.
  final Duration delay;

  /// FIFO queue of scan results; when empty, `scanImage` returns an empty
  /// result with zero candidates.
  final List<VisionScanResult> scriptedResults = [];

  /// FIFO queue of events emitted by `startSession`.
  final List<VisionEvent> scriptedEvents = [];

  /// Exposed so tests can assert on stale-frame rejection independently.
  final VisionFrameGate gate = VisionFrameGate();

  int scanCalls = 0;
  int disposeCalls = 0;

  /// When true, `scanImage` throws [VisionEngineException] (scripted failure).
  bool failOnScan = false;

  /// When true, `scanImage` rejects out-of-order frames via [gate].
  bool rejectStale = true;

  void enqueueResult(VisionScanResult result) => scriptedResults.add(result);
  void enqueueEvent(VisionEvent event) => scriptedEvents.add(event);

  /// Builds a recognized tarot candidate with sensible defaults.
  static VisionCardCandidate candidate({
    String observationId = 'obs',
    String trackId = 'track',
    int? canonicalCardId = 0,
    CardOrientation orientation = CardOrientation.upright,
    CardFaceState faceState = CardFaceState.faceUp,
    RecognitionStatus status = RecognitionStatus.recognized,
    DateTime? timestamp,
  }) {
    return VisionCardCandidate(
      observationId: observationId,
      trackId: trackId,
      system: DivinationSystem.tarot,
      timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
      canonicalCardId: canonicalCardId,
      orientation: orientation,
      faceState: faceState,
      recognitionStatus: status,
    );
  }

  /// Builds a frame with a fixed timestamp (defaults to epoch).
  static VisionFrame frame({
    List<int> bytes = const [1, 2, 3],
    int width = 100,
    int height = 100,
    DateTime? timestamp,
  }) {
    return VisionFrame(
      bytes: Uint8List.fromList(bytes),
      sourceWidth: width,
      sourceHeight: height,
      timestamp: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<VisionScanResult> scanImage(
    VisionFrame frame, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    scanCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (cancelToken?.isCancelled ?? false) {
      throw const VisionCancelledException();
    }
    if (failOnScan) {
      throw const VisionEngineException('scripted failure');
    }
    if (rejectStale) {
      final stale = gate.guard(sessionId, frame);
      if (stale != null) throw StaleVisionFrameException(stale);
    }
    if (scriptedResults.isEmpty) {
      return const VisionScanResult(candidates: [], observations: []);
    }
    return scriptedResults.removeAt(0);
  }

  @override
  Stream<VisionEvent> startSession({String? sessionId}) async* {
    for (final event in List<VisionEvent>.of(scriptedEvents)) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield event;
    }
  }

  @override
  Future<VisionObservation?> processFrame(
    VisionFrame frame, {
    String? sessionId,
  }) async {
    return null;
  }

  @override
  Future<void> stopSession({String? sessionId}) async {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
