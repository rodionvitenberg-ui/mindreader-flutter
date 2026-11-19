import 'dart:async';
import 'dart:typed_data';

import '../../models/divination_system.dart';

/// The ML-agnostic camera/vision contract for the Physical Reading flows.
///
/// This file is PURE Dart (no Flutter imports) so engines and the fakes used
/// in tests can run headlessly. Detection (a card-shaped region was found)
/// is deliberately separated from Recognition (that region was identified as
/// a specific canonical card) — see [VisionObservation] vs
/// [VisionCardCandidate] and [RecognitionStatus].

/// Clamps [v] into the normalized 0..1 coordinate space.
double clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

/// A point in normalized image coordinates (0..1 relative to the source).
class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  final double x;
  final double y;

  NormalizedPoint clamped() => NormalizedPoint(clamp01(x), clamp01(y));

  @override
  bool operator ==(Object other) =>
      other is NormalizedPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'NormalizedPoint($x, $y)';
}

/// An axis-aligned box in normalized image coordinates (0..1). [left] is
/// expected ≤ [right] and [top] ≤ [bottom]; the engine is responsible for
/// emitting boxes already clamped/valid, but [clamped] provides a defensive
/// normalizer for adapters.
class NormalizedRect {
  const NormalizedRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// True when every coordinate is inside 0..1 and the box has non-negative
  /// area (left ≤ right, top ≤ bottom).
  bool get isNormalized =>
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      right >= left &&
      bottom >= top;

  NormalizedRect clamped() => NormalizedRect(
    left: clamp01(left),
    top: clamp01(top),
    right: clamp01(right),
    bottom: clamp01(bottom),
  );
}

/// Whether the card's face, its back, or an unknown side is toward the
/// camera.
enum CardFaceState { faceUp, faceDown, unknown }

/// Rotation of a face-up card relative to the reader.
enum CardOrientation { upright, reversed, unknown }

/// Recognition lifecycle of a single detected card region. Detection ≠
/// recognition: [detected] means only a region was found; [recognized] means
/// it was mapped to a canonical card.
enum RecognitionStatus {
  detected,
  recognizing,
  recognized,
  ambiguous,
  unknown,
  lost,
}

/// A single image frame handed to an engine (from camera or gallery).
class VisionFrame {
  const VisionFrame({
    required this.bytes,
    required this.sourceWidth,
    required this.sourceHeight,
    this.rotationDegrees = 0,
    this.timestamp,
  });

  /// Encoded payload (JPEG/PNG/…).
  final Uint8List bytes;

  final int sourceWidth;
  final int sourceHeight;

  /// Sensor/EXIF rotation in degrees (0/90/180/270).
  final int rotationDegrees;

  /// Capture time — used for stale-frame rejection. When null the frame is
  /// never considered stale.
  final DateTime? timestamp;
}

/// A detected card-shaped region, BEFORE any recognition. This is the raw
/// detection layer: an engine can report [VisionObservation]s even when it
/// cannot name the card.
class VisionObservation {
  const VisionObservation({
    required this.observationId,
    required this.trackId,
    required this.boundingBox,
    required this.timestamp,
    this.detectionConfidence,
  });

  final String observationId;
  final String trackId;
  final NormalizedRect boundingBox;
  final DateTime timestamp;
  final double? detectionConfidence;
}

/// A recognized (or still-recognizing) card candidate. Carries BOTH the
/// identity fields ([canonicalCardId], [deckId], [orientation]) and the
/// geometric fields ([boundingBox], [corners]) — an engine may populate the
/// identity only, the geometry only, or both.
class VisionCardCandidate {
  const VisionCardCandidate({
    required this.observationId,
    required this.trackId,
    required this.system,
    required this.timestamp,
    this.canonicalCardId,
    this.deckId,
    this.orientation = CardOrientation.unknown,
    this.faceState = CardFaceState.unknown,
    this.recognitionConfidence,
    this.detectionConfidence,
    this.boundingBox,
    this.corners,
    this.recognitionStatus = RecognitionStatus.detected,
  });

  final String observationId;
  final String trackId;

  /// The divination system this card belongs to (null while unknown).
  final DivinationSystem? system;

  final DateTime timestamp;

  /// Stable index into the system's dataset (e.g. 0..77 for tarot). Null
  /// until recognition succeeds.
  final int? canonicalCardId;

  /// Optional deck identifier (e.g. 'rider-waite-smith'); null when the
  /// engine does not track decks.
  final String? deckId;

