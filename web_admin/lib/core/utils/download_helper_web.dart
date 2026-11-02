// lib/core/utils/download_helper_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> downloadFileUniversal(String url, String filename) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (e) {
    try {
      html.window.open(url, '_blank');
      return true;
    } catch (_) {
      return false;
    }
  }
}
