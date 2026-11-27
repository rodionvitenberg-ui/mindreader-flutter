import 'dart:js_interop';

import 'pwa_install_service.dart';

@JS('__tarotPwa')
external _TarotPwaJs? get _tarotPwa;

extension type _TarotPwaJs._(JSObject _) implements JSObject {
  external bool canPrompt();
  external bool isStandalone();
  external bool isIosSafari();
  external JSPromise<JSString> promptInstall();
}

PwaInstallBridge createPlatformPwaInstallBridge() => const _WebPwaInstallBridge();

class _WebPwaInstallBridge implements PwaInstallBridge {
  const _WebPwaInstallBridge();

  @override
  PwaInstallMode currentMode() {
    final pwa = _tarotPwa;
    if (pwa == null) return PwaInstallMode.unavailable;
    try {
      if (pwa.isStandalone()) return PwaInstallMode.unavailable;
      if (pwa.canPrompt()) return PwaInstallMode.nativePrompt;
      if (pwa.isIosSafari()) return PwaInstallMode.iosManualHint;
    } catch (_) {
      // Ignore JS interop failures on restricted webviews.
    }
    return PwaInstallMode.unavailable;
  }

  @override
  Future<bool> promptInstall() async {
    final pwa = _tarotPwa;
    if (pwa == null) return false;
    try {
      final outcome = (await pwa.promptInstall().toDart).toDart;
      return outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }
}
