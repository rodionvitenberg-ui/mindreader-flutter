import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/models/reading_source.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/features/digital_table/widgets/oracle_session_meta_bar.dart';
import 'package:mindreader/state/oracle_session_controller.dart';

import 'fakes/fake_tts_engine.dart';

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

    Future<OracleVoiceService> availableVoice() async {
      final voice = OracleVoiceService(engine: FakeTtsEngine());
      await voice.initialize();
      return voice;
    }

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('collapses for a digital standard reading with no TTS',
        (tester) async {
      final session = OracleSessionController();
      final voice = OracleVoiceService(engine: FakeTtsEngine()..languages = []);
      await voice.initialize();

      await tester.pumpWidget(wrap(OracleSessionMetaBar(
        session: session,
        voice: voice,
        onResumeCamera: () {},
      )));

      expect(find.text('PHYSICAL'), findsNothing);
      expect(find.text('DIGITAL'), findsNothing);
      expect(find.text('STANDARD'), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('shows source + mode badges, voice toggle and CTA for physical',
        (tester) async {
      final session = physicalGuidedSession();
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleSessionMetaBar(
        session: session,
        voice: voice,
        onResumeCamera: () {},
      )));

      expect(find.text('PHYSICAL'), findsOneWidget);
      expect(find.text('GUIDED SPREAD'), findsOneWidget);
      expect(find.text('CONTINUE GUIDED SESSION'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('tapping the CTA fires onResumeCamera', (tester) async {
      final session = physicalGuidedSession();
      final voice = await availableVoice();
      var resumed = 0;

      await tester.pumpWidget(wrap(OracleSessionMetaBar(
        session: session,
        voice: voice,
        onResumeCamera: () => resumed++,
      )));

      await tester.tap(find.text('CONTINUE GUIDED SESSION'));
      await tester.pump();
      expect(resumed, 1);
    });

    testWidgets('tapping the voice toggle mutes the Oracle', (tester) async {
      final session = physicalGuidedSession();
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleSessionMetaBar(
        session: session,
        voice: voice,
        onResumeCamera: () {},
      )));

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pump();
      expect(voice.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });

    testWidgets('no CTA for a digital standard reading', (tester) async {
      final session = OracleSessionController();
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleSessionMetaBar(
        session: session,
        voice: voice,
        onResumeCamera: () {},
      )));

      expect(find.text('RESUME CAMERA'), findsNothing);
      expect(find.text('RETURN TO PHYSICAL SPREAD'), findsNothing);
      expect(find.text('CONTINUE GUIDED SESSION'), findsNothing);
      // The voice toggle is still present (TTS available).
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });
  });
}
