import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

/// A deterministic in-memory camera platform for widget tests.
///
/// Returns ONE fake back camera and counts `create`/`initialize`/`dispose`
/// calls so lifecycle tests can assert the camera opens exactly when the
/// CAMERA tab becomes active and is disposed the instant it is left. The
/// preview renders as an empty box and every stream resolves or stays pending
/// exactly like a healthy device.
class FakeCameraPlatform extends CameraPlatform {
  int createCalls = 0;
  int initCalls = 0;
  int disposeCalls = 0;

  /// When true, `availableCameras` reports no hardware (simulates a device
  /// with no camera / denied permission) so the screen exercises its
  /// honest simulated-viewfinder fallback.
  bool noCameras = false;

  /// Optional gate to pause `initializeCamera` so tests can inspect the
  /// loading state before the live feed arrives.
  Completer<void>? initGate;

  @override
  Future<List<CameraDescription>> availableCameras() async => noCameras
      ? const []
      : [
          const CameraDescription(
            name: 'fake-back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90,
          ),
        ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    createCalls++;
    return 7;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    initCalls++;
    if (initGate != null) {
      await initGate!.future;
    }
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposeCalls++;
  }

  @override
  Widget buildPreview(int cameraId) =>
      const SizedBox.expand(); // live preview placeholder in tests

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(const CameraInitializedEvent(
        7,
        1280,
        720,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ));

  @override
  Stream<CameraResolutionChangedEvent> onCameraResolutionChanged(
          int cameraId) =>
      const Stream.empty();

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      const Stream.empty();

  /// The controller awaits `.first` on this stream — it must stay PENDING
  /// (a real device emits an error event only on an actual failure).
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      Stream<CameraErrorEvent>.multi((_) {});

  @override
  Stream<VideoRecordedEvent> onVideoRecordedEvent(int cameraId) =>
      const Stream.empty();

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
}
