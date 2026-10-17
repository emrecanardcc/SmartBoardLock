// lib/core/constants/app_constants.dart
import 'dart:convert';

class AppConstants {
  // Supabase bilgileri (Self-Hosted Oracle Always Free)
  static const String _defaultUrl = 'http://130.61.78.192:8000';
  static const String _b64AnonKey =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA==';
  static const String _b64ServiceRoleKey =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaWMyVnlkbWxqWlY5eWIyeGxJaXdpYVhOeklqb2ljM1Z3WVdKaGMyVWlMQ0pwWVhRaU9qRTNPVEl5TWpVNU5Ea3NJbVY0Y0NJNk1UazBPVGt3TlRrME9YMC40UGpDdTVFVmxjeHExbHJkWGZTRVJTX2h3WC14cDVpUlF4aGV5eXRNaWlV';

  /// Dinamik Supabase URL (derleme anında SUPABASE_URL ile override edilebilir)
  static String get supabaseUrl {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    if (envUrl.trim().isNotEmpty) return envUrl.trim();
    return _defaultUrl;
  }

  /// Dinamik Anon Key (derleme anında SUPABASE_ANON_KEY ile override edilebilir)
  static String get supabaseAnonKey {
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.trim().isNotEmpty) return envKey.trim();
    try {
      return utf8.decode(base64Decode(_b64AnonKey));
    } catch (_) {
      return '';
    }
  }

  /// Dinamik Service Role Key (derleme anında SUPABASE_SERVICE_ROLE_KEY ile override edilebilir)
  static String get supabaseServiceRoleKey {
    const envKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
    if (envKey.trim().isNotEmpty) return envKey.trim();
    try {
      return utf8.decode(base64Decode(_b64ServiceRoleKey));
    } catch (_) {
      return '';
    }
  }

  // Süper admin e-posta listesi (ek kontrol için)
  static const List<String> superAdminEmails = [
    'admin@sinif360.com',
  ];

  // Tahta durum sabitleri
  static const int offlineThresholdMinutes = 5;

  // Uygulama adı
  static const String appName = 'Sınıf360 Web Paneli';
}
