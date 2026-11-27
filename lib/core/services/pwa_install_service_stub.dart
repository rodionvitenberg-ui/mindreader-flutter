import 'pwa_install_service.dart';

PwaInstallBridge createPlatformPwaInstallBridge() => const _StubPwaInstallBridge();

class _StubPwaInstallBridge implements PwaInstallBridge {
  const _StubPwaInstallBridge();

  @override
  PwaInstallMode currentMode() => PwaInstallMode.unavailable;

  @override
  Future<bool> promptInstall() async => false;
}
