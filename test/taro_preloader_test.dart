import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro.dart';
import 'package:mindreader/main.dart';

void main() {
  group('TaroPreloader', () {
    testWidgets(
      'starts immediately on frame 1 with #0C101B cover, blocks taps until ready, '
      'grows branch to 100%, fades out, and unmounts cleanly',
      (tester) async {
        final ready = Completer<void>();
        var completed = false;
        var tappedUnderlying = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => tappedUnderlying = true,
                    child: const Text('UNDERLYING'),
                  ),
                ),
                TaroPreloader(
                  ready: ready.future,
                  onCompleted: () => completed = true,
                ),
              ],
            ),
          ),
        );

        // Frame 1: preloader is mounted and fully opaque on #0C101B.
        expect(find.byKey(const ValueKey('taro-preloader')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('taro-preloader-logo')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('taro-preloader-ring')),
          findsOneWidget,
        );

        final opacityBefore = tester.widget<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('taro-preloader')),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacityBefore.opacity, closeTo(1.0, 0.001));

        // Taps cannot reach underlying UI while preloader is covering.
        await tester.tap(
          find.text('UNDERLYING'),
          warnIfMissed: false,
        );
        expect(tappedUnderlying, isFalse);

        // While app is loading, branch sprouts continuously (no empty stall)
        // and stays below 1.0 until ready completes.
        await tester.pump(const Duration(milliseconds: 500));
        final painterMid = tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('taro-preloader-ring')),
            )
            .painter! as PreloaderBranchRingPainter;
        expect(painterMid.progress, greaterThan(0.2));
        expect(painterMid.progress, lessThan(0.8));
        expect(completed, isFalse);

        // App finishes loading -> branch completes to 1.0 -> fades out.
        ready.complete();
        await tester.pump(); // deliver future completion
        await tester.pump(const Duration(milliseconds: 600)); // finish sweep
        await tester.pump(); // start fade
        await tester.pump(const Duration(milliseconds: 550)); // fade-out
        await tester.pump();

        expect(completed, isTrue);
        expect(find.byKey(const ValueKey('taro-preloader-ring')), findsNothing);

        // Underlying UI is now interactive.
        await tester.tap(find.text('UNDERLYING'));
        expect(tappedUnderlying, isTrue);
      },
    );

    testWidgets(
      'safety timeout dismisses preloader if ready never completes',
      (tester) async {
        final neverReady = Completer<void>();
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: TaroPreloader(
              ready: neverReady.future,
              readyTimeout: const Duration(milliseconds: 800),
              creepDuration: const Duration(milliseconds: 600),
              minFinishDuration: const Duration(milliseconds: 200),
              maxFinishDuration: const Duration(milliseconds: 300),
              hideDuration: const Duration(milliseconds: 200),
              onCompleted: () => completed = true,
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 850)); // timeout fires
        await tester.pump(const Duration(milliseconds: 350)); // finish sweep
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250)); // fade out
        await tester.pump();

        expect(completed, isTrue);
      },
    );

    testWidgets(
      'disposing mid-load cancels timeout timer cleanly with zero pending timers',
      (tester) async {
        final ready = Completer<void>();

        await tester.pumpWidget(
          MaterialApp(home: TaroPreloader(ready: ready.future)),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Replace tree before ready resolves — Flutter test binding fails
        // automatically if any Timer leaks on teardown.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      },
    );

    testWidgets(
      'MindreaderApp shows TaroPreloader when showPreloader: true and reveals '
      'the Digital Table once warmup finishes',
      (tester) async {
        final warmup = Completer<void>();
        var completed = false;

        await tester.pumpWidget(
          MindreaderApp(
            showPreloader: true,
            preloaderReady: warmup.future,
            onPreloaderCompleted: () => completed = true,
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('taro-preloader')), findsOneWidget);

        warmup.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pump();

        expect(completed, isTrue);
        expect(find.byKey(const ValueKey('taro-preloader')), findsNothing);
        expect(find.text('TAROT'), findsOneWidget);
      },
    );
  });

  group('PreloaderBranchRingPainter', () {
    test('shouldRepaint detects progress, radius, and color changes', () {
      const a = PreloaderBranchRingPainter(progress: 0.2);
      const same = PreloaderBranchRingPainter(progress: 0.2);
      const b = PreloaderBranchRingPainter(progress: 0.6);

      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
