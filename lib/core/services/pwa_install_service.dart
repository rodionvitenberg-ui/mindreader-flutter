import 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart';

/// Availability state of PWA "Add to Home Screen" installation.
enum PwaInstallMode {
  /// Running natively, already installed as standalone, or unsupported browser.
  unavailable,

  /// Browser fired `beforeinstallprompt` — can open native install dialog.
  nativePrompt,

  /// iOS Safari in browser tab — show Share -> Add to Home Screen hint.
  iosManualHint,
}

/// Platform seam for detecting and triggering PWA installation.
abstract class PwaInstallBridge {
  PwaInstallMode currentMode();
  Future<bool> promptInstall();
}

PwaInstallBridge createPwaInstallBridge() => createPlatformPwaInstallBridge();
