// lib/core/utils/download_helper_stub.dart
import 'package:url_launcher/url_launcher.dart';

Future<bool> downloadFileUniversal(String url, String filename) async {
  try {
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    return false;
  }
}
