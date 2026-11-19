# VISION ENGINE CONTRACT — mindreader.quest

> The ML-agnostic contract between the Physical Reading flows and any camera
> recognition engine. The app depends on `VisionEngine` (`lib/core/services/
> vision/vision_engine.dart`) — never on a concrete scanner. This document is
> the human-readable spec of that contract; the code is the authority.

## 1. Interface

```dart
abstract class VisionEngine {
  VisionCapabilities get capabilities;
  Future<void> initialize();
  Future<VisionScanResult> scanImage(VisionFrame frame,
      {String? sessionId, CancelToken? cancelToken});
  Stream<VisionEvent> startSession({String? sessionId});
  Future<VisionObservation?> processFrame(VisionFrame frame,
      {String? sessionId});
  Future<void> stopSession({String? sessionId});
  Future<void> dispose();
}
```

Detection is deliberately separated from recognition: an engine can report a
card-shaped region (`VisionObservation`) without naming it, and can name a card
(`VisionCardCandidate`) without geometry.

## 2. Capabilities

`VisionCapabilities` advertises, without ever overstating:

| Field | Meaning |
| --- | --- |
| `isAvailable` | a usable engine exists |
| `supportsRecognition` | it maps regions to canonical cards |
| `supportsReversal` | it reports upright/reversed |
| `supportsLiveTracking` | it can stream live frames |
| `supportedSystems` | the `DivinationSystem`s it recognizes (e.g. tarot only) |

The UI renders affordances from `capabilities` — **no invented confidence, no
fake recognition**.

## 3. Frame format

`VisionFrame` is a pure, engine-agnostic payload:

* `bytes` — encoded image (JPEG/PNG/…), `Uint8List`;
* `sourceWidth` / `sourceHeight` — pixel dimensions of the source;
* `rotationDegrees` — sensor/EXIF rotation (0/90/180/270);
* `timestamp` — capture time (nullable; a null timestamp is never stale).

## 4. Coordinate & orientation model

* Geometry is in **normalized** image coordinates `0..1`:
  `NormalizedPoint(x, y)`, `NormalizedRect(left, top, right, bottom)`, with
  `isNormalized` / `clamped()` guards. Engines must emit boxes already valid.
* `CardFaceState`: `faceUp | faceDown | unknown`.
* `CardOrientation`: `upright | reversed | unknown`.

## 5. Recognition schema

`VisionCardCandidate` carries identity AND geometry, any subset populated:

* `canonicalCardId` — stable index into the system's dataset (0..77 tarot),
  null until recognized;
* `deckId` — optional deck identifier, null when untracked;
* `orientation` / `faceState`;
* `recognitionConfidence` / `detectionConfidence` — **null when the engine has
  none** (never invented);
* `boundingBox` / `corners` — optional geometry;
* `recognitionStatus`: `detected | recognizing | recognized | ambiguous |
  unknown | lost`.

## 6. Unknown card

An unrecognized region is still a `VisionCardCandidate` with
`recognitionStatus` in `detected`/`ambiguous`/`unknown` and a null
`canonicalCardId`. The engine NEVER fabricates an identity; the app treats
`unknown`/`ambiguous` as a manual-entry prompt, not a silent guess.

## 7. Event schema (live sessions)

`VisionEvent` has `type` (`observed | recognized | updated | lost`), a
`VisionCardCandidate`, and a `timestamp`. Live tracking is OPTIONAL — an engine
without it (`supportsLiveTracking == false`) returns an empty stream.

## 8. Session lifecycle

`initialize()` once; `startSession({sessionId})` opens a tracked stream;
`processFrame` updates one frame; `stopSession` ends it; `dispose()` releases
resources. `sessionId` scopes stale-frame tracking per session.

## 9. Cancellation & backpressure

* `CancelToken` — cooperative; engines check `isCancelled` between async hops
  and throw `VisionCancelledException`.
* `VisionFrameGate` — reusable per-session monotonic gate; a frame older than
  the newest processed one throws `StaleVisionFrameException`. Frames with no
  timestamp are never stale.
* The caller submits only the latest frame and cancels in-flight work on
  session switch — an engine never accumulates a backlog.

## 10. Exceptions

`VisionCancelledException`, `StaleVisionFrameException`, `VisionEngineException`
— all plain, serializable, no sensitive payload.

## 11. Built-in engines

| Engine | Role |
| --- | --- |
| `UnavailableVisionEngine` | honest default: `isAvailable: false`, every scan returns `manualFallbackRequired: true` |
| `LegacyVisionAdapter` | adapts the existing `VisionScannerService` (tarot-only, name + reversed) onto this contract; confidence/bbox stay null |
| `VisionScannerService` (legacy) | the dual-AI (worker → Gemini → offline mock) scanner behind the adapter |

## 12. Adapter guide

To add a real engine: implement `VisionEngine`, set `capabilities` honestly,
return `VisionScanResult(candidates: …)` with `canonicalCardId`/`orientation`
when recognized and `recognitionStatus` otherwise, then register the concrete
engine via provider **without** touching Oracle/Table/History. Reuse
`VisionFrameGate` for stale rejection and `CancelToken` for cancellation.

## 13. Debug fixtures

`test/fakes/fake_vision_engine.dart` provides a scriptable in-memory engine for
headless tests. `test/vision_contract_test.dart` pins the contract — detection
vs recognition, unknown card, cancellation, stale rejection, orientation and
the `UnavailableVisionEngine` manual fallback.

## 14. Real-engine checklist

1. `capabilities` reflects the real engine (no invented confidence).
2. `scanImage` respects `CancelToken` and rejects stale frames.
3. `canonicalCardId` matches the dataset index; `orientation`/`faceState` set.
4. Unknown regions return a candidate with a non-`recognized` status, not a guess.
5. `manualFallbackRequired` is true only when there is genuinely no vision.
6. Register via provider; run `vision_contract_test` + the full suite unchanged.
