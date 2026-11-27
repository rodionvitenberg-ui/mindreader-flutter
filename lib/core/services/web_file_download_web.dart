import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool triggerPlatformWebFileDownload(
  Uint8List bytes, {
  required String filename,
  String mimeType = 'image/png',
}) {
  try {
    final blobParts = <JSAny>[bytes.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));
    final objectUrl = web.URL.createObjectURL(blob);
    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = objectUrl
          ..download = filename
          ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // Defer URL revocation slightly so the browser starts streaming the blob.
    Future<void>.delayed(
      const Duration(seconds: 2),
      () => web.URL.revokeObjectURL(objectUrl),
    );
    return true;
  } catch (_) {
    return false;
  }
}
