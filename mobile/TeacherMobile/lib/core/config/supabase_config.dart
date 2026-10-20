import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Güvenli Supabase bağlantı yapılandırması.
/// Mobil uygulama sadece Oracle Cloud VM Self-Hosted Supabase sunucusuna bağlanır.
class SupabaseConfig {
  static const String _defaultPrimaryUrl = 'http://130.61.78.192:8000';
  static const String _b64PrimaryKey =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA==';

  static String _decodeKey(String b64) {
    try {
      return utf8.decode(base64Decode(b64));
    } catch (_) {
      return '';
    }
  }

  /// Birincil ve Tekil Sunucu URL (Oracle Cloud Self-Hosted Supabase)
  static String get primaryUrl {
    try {
      final envVal = dotenv.env['SUPABASE_URL'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _defaultPrimaryUrl;
  }

  /// Birincil ve Tekil Sunucu Anon Key
  static String get primaryKey {
    try {
      final envVal = dotenv.env['SUPABASE_ANON_KEY'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _decodeKey(_b64PrimaryKey);
  }
}
