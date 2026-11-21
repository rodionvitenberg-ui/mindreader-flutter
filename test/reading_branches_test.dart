import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindreader/core/models/tarot_card_model.dart';
import 'package:mindreader/state/spread_controller.dart';
import 'package:mindreader/state/app_settings_controller.dart';
import 'package:mindreader/features/digital_table/widgets/spread_threads_layer.dart';
import 'package:mindreader/features/digital_table/widgets/elemental_threads_painter.dart';

void main() {
  testWidgets('neighbor reveals grow independently during guided dealing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ctrl = SpreadController();
    final settings = AppSettingsController();
    await settings.setAid(ReadingAid.guide, true);
    var taps = 0;
    Future<void> render({bool reduced = false}) => tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ctrl),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned.fill(
                child: SpreadThreadsLayer(
                  rects: {
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
    List<double> growth() => tester
        .widgetList<CustomPaint>(branches)
        .map((w) => (w.painter! as ElementalBranchPainter).progress)
        .toList();

    await render();
    ctrl.dealNextCard();
    ctrl.dealNextCard();
    ctrl.flipSlot(1);
    await settings.setAid(ReadingAid.relationships, true);
    await tester.pump();
    expect(branches, findsNothing);
    ctrl.flipSlot(0);
    await tester.pump();
    expect(ctrl.allDealt, isFalse);
    expect(growth(), [0]);
    final firstBranch =
        (tester.widget<CustomPaint>(branches).painter!
                as ElementalBranchPainter)
            .segments
            .single;
    expect(firstBranch.start.dx, greaterThan(firstBranch.end.dx));
    await tester.pump(const Duration(milliseconds: 750));
    expect(growth(), [.5]);
    ctrl.dealNextCard();
    ctrl.flipSlot(2);
    await tester.pump();
    expect(growth(), [.5, 0]);
    await tester.pump(const Duration(milliseconds: 750));
    expect(growth(), [1, .5]);
    await tester.pump(const Duration(milliseconds: 750));
    expect(growth(), [1, 1]);
    await tester.tapAt(const Offset(50, 30));
    expect(taps, 1);
    await settings.setAid(ReadingAid.relationships, false);
    await tester.pump();
    expect(branches, findsNothing);
    await render(reduced: true);
    await settings.setAid(ReadingAid.relationships, true);
    await tester.pump();
    expect(growth(), [1, 1]);
    ctrl.resetTable();
    await tester.pump();
    expect(branches, findsNothing);
  });

  test('leaves unfold behind the growing tip', () {
    List<Rect> leavesAt(double progress) {
      final canvas = TestRecordingCanvas();
      ElementalBranchPainter(const [
        (start: Offset.zero, end: Offset(130, 0), element: Element.earth),
      ], progress).paint(canvas, const Size(150, 100));
      return [
        for (final call in canvas.invocations.map((r) => r.invocation))
          if (call.memberName == #drawPath &&
              (call.positionalArguments[1] as Paint).style ==
                  PaintingStyle.fill)
            (call.positionalArguments.first as Path).getBounds(),
      ];
    }

    expect(leavesAt(.1), isEmpty);
    final firstBud = leavesAt(.32).single;
    final later = leavesAt(.63);
    expect(later, hasLength(2));
    expect(later.first.width, greaterThan(firstBud.width));
    expect(later.first.height, greaterThan(firstBud.height));
    expect(leavesAt(1), hasLength(3));
  });
}
