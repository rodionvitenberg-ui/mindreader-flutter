import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindreader/state/app_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('old installations get quiet defaults and each setting round-trips', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'ru'});
    final settings = AppSettingsController();
    await settings.load();
    for (final aid in ReadingAid.values) {
      expect(settings.enabled(aid), aid == ReadingAid.positions);
      await settings.setAid(aid, aid != ReadingAid.positions);
    }
    final restored = AppSettingsController();
    await restored.load();
    expect(restored.language.name, 'ru');
    for (final aid in ReadingAid.values) {
      expect(restored.enabled(aid), aid != ReadingAid.positions);
    }
  });
}
