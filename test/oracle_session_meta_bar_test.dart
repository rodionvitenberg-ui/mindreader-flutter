import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/features/digital_table/widgets/oracle_session_meta_bar.dart';
import 'package:mindreader/state/oracle_session_controller.dart';

void main() {
  group('oraclePhysicalCtaLabel', () {
    test('digital standard has no CTA', () {
      expect(
        oraclePhysicalCtaLabel(ReadingSource.digital, ReadingMode.standard),
        isNull,
      );
    });

    test('physical standard -> RETURN TO PHYSICAL SPREAD', () {
      expect(
        oraclePhysicalCtaLabel(ReadingSource.physical, ReadingMode.standard),
        'RETURN TO PHYSICAL SPREAD',
      );
    });

    test('quickScan and liveOracle -> RESUME CAMERA', () {
      expect(
        oraclePhysicalCtaLabel(ReadingSource.physical, ReadingMode.quickScan),
        'RESUME CAMERA',
      );
      expect(
        oraclePhysicalCtaLabel(ReadingSource.physical, ReadingMode.liveOracle),
        'RESUME CAMERA',
      );
    });

    test('guidedSpread -> CONTINUE GUIDED SESSION', () {
      expect(
        oraclePhysicalCtaLabel(
          ReadingSource.physical,
          ReadingMode.guidedSpread,
        ),
        'CONTINUE GUIDED SESSION',
      );
    });
  });

  group('OracleSessionMetaBar', () {
    OracleSessionController physicalGuidedSession() => OracleSessionController()
      ..beginSession(
        source: ReadingSource.physical,
        mode: ReadingMode.guidedSpread,
      );

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('collapses for a digital standard reading', (tester) async {
      final session = OracleSessionController();

      await tester.pumpWidget(
        wrap(OracleSessionMetaBar(session: session, onResumeCamera: () {})),
      );

      expect(find.text('PHYSICAL'), findsNothing);
      expect(find.text('DIGITAL'), findsNothing);
      expect(find.text('STANDARD'), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('shows source and resume action for a physical reading', (
      tester,
    ) async {
      final session = physicalGuidedSession();

      await tester.pumpWidget(
        wrap(OracleSessionMetaBar(session: session, onResumeCamera: () {})),
      );

      expect(find.text('PHYSICAL'), findsOneWidget);
      expect(find.text('GUIDED SPREAD'), findsOneWidget);
      expect(find.text('CONTINUE GUIDED SESSION'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('tapping the CTA fires onResumeCamera', (tester) async {
      final session = physicalGuidedSession();
      var resumed = 0;

      await tester.pumpWidget(
        wrap(
          OracleSessionMetaBar(
            session: session,
            onResumeCamera: () => resumed++,
          ),
        ),
      );

      await tester.tap(find.text('CONTINUE GUIDED SESSION'));
      await tester.pump();
      expect(resumed, 1);
    });

    testWidgets('no CTA for a digital standard reading', (tester) async {
      final session = OracleSessionController();

      await tester.pumpWidget(
        wrap(OracleSessionMetaBar(session: session, onResumeCamera: () {})),
      );

      expect(find.text('RESUME CAMERA'), findsNothing);
      expect(find.text('RETURN TO PHYSICAL SPREAD'), findsNothing);
      expect(find.text('CONTINUE GUIDED SESSION'), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });
  });
}
