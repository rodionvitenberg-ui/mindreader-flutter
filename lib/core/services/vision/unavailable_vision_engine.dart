import '../../l10n/app_strings.dart';
import 'dart:async';

import 'vision_engine.dart';

/// The honest fallback when NO vision engine is available (no worker, no
/// cloud, no offline model). It never invents cards: every scan returns
/// [VisionScanResult.manualFallbackRequired] == true so the UI falls back to
/// manual card entry via `DivinationCard`.
class UnavailableVisionEngine implements VisionEngine {
  const UnavailableVisionEngine();

  @override
  VisionCapabilities get capabilities => const VisionCapabilities(
    isAvailable: false,
    supportsRecognition: false,
    supportsReversal: false,
    supportsLiveTracking: false,
    supportedSystems: {},
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<VisionScanResult> scanImage(
    VisionFrame frame, {
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    return VisionScanResult(
      candidates: [],
      observations: [],
      manualFallbackRequired: true,
      message: AppStrings.g('vision.unavailable'),
    );
  }

  @override
  Stream<VisionEvent> startSession({String? sessionId}) => const Stream.empty();

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
  Future<void> dispose() async {}
}
