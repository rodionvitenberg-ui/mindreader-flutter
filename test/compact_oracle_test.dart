import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/features/oracle/widgets/compact_oracle.dart';
import 'package:mindreader/features/oracle/widgets/oracle_presence_indicator.dart';
import 'package:mindreader/features/oracle/widgets/oracle_voice_overlay.dart';

import 'fakes/fake_tts_engine.dart';

void main() {
  Future<OracleVoiceService> availableVoice() async {
    final voice = OracleVoiceService(engine: FakeTtsEngine());
    await voice.initialize();
    return voice;
  }

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('CompactOracle', () {
    testWidgets('renders as a floating capsule with presence', (tester) async {
      final voice = await availableVoice();

      await tester.pumpWidget(wrap(CompactOracle(voice: voice)));

      expect(find.byType(OraclePresenceIndicator), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('shows the expand button and fires onExpand', (tester) async {
      final voice = await availableVoice();
      var expanded = 0;

      await tester.pumpWidget(wrap(CompactOracle(
        voice: voice,
        onExpand: () => expanded++,
      )));

      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pump();
      expect(expanded, 1);
    });

    testWidgets('mute toggle + end work from the capsule', (tester) async {
      final voice = await availableVoice();
      var ended = 0;

      await tester.pumpWidget(wrap(CompactOracle(
        voice: voice,
        onEnd: () => ended++,
      )));

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      await tester.pump();
      expect(voice.isMuted, isTrue);

      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pump();
      expect(ended, 1);
    });

    testWidgets('mic toggle fires onMicToggle', (tester) async {
      final voice = await availableVoice();
      var mic = 0;

      await tester.pumpWidget(wrap(CompactOracle(
        voice: voice,
        onMicToggle: () => mic++,
      )));

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      expect(mic, 1);
    });
  });

  group('voice session continuity across views', () {
    testWidgets('Compact ↔ Overlay share ONE voice session (no reset)',
        (tester) async {
      final voice = await availableVoice();

      // Start speaking, then mute — the shared service holds the session.
      await voice.speak('the oracle speaks');
      await voice.setMuted(true);

      // Render the compact capsule first.
      await tester.pumpWidget(wrap(CompactOracle(voice: voice)));
      expect(voice.isMuted, isTrue);

      // Swap to the full overlay with the SAME service.
      await tester.pumpWidget(wrap(OracleVoiceOverlay(
        voice: voice,
        subtitle: 'the oracle speaks',
      )));

      // The voice session (mute) survived the view transition — it was never
      // reset, because both views depend on the one shared instance.
      expect(voice.isMuted, isTrue);

      // Unmute from the overlay and confirm the shared instance is unmuted.
      await tester.tap(find.byIcon(Icons.volume_off_outlined));
      await tester.pump();
      expect(voice.isMuted, isFalse);
    });
  });
}
