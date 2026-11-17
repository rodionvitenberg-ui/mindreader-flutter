import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/data/deck_packs_registry.dart';
import 'package:mindreader/features/digital_table/widgets/tarot_card_3d_widget.dart';

void main() {
  // Regression: on real devices the very first frame can paint with a 0x0
  // surface ("FlutterRenderer: Width is zero"). `_paintObsidian` derived its
  // lattice step from size.width, so width 0 produced step 0 and an infinite
  // drawLine loop on the main thread — the app never reached the first
  // frame (black screen, 100% CPU, input dropped).
  test('CardBackPainter terminates on a zero-sized canvas (every style)', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painters = <CardBackPainter>[
      const CardBackPainter(pack: null), // default obsidian
      for (final pack in deckPacksRegistry) CardBackPainter(pack: pack),
    ];
    for (final painter in painters) {
      painter.paint(canvas, Size.zero);
      painter.paint(canvas, const Size(0, 120));
      painter.paint(canvas, const Size(60, 0));
    }
    // Reaching this line means no style hangs on a degenerate size.
    recorder.endRecording().dispose();
  });
}
