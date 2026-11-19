import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/models/voice_state.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/theme/app_colors.dart';
import 'package:mindreader/features/oracle/widgets/oracle_presence_indicator.dart';
import 'package:mindreader/features/oracle/widgets/oracle_subtitles.dart';
import 'package:mindreader/features/oracle/widgets/oracle_voice_overlay.dart';

import 'fakes/fake_tts_engine.dart';

void main() {
  group('oraclePresenceColor / oraclePresenceActive', () {
    test('speaking and paused are lavender and active', () {
      expect(oraclePresenceColor(VoiceState.speaking, false), AppColors.lavender);
      expect(oraclePresenceColor(VoiceState.paused, false), AppColors.lavender);
      expect(oraclePresenceActive(VoiceState.speaking), isTrue);
      expect(oraclePresenceActive(VoiceState.paused), isFalse);
    });

    test('muted overrides every color to textMuted', () {
      expect(oraclePresenceColor(VoiceState.speaking, true), AppColors.textMuted);
      expect(oraclePresenceColor(VoiceState.idle, false), AppColors.textMuted);
      expect(oraclePresenceColor(VoiceState.thinking, true), AppColors.textMuted);
    });

    test('idle and unavailable are never active', () {
      expect(oraclePresenceActive(VoiceState.idle), isFalse);
      expect(oraclePresenceActive(VoiceState.unavailable), isFalse);
    });
  });

  group('OracleVoiceOverlay', () {
    Future<OracleVoiceService> availableVoice() async {
      final voice = OracleVoiceService(engine: FakeTtsEngine());
      await voice.initialize();
      return voice;
    }

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('renders the subtitle text and presence marker', (tester) async {
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: 'The Fool begins a long journey.',
      )));

      expect(find.text('The Fool begins a long journey.'), findsOneWidget);
      expect(find.byType(OraclePresenceIndicator), findsOneWidget);
      expect(find.text('LIVE ORACLE'), findsOneWidget);
    });

    testWidgets('mute toggle silences the Oracle', (tester) async {
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: 'answer',
      )));

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pump();
      expect(voice.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });

    testWidgets('interrupt and pause appear while speaking; stop interrupts',
        (tester) async {
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: 'answer',
      )));

      await voice.speak('a long answer');
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(voice.state, VoiceState.idle);
    });

    testWidgets('collapse and end fire their callbacks', (tester) async {
      final voice = await availableVoice();
      var collapsed = 0;
      var ended = 0;

      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: 'answer',
        onCollapse: () => collapsed++,
        onEnd: () => ended++,
      )));

      await tester.tap(find.byIcon(Icons.unfold_less));
      await tester.pump();
      expect(collapsed, 1);

      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pump();
      expect(ended, 1);
    });

    testWidgets('empty subtitle renders no caption', (tester) async {
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: '',
      )));

      expect(find.byType(OracleSubtitles), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });
}