  final CardOrientation orientation;
  final CardFaceState faceState;

  /// Never invented: engines report confidence only when they actually
  /// produce one (otherwise null).
  final double? recognitionConfidence;
  final double? detectionConfidence;

  final NormalizedRect? boundingBox;
  final List<NormalizedPoint>? corners;

  final RecognitionStatus recognitionStatus;
}

/// Result of one `scanImage` call.
class VisionScanResult {
  const VisionScanResult({
    required this.candidates,
    required this.observations,
    this.manualFallbackRequired = false,
    this.message,
  });

  final List<VisionCardCandidate> candidates;
  final List<VisionObservation> observations;

  /// True when the engine has NO vision and the UI must fall back to manual
  /// card entry (via `DivinationCard`).
  final bool manualFallbackRequired;

  final String? message;

  int get detectedCount => candidates.length;
}

/// Streaming event kinds emitted by `startSession`.
enum VisionEventType { observed, recognized, updated, lost }

/// One streaming tracking update for a live session.
class VisionEvent {
  const VisionEvent({
    required this.type,
    required this.candidate,
    required this.timestamp,
  });

  final VisionEventType type;
  final VisionCardCandidate candidate;
  final DateTime timestamp;
}

/// Cooperative cancellation token. Engines check [isCancelled] between
/// async hops and throw [VisionCancelledException] instead of producing a
/// result.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Thrown when a scan/session was cancelled before it could complete.
class VisionCancelledException implements Exception {
  const VisionCancelledException();
  @override
  String toString() => 'VisionCancelledException';
}

/// Thrown when an engine rejects an out-of-order (stale) frame.
class StaleVisionFrameException implements Exception {
  const StaleVisionFrameException(this.message);
  final String message;
  @override
  String toString() => 'StaleVisionFrameException: $message';
}

/// Generic engine failure.
class VisionEngineException implements Exception {
  const VisionEngineException(this.message);
  final String message;
  @override
  String toString() => 'VisionEngineException: $message';
}

/// Reusable stale-frame gate: tracks the newest processed frame timestamp
/// per session and rejects older frames. Engines compose this to satisfy the
/// contract's stale-rejection requirement without duplicating the logic.
class VisionFrameGate {
  final Map<String, DateTime> _latestBySession = {};

  /// Returns an error message when [frame] is stale for [sessionId], else
  /// records it and returns null (accepted). Frames with no timestamp are
  /// never stale.
  String? guard(String? sessionId, VisionFrame frame) {
    final timestamp = frame.timestamp;
    if (timestamp == null) return null;
    final key = sessionId ?? '_default';
    final latest = _latestBySession[key];
    if (latest != null && timestamp.isBefore(latest)) {
      return 'stale frame (${timestamp.toIso8601String()}) for session "$key"';
    }
    if (latest == null || timestamp.isAfter(latest)) {
      _latestBySession[key] = timestamp;
    }
    return null;
  }
}

/// What a concrete engine can and cannot do — lets the Camera UI and the
/// handoff render honest affordances (no invented confidence, no fake
/// recognition).
class VisionCapabilities {
  const VisionCapabilities({
    this.isAvailable = true,
    this.supportsRecognition = true,
    this.supportsReversal = true,
    this.supportsLiveTracking = false,
    this.supportedSystems = const {DivinationSystem.tarot},
  });

  final bool isAvailable;
  final bool supportsRecognition;
  final bool supportsReversal;
  final bool supportsLiveTracking;
  final Set<DivinationSystem> supportedSystems;
}

/// The engine contract. Every real or fake engine implements this; the app
/// depends on [VisionEngine], never on a concrete scanner. All operations
/// are async, cancellable where noted, and injected via provider.
abstract class VisionEngine {
  VisionCapabilities get capabilities;

  Future<void> initialize();

  /// Scans one still image and returns candidates. Throws
  /// [VisionCancelledException] when [cancelToken] is cancelled, and
  /// [StaleVisionFrameException] when [frame] is older than a previously
  /// processed frame for [sessionId].
  Future<VisionScanResult> scanImage(
    VisionFrame frame, {
    String? sessionId,
    CancelToken? cancelToken,
  });

  /// Starts a live tracking session, streaming detection/recognition events.
  Stream<VisionEvent> startSession({String? sessionId});

  /// Processes one frame in a live session (single-frame tracking update).
  Future<VisionObservation?> processFrame(
    VisionFrame frame, {
    String? sessionId,
  });

  Future<void> stopSession({String? sessionId});

  Future<void> dispose();
}
