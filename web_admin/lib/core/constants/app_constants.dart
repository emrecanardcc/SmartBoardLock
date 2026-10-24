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

    // Web tarayıcısında çalışırken:
    // Eğer HTTPS üzerinden açıldıysa (örn: https://panel-sinif360.pages.dev veya https://panel.sinif360.app)
    // Mixed Content hatasını önlemek için doğrudan aynı origin üzerindeki /backend proxy'sini kullanır.
    if (Uri.base.scheme == 'https') {
      return '${Uri.base.origin}/backend';
    }

    // Eğer doğrudan IP üzerinden açıldıysa (örn: http://130.61.78.192/admin/)
    if (Uri.base.host.isNotEmpty && Uri.base.host != 'localhost') {
      return 'http://${Uri.base.host}/backend';
    }

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

  // Uygulama ve Sunucu Versiyon Bilgileri
  static const String appName = 'Sınıf360';
  static const String appVersion = '2.1.2';
  static const String serverVersion = 'v2.1.2';
  static const String serverHost = 'Oracle Cloud (130.61.78.192)';
  static const String serverReleaseDate = '24 Ekim 2026';
  static const String serverStatus = 'Aktif & Güncel';

  // Supabase Studio 1-Click Bilgileri
  static const String studioToken = '0acc0bd6f232996646fa6e77a2ff3262';
  static const String studioDirectUrl = 'http://130.61.78.192:8000';
  static String get studioLaunchUrl => '$studioDirectUrl/?studio_token=$studioToken';
}
