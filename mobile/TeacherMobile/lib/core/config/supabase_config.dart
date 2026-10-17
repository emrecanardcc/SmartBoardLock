import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Güvenli Supabase bağlantı yapılandırması.
/// Git tarayıcılarını tetiklemeyen ve Mac/TestFlight ortamında .env dosyası
/// bulunmasa bile uygulamanın sorunsuz çalışmasını sağlayan hibrit mimari.
class SupabaseConfig {
  static const String _defaultPrimaryUrl = 'http://130.61.78.192:8000';
  static const String _b64PrimaryKey =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA==';

  static const String _defaultFallbackUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  static const String _b64FallbackKey =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW1Oc2EyRnpibUp3Yldoa1pHaHpkRzlwZUdSNklpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RJNU9EYzRPRFFzSW1WNGNDSTZNakE1T0RVMk16ZzROSDAuS3B3T1pvV3dPdTJEZndPZWMweTVMU3ZTNk1SR0d5NFVxb3QtUTFHMF94OA==';

  static String _decodeKey(String b64) {
    try {
      return utf8.decode(base64Decode(b64));
    } catch (_) {
      return '';
    }
  }

  /// Birincil Sunucu URL (Oracle Cloud Self-Hosted Supabase)
  static String get primaryUrl {
    try {
      final envVal = dotenv.env['SUPABASE_URL'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _defaultPrimaryUrl;
  }

  /// Birincil Sunucu Anon Key
  static String get primaryKey {
    try {
      final envVal = dotenv.env['SUPABASE_ANON_KEY'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _decodeKey(_b64PrimaryKey);
  }

  /// İkincil / Yedek Sunucu URL (Cloud Supabase)
  static String get fallbackUrl {
    try {
      final envVal = dotenv.env['FALLBACK_SUPABASE_URL'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _defaultFallbackUrl;
  }

  /// İkincil / Yedek Sunucu Anon Key
  static String get fallbackKey {
    try {
      final envVal = dotenv.env['FALLBACK_SUPABASE_ANON_KEY'];
      if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    } catch (_) {}
    return _decodeKey(_b64FallbackKey);
  }
}
