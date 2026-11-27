import 'dart:js_interop';

import 'telegram_webapp_service.dart';

@JS('__tarotTma')
external _TarotTmaJs? get _tarotTma;

extension type _TarotTmaJs._(JSObject _) implements JSObject {
  external bool isTelegram();
  external bool init();
  external JSString initData();
  external JSString startParam();
}

TelegramWebAppBridge createPlatformTelegramWebAppBridge() =>
    const _WebTelegramWebAppBridge();

class _WebTelegramWebAppBridge implements TelegramWebAppBridge {
  const _WebTelegramWebAppBridge();

  @override
  bool get isTelegram {
    final tma = _tarotTma;
    if (tma == null) return false;
    try {
      return tma.isTelegram();
    } catch (_) {
      return false;
    }
  }

  @override
  void initialize() {
    final tma = _tarotTma;
    if (tma == null) return;
    try {
      tma.init();
    } catch (_) {}
  }

  @override
  String get initData {
    final tma = _tarotTma;
    if (tma == null) return '';
    try {
      return tma.initData().toDart;
    } catch (_) {
      return '';
    }
  }

  @override
  String get startParam {
    final tma = _tarotTma;
    if (tma == null) return '';
    try {
      return tma.startParam().toDart;
    } catch (_) {
      return '';
    }
  }
}
