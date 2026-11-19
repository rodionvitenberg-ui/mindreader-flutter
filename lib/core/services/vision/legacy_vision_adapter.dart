import 'dart:async';

import '../../models/divination_system.dart';
import '../vision_scanner_service.dart';
import 'vision_engine.dart';

/// Adapts the legacy [VisionScannerService] (the existing dual-AI + offline
/// mock scanner) onto the new [VisionEngine] contract.
///
/// The legacy scanner only recognizes Tarot, reports the card name +
/// reversed flag, and has no geometry or confidence — so this adapter maps:
/// * `DetectedCard` → a [VisionCardCandidate] with [RecognitionStatus.recognized],
///   [CardFaceState.faceUp], and [CardOrientation.reversed] / [upright];
/// * `cardCount` is left OPTIONAL — the count comes from the result list.
///
/// Recognition confidence and bounding boxes are deliberately NOT invented
/// (both stay null).
class LegacyVisionAdapter implements VisionEngine {
  LegacyVisionAdapter({VisionScannerService? service})
    : _service = service ?? VisionScannerService();

  final VisionScannerService _service;
  final VisionFrameGate _gate = VisionFrameGate();

  @override
  VisionCapabilities get capabilities => const VisionCapabilities(
    isAvailable: true,
    supportsRecognition: true,
    supportsReversal: true,
    supportsLiveTracking: false,
    supportedSystems: {DivinationSystem.tarot},
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<VisionScanResult> scanImage(
    VisionFrame frame, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const VisionCancelledException();
    }
    final stale = _gate.guard(sessionId, frame);
    if (stale != null) throw StaleVisionFrameException(stale);

    final detected = await _service.detectSpread(jpeg: frame.bytes);
    final candidates = [
      for (var i = 0; i < detected.length; i++)
        VisionCardCandidate(
          observationId: 'legacy-$i',
          trackId: 'legacy-track-$i',
          system: DivinationSystem.tarot,
          timestamp: frame.timestamp ?? DateTime.now(),
          canonicalCardId: detected[i].card.id,
          orientation: detected[i].isReversed
              ? CardOrientation.reversed
              : CardOrientation.upright,
          faceState: CardFaceState.faceUp,
          recognitionStatus: RecognitionStatus.recognized,
        ),
    ];
    return VisionScanResult(candidates: candidates, observations: const []);
  }

  @override
  Stream<VisionEvent> startSession({String? sessionId}) => const Stream.empty();

  @override
  Future<VisionObservation?> processFrame(
    VisionFrame frame, {
    String? sessionId,
  }) async {
    return null; // the legacy scanner has no live tracking.
  }

  @override
  Future<void> stopSession({String? sessionId}) async {}

  @override
  Future<void> dispose() async {}
}
