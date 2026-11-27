import 'telegram_webapp_service_stub.dart'
    if (dart.library.js_interop) 'telegram_webapp_service_web.dart';

/// Platform bridge for Telegram Mini App (TMA) runtime & deep links.
abstract class TelegramWebAppBridge {
  bool get isTelegram;
  void initialize();
  String get initData;
  String get startParam;
}

TelegramWebAppBridge createTelegramWebAppBridge() =>
    createPlatformTelegramWebAppBridge();

/// Maps a Telegram `startapp` / `?startapp=` deep-link token to a shell tab.
int? tabIndexForStartParam(String raw) {
  final token = raw.trim().toLowerCase();
  if (token.isEmpty) return null;
  if (token == 'camera' || token == 'scan') return 0;
  if (token == 'table' || token == 'spread') return 1;
  if (token == 'almanac' || token == 'learn') return 2;
  if (token == 'astral' || token == 'natal' || token == 'synastry') return 3;
  if (token == 'daily' ||
      token == 'lunar' ||
      token == 'checkin' ||
      token == 'rituals') {
    return 4;
  }
  return null;
}
