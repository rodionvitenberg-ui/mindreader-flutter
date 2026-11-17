import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';

/// Sprint 1/3 — lazy camera lifecycle: the Android green privacy indicator
/// must NEVER stay on while the TABLE or ALMANAC tab is visible. The
/// camera opens only when the CAMERA tab is active and is disposed the
/// instant the user switches away.
class _FakeCameraPlatform extends CameraPlatform {
  int createCalls = 0;
  int initCalls = 0;
  int disposeCalls = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => [
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

void main() {
  late _FakeCameraPlatform fake;

  setUp(() {
    fake = _FakeCameraPlatform();
    CameraPlatform.instance = fake;
  });

  testWidgets(
      'camera stays OFF until the CAMERA tab opens and goes OFF when left',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.pump();

    // Booting on the TABLE tab never touches the hardware camera — no
    // green privacy indicator at startup.
    expect(fake.createCalls, 0);
    expect(fake.initCalls, 0);
    expect(fake.disposeCalls, 0);

    // Opening the CAMERA tab acquires the hardware exactly once.
    await tester.tap(find.text('CAMERA'));
    await tester.pump(); // didUpdateWidget + init starts
    await tester.pump(); // availableCameras resolves
    await tester.pump(); // initialize() resolves
    expect(fake.createCalls, 1);
    expect(fake.initCalls, 1);
    expect(fake.disposeCalls, 0);

    // Switching to ALMANAC releases the camera IMMEDIATELY.
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    await tester.pump();
    expect(fake.disposeCalls, 1);

    // Reopening the CAMERA tab re-acquires the hardware.
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(fake.createCalls, 2);
    expect(fake.initCalls, 2);
  });

  testWidgets('leaving the CAMERA tab mid-initialization drops the hardware',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();

    // Open CAMERA and immediately leave again — the async init must not
    // leave a live camera behind.
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    // Whatever the init race produced, the camera must never stay live:
    // every acquired camera is disposed (or never acquired at all).
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.disposeCalls, greaterThanOrEqualTo(fake.createCalls));
  });
}
