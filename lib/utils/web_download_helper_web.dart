// lib/utils/web_download_helper_web.dart
// Web-specific implementation using dart:html
import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileWebImpl(Uint8List bytes, String fileName) {
  try {
    // Create blob from bytes
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create anchor element and trigger download
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    // Clean up
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    print('Error downloading file on web: $e');
  }
}
