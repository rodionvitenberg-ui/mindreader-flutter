import 'telegram_webapp_service.dart';

TelegramWebAppBridge createPlatformTelegramWebAppBridge() =>
    const _StubTelegramWebAppBridge();

class _StubTelegramWebAppBridge implements TelegramWebAppBridge {
  const _StubTelegramWebAppBridge();

  @override
  bool get isTelegram => false;

  @override
  void initialize() {}

  @override
  String get initData => '';

  @override
  String get startParam => '';
}
