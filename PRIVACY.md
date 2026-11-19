# PRIVACY & NETWORK — mindreader.quest

> Local-first. The device is the only store of truth. This document records
> exactly what leaves the device and what never does, so the guarantees are
> auditable against the code (not assumed).

## 1. Where data lives

| Data | Location | Leaves the device? |
| --- | --- | --- |
| Reading sessions (spread + synthesis + Oracle chat) | `SharedPreferences` via `LocalStorageService` | No |
| User profile / birth data / natal charts | `SharedPreferences` (`UserProfileController`, `AstralController`) | No |
| App settings / PRO flag / deck packs | `SharedPreferences` | No |
| Ritual streaks / notifications state | `SharedPreferences` | No |

There is no remote account, no relay server and no analytics SDK. Sessions are
keyed by a local ISO-8601 timestamp; the archive is written in the background
and read back on launch.

## 2. What is sent over the network

The app has exactly two network surfaces, both `http` and both reachable only
when the operator supplies `--dart-define` configuration (there are **no**
hardcoded endpoints or keys in the repository):

1. **Oracle synthesis** (`OracleSynthesisService`): sends a *text prompt*
   (card meanings, spread position, context notes) to, in order, a local/tunneled
   worker (`PRIMARY_WORKER_URL`) then Gemini Flash cloud (`ORACLE_API_URL`), and
   falls back to a deterministic **offline** engine when neither is configured
   or reachable. It never sends images, video or audio frames.

2. **Vision recognition** (`VisionScannerService`, behind the `VisionEngine`
   contract): when a real engine is configured, sends a **downscaled JPEG**
   (≤1024 px, quality 80) to the same worker → cloud chain. When neither the
   worker nor the cloud key is configured the service runs its offline mock
   (`isMock`) — **nothing is sent**. The `VisionEngine` contract's default is
   `UnavailableVisionEngine`, which likewise never sends a frame.

Both surfaces degrade to a local offline safety net, so the reading flow never
fails (or leaks) without network.

## 3. What is NEVER sent or stored

- **Raw video/audio are never captured for storage or upload.** The camera runs
  with `enableAudio: false`; no microphone stream is recorded. Voice
  (`OracleVoiceService` / `speech_to_text`) is a live half-duplex interaction,
  not a recording.
- **Camera frames are never sent to the Oracle.** The Oracle receives only the
  compact structured `OraclePayload` (`canonicalCardId`, position, role,
  orientation, source, confirmation) — no bounding boxes, no images.
- **Personally identifiable information and secrets are never logged.** Log
  output is limited to error *types* (`debugPrint('... ${e.runtimeType}')`),
  never values, prompts, keys or profile data.

## 4. Keys & secrets

All keys/endpoints are read from `String.fromEnvironment` (`dart-define`) at
build time: `PRIMARY_WORKER_URL`, `PRIMARY_WORKER_KEY`, `ORACLE_API_URL`,
`GEMINI_API_KEY`, `VISION_API_URL`, `VISION_API_KEY`. None are committed, and
new server dependencies or in-code secrets must not be added.

## 5. Physical-reading flows

- **Quick Scan / Guided Spread** images go to Vision *only* while a real engine
  is configured; recognition is the only purpose.
- **Live Oracle** never uploads a frame: it reads the already-recognized,
  face-up cards from the local table.
- Camera and microphone are never started implicitly: they open only when the
  reader navigates to the Camera tab or taps an explicit resume action. A
  restored session lands on the chat pane in a `completed` state and never
  re-activates capture.
