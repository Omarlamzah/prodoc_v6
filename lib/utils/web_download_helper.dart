// lib/utils/web_download_helper.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import for web
import 'web_download_helper_stub.dart'
    if (dart.library.html) 'web_download_helper_web.dart' as web_helper;

/// Helper function to download a file on web using bytes
void downloadFileWeb(Uint8List bytes, String fileName) {
  if (!kIsWeb) return;
  web_helper.downloadFileWebImpl(bytes, fileName);
}
