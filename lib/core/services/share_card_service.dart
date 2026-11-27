import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'web_file_download.dart';

/// How the rendered 9:16 PNG was delivered to the user.
enum ShareDeliveryOutcome { shared, downloaded, failed }

/// Platform delivery seam so widget & unit tests can verify PNG capture and
/// share invocations without touching OS share sheets.
abstract class ShareAdapter {
  Future<void> sharePngBytes(
    Uint8List bytes, {
    required String filename,
    String? text,
  });
}

class SharePlusAdapter implements ShareAdapter {
  const SharePlusAdapter({this.webDownloadFallback = triggerWebFileDownload});

  final bool Function(
    Uint8List bytes, {
    required String filename,
    String mimeType,
  }) webDownloadFallback;

  /// Tracks whether the most recent Web share fell back to direct PNG download.
  static bool lastDeliveryWasWebDownload = false;

  @override
  Future<void> sharePngBytes(
    Uint8List bytes, {
    required String filename,
    String? text,
  }) async {
    lastDeliveryWasWebDownload = false;
    if (kIsWeb) {
      try {
        final result = await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: filename)],
          text: text,
        );
        if (result.status == ShareResultStatus.unavailable) {
          final downloaded = webDownloadFallback(
            bytes,
            filename: filename,
            mimeType: 'image/png',
          );
          if (downloaded) {
            lastDeliveryWasWebDownload = true;
            return;
          }
          throw UnsupportedError('Web Share unavailable and download failed.');
        }
        return;
      } catch (_) {
        // Desktop browsers & WebViews often reject navigator.share({files}).
        // Fall back seamlessly to downloading the crisp 1080x1920 PNG.
        final downloaded = webDownloadFallback(
          bytes,
          filename: filename,
          mimeType: 'image/png',
        );
        if (downloaded) {
          lastDeliveryWasWebDownload = true;
          return;
        }
        rethrow;
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: filename)],
      text: text,
    );
  }
}

/// Captures a 9:16 [RepaintBoundary] into a crisp 1080x1920 PNG and invokes
/// the native OS share sheet (Stories, Telegram, Save to Gallery) — or falls
/// back to a direct PNG download on desktop browsers / WebViews.
class ShareCardService {
  ShareCardService._();

  static const ShareAdapter _defaultAdapter = SharePlusAdapter();

  @visibleForTesting
  static ShareAdapter? debugAdapterOverride;

  static ShareAdapter get _adapter => debugAdapterOverride ?? _defaultAdapter;

  static Future<Uint8List?> captureBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    final image = await ro.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static Future<ShareDeliveryOutcome> shareBoundaryDetailed(
    GlobalKey boundaryKey, {
    String filename = 'tarot_tree_story.png',
    String? caption,
    double pixelRatio = 3.0,
    ShareAdapter? adapter,
  }) async {
    final bytes = await captureBoundary(boundaryKey, pixelRatio: pixelRatio);
    if (bytes == null || bytes.isEmpty) return ShareDeliveryOutcome.failed;
    SharePlusAdapter.lastDeliveryWasWebDownload = false;
    await (adapter ?? _adapter).sharePngBytes(
      bytes,
      filename: filename,
      text: caption,
    );
    return SharePlusAdapter.lastDeliveryWasWebDownload
        ? ShareDeliveryOutcome.downloaded
        : ShareDeliveryOutcome.shared;
  }

  static Future<bool> shareBoundary(
    GlobalKey boundaryKey, {
    String filename = 'tarot_tree_story.png',
    String? caption,
    double pixelRatio = 3.0,
    ShareAdapter? adapter,
  }) async {
    final outcome = await shareBoundaryDetailed(
      boundaryKey,
      filename: filename,
      caption: caption,
      pixelRatio: pixelRatio,
      adapter: adapter,
    );
    return outcome != ShareDeliveryOutcome.failed;
  }
}
