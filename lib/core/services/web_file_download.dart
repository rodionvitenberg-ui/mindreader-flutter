import 'dart:typed_data';

import 'web_file_download_stub.dart'
    if (dart.library.js_interop) 'web_file_download_web.dart';

/// Triggers an instant browser file download on Web (`<a download>` + Blob URL).
/// Returns `true` if the download was initiated, `false` on non-Web platforms.
bool triggerWebFileDownload(
  Uint8List bytes, {
  required String filename,
  String mimeType = 'image/png',
}) =>
    triggerPlatformWebFileDownload(
      bytes,
      filename: filename,
      mimeType: mimeType,
    );
