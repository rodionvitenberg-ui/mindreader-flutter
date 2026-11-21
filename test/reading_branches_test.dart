import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/features/digital_table/widgets/spread_threads_layer.dart';
import 'package:mindreader/features/digital_table/widgets/elemental_threads_painter.dart';

void main() {
  testWidgets(
    'selected confirmed links respect preferences, reduced motion and taps',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = SpreadController();
      final settings = AppSettingsController();
      for (var i = 0; i < 3; i++) {
        ctrl.dealNextCard();
        ctrl.flipSlot(i);
      }
      var taps = 0;
      Future<void> render(int? selected) => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ctrl),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Stack(
              textDirection: TextDirection.ltr,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                  ),
                ),
                Positioned.fill(
                  child: SpreadThreadsLayer(
                    selected: selected,
                    rects: const {
                      0: Rect.fromLTWH(0, 0, 40, 65),
                      1: Rect.fromLTWH(60, 0, 40, 65),
                      2: Rect.fromLTWH(120, 0, 40, 65),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final branches = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ElementalBranchPainter,
      );
      await render(1);
      expect(branches, findsNothing);
      await settings.setAid(ReadingAid.relationships, true);
      await render(null);
      expect(branches, findsNothing);
      await render(1);
      expect(branches, findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(branches).painter!
              as ElementalBranchPainter;
      expect(painter.progress, 1);
      expect(painter.segments.length, 2);
      await tester.tapAt(const Offset(50, 30));
      expect(taps, 1);
    },
  );
}
