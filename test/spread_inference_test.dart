import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/models/divination_system.dart';
import 'package:mindreader/core/models/lenormand_spread.dart';
import 'package:mindreader/core/models/rune_cast.dart';
import 'package:mindreader/core/models/spread_type.dart';
import 'package:mindreader/core/services/spread_inference_service.dart';
import 'package:mindreader/core/services/vision/vision_engine.dart';

void main() {
  const svc = SpreadInferenceService();

  test('tarot: exact count resolves to a single template', () {
    final r = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.tarot, detectedCount: 3),
    );
    expect(r.isFreeform, isFalse);
    expect(r.needsConfirmation, isFalse);
    expect(r.top?.tarot, SpreadType.three);
    expect(r.top?.slotRoles, SpreadType.three.slotRoles);
  });

  test('tarot: Celtic Cross resolves and is open without PRO', () {
    final r = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.tarot, detectedCount: 10),
    );
    expect(r.top?.tarot, SpreadType.celticCross);
    expect(r.top?.isPro, isFalse);
  });

  test('lenormand: count 9 is AMBIGUOUS (nine vs grandPortrait)', () {
    final r = svc.infer(
      const SpreadInferenceInput(
        system: DivinationSystem.lenormand,
        detectedCount: 9,
      ),
    );
    expect(r.needsConfirmation, isTrue);
    expect(r.candidates.length, 2);
    expect(r.candidates.any((c) => c.lenormand == LenormandSpread.nine), isTrue);
    expect(
      r.candidates.any((c) => c.lenormand == LenormandSpread.grandPortrait),
      isTrue,
    );
    // top stays deterministic (first enum value), but review must confirm.
    expect(r.top?.lenormand, LenormandSpread.nine);
  });

  test('runes: exact count resolves', () {
    final r = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.runes, detectedCount: 7),
    );
    expect(r.top?.rune, RuneCast.seven);
  });

  test('no template → Freeform (cards are preserved, not dropped)', () {
    final r = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.tarot, detectedCount: 8),
    );
    expect(r.isFreeform, isTrue);
    expect(r.top, isNull);
    // The raw count is preserved so the handoff keeps ALL 8 cards.
    expect(r.detectedCount, 8);
  });

  test('confirmedCount overrides detectedCount', () {
    final r = svc.infer(
      const SpreadInferenceInput(
        system: DivinationSystem.tarot,
        detectedCount: 5,
        confirmedCount: 3,
      ),
    );
    expect(r.top?.tarot, SpreadType.three);
  });

  test('geometry is optional and only flags availability', () {
    final noGeo = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.tarot, detectedCount: 3),
    );
    expect(noGeo.hasGeometry, isFalse);

    final withGeo = svc.infer(
      SpreadInferenceInput(
        system: DivinationSystem.tarot,
        detectedCount: 3,
        positions: const [
          NormalizedPoint(0.08, 0.5),
          NormalizedPoint(0.5, 0.5),
          NormalizedPoint(0.92, 0.5),
        ],
      ),
    );
    expect(withGeo.hasGeometry, isTrue);
    // Geometry does not change the count-based candidate.
    expect(withGeo.top?.tarot, SpreadType.three);
  });

  test('zero/negative count → Freeform', () {
    final r = svc.infer(
      const SpreadInferenceInput(system: DivinationSystem.tarot, detectedCount: 0),
    );
    expect(r.isFreeform, isTrue);
  });
}
