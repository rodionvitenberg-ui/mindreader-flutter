import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/main.dart';

void main() {
  testWidgets('diag-camera', (tester) async {
    await tester.pumpWidget(const MindreaderApp());
    await tester.pump();
    await tester.tap(find.text('CAMERA'));
    await tester.pump();
    debugPrint('mock texts: '
        '${find.textContaining('MOCK MODE').evaluate().length}');
    debugPrint('sim texts: '
        '${find.textContaining('SIMULATED VIEWFINDER').evaluate().length}');
    debugPrint('point: '
        '${find.textContaining('POINT AT YOUR SPREAD').evaluate().length}');
  });
}
