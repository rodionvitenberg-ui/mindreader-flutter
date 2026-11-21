import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/tarot_deck_data.dart';
import 'package:mindreader/core/models/divination_card.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/reading_mode.dart';
import 'package:mindreader/core/services/oracle_voice_service.dart';
import 'package:mindreader/core/services/spread_inference_service.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/features/camera_scan/widgets/camera_mode_selector.dart';
import 'package:mindreader/features/camera_scan/widgets/camera_top_hud.dart';
import 'package:mindreader/features/camera_scan/widgets/guided_spread_hud.dart';
import 'package:mindreader/features/camera_scan/widgets/recognition_review_sheet.dart';
import 'package:mindreader/features/oracle/widgets/compact_oracle.dart';
import 'package:mindreader/features/oracle/widgets/oracle_voice_overlay.dart';
import 'package:mindreader/state/live_reading_controller.dart';

import 'fakes/fake_tts_engine.dart';

Widget _wrap360(Widget child) => MaterialApp(
      home: TaroGlassLayer(
        mode: TaroGlassMode.simple,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: 360, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'G6 CameraModeSelector uses TaroGlassSegmentedControl cleanly at 360px',
      (tester) async {
    var selected = ReadingMode.quickScan;
    await tester.pumpWidget(
      _wrap360(
        StatefulBuilder(
          builder: (context, setState) => CameraModeSelector(
            value: selected,
            onChanged: (m) => setState(() => selected = m),
          ),
        ),
      ),
    );

    expect(
      find.byType(TaroGlassSegmentedControl<ReadingMode>),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('camera-mode-guidedSpread')));
    await tester.pumpAndSettle();
    expect(selected, ReadingMode.guidedSpread);

    await tester.tap(find.byKey(const ValueKey('camera-mode-liveOracle')));
    await tester.pumpAndSettle();
    expect(selected, ReadingMode.liveOracle);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'G6 CameraTopHud uses TaroGlassSurface and >=44px TaroGlassIconButtons',
      (tester) async {
    var system = DivinationSystem.tarot;
    var flash = false;
    var gallery = 0;

    await tester.pumpWidget(
      _wrap360(
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CameraTopHud(
              system: system,
              onSystemChanged: (s) => setState(() => system = s),
              flashOn: flash,
              onToggleFlash: () => setState(() => flash = !flash),
              onPickGallery: () => gallery++,
              showActions: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TaroGlassIconButton), findsNWidgets(2));
    for (final e in tester.widgetList<TaroGlassIconButton>(
      find.byType(TaroGlassIconButton),
    )) {
      expect(e.size, greaterThanOrEqualTo(44));
    }

    await tester.tap(find.text('RUNES'));
    await tester.pumpAndSettle();
    expect(system, DivinationSystem.runes);

    await tester.tap(find.byTooltip('Turn flash on'));
    await tester.pumpAndSettle();
    expect(flash, isTrue);

    await tester.tap(find.byTooltip('Pick from gallery'));
    await tester.pump();
    expect(gallery, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'G6 GuidedSpreadHud uses TaroGlassPanel/Pill/Button at 360px width',
      (tester) async {
    var confirmed = 0;
    await tester.pumpWidget(
      _wrap360(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GuidedSpreadHud(
            spreadName: 'Triad Flow',
            filledCount: 2,
            totalSlots: 3,
            currentSlotRole: 'HIDDEN SHADOW',
            phase: GuidePhase.awaitingConfirmation,
            flashOn: false,
            onToggleFlash: () {},
            onPause: () {},
            onExit: () {},
            onConfirm: () => confirmed++,
            onResume: () {},
            onOpenChat: () {},
          ),
        ),
      ),
    );

    expect(find.byType(TaroGlassPanel), findsNWidgets(2));
    expect(find.byType(TaroGlassPill), findsOneWidget);
    expect(find.byType(TaroGlassIconButton), findsNWidgets(4));
    expect(find.byType(TaroGlassButton), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guided-primary-CONFIRM')));
    await tester.pump();
    expect(confirmed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'G6 RecognitionReviewSheet renders inside TaroGlassSheet with TaroGlassButton',
      (tester) async {
    final c0 = TarotDivinationCard(tarotDeck[0]);
    final c1 = TarotDivinationCard(tarotDeck[1]);
    final inference = const SpreadInferenceService().infer(
      const SpreadInferenceInput(
        system: DivinationSystem.tarot,
        detectedCount: 2,
      ),
    );

    RecognitionReviewResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await RecognitionReviewSheet.show(
                    context,
                    cards: [c0, c1],
                    reversed: [false, true],
                    inference: inference,
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byType(TaroGlassSheet), findsOneWidget);
    expect(find.byType(TaroGlassButton), findsOneWidget);
    expect(find.text('REVERSED'), findsOneWidget);

    await tester.tap(find.text('CONFIRM & PLACE ON TABLE'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.cards.length, 2);
  });

  testWidgets(
      'G6 CompactOracle & OracleVoiceOverlay use TaroGlassPanel without BackdropFilter at 360px',
      (tester) async {
    final voice = OracleVoiceService(engine: FakeTtsEngine());
    await voice.initialize();
    await voice.speak('The Star illuminates your next step across the waters.');

    await tester.pumpWidget(
      _wrap360(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompactOracle(
              voice: voice,
              onMicToggle: () {},
              onExpand: () {},
              onEnd: () {},
            ),
            const SizedBox(height: 12),
            OracleVoiceOverlay(
              voice: voice,
              subtitle: 'The Star illuminates your next step across the waters.',
              onMicToggle: () {},
              onCollapse: () {},
              onEnd: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TaroGlassPanel), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('LIVE ORACLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
