import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';

import 'fakes/fake_camera_platform.dart';

/// Drives the binding through the LEGAL AppLifecycleState transition chain.
/// Jumping straight to `paused`/`resumed` trips `AppLifecycleListener`'s
/// transition assertions, so backgrounding goes inactive -> hidden -> paused
/// and foregrounding goes hidden -> inactive -> resumed.
void _driveLifecycleTo(WidgetTester tester, AppLifecycleState target) {
  if (target == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  } else if (target == AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

void main() {
  late FakeCameraPlatform fake;

  setUp(() {
    fake = FakeCameraPlatform();
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

  testWidgets('app backgrounding releases the camera; resume re-acquires it',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(fake.createCalls, 1);
    expect(fake.initCalls, 1);

    // Backgrounding the app must kill the hardware immediately.
    _driveLifecycleTo(tester, AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(fake.disposeCalls, 1);

    // Resuming while still on the CAMERA tab re-acquires the hardware.
    _driveLifecycleTo(tester, AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(fake.createCalls, 2);
    expect(fake.initCalls, 2);
  });

  testWidgets('resume on a non-camera tab does not re-open the camera',
      (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('ALMANAC'));
    await tester.pump();
    await tester.pump();
    expect(fake.disposeCalls, 1);
    final createdAfterLeave = fake.createCalls;

    // Background then resume while ALMANAC is on top: the camera must stay off.
    _driveLifecycleTo(tester, AppLifecycleState.paused);
    await tester.pump();
    _driveLifecycleTo(tester, AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(fake.createCalls, createdAfterLeave);
  });

  testWidgets(
      'no camera (denied/unavailable) degrades to the simulated viewfinder, '
      'never a live preview', (tester) async {
    fake.noCameras = true;
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // No hardware was ever created — the fallback is honest, not a fake feed.
    expect(fake.createCalls, 0);
    // The simulated-viewfinder hint is shown instead of a live preview.
    expect(find.textContaining('SIMULATED VIEWFINDER'), findsOneWidget);
  });
}
