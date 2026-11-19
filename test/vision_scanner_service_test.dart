import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mindreader/core/services/vision_scanner_service.dart';

/// PHASE 5.4 — Performance: the CPU-bound JPEG compress runs off the UI
/// thread (via `compute`) but must keep its exact behavior — decodable output,
/// the ≤maxDim downscale, and a FormatException on unreadable bytes.
void main() {
  Uint8List png(int size) {
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(120, 40, 40));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('compressJpeg produces a decodable JPEG', () async {
    final jpeg = await VisionScannerService().compressJpeg(png(64));
    final decoded = img.decodeImage(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, 64);
    expect(decoded.height, 64);
  });

  test('compressJpeg downscales to maxDim', () async {
    final jpeg = await VisionScannerService().compressJpeg(png(64), maxDim: 32);
    final decoded = img.decodeImage(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, 32);
    expect(decoded.height, 32);
  });

  test('compressJpeg rejects unreadable bytes', () async {
    final service = VisionScannerService();
    await expectLater(
      service.compressJpeg(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
  });
}
