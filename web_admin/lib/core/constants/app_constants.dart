// lib/core/constants/app_constants.dart
class AppConstants {
  // Supabase bilgileri (Self-Hosted Oracle Always Free)
  static const String supabaseUrl = 'http://130.61.78.192:8000';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkyMjI1OTQ5LCJleHAiOjE5NDk5MDU5NDl9'
      '.sk8yBULVd4I88d6zbbvYFBtLETiDhr0Ipq2gG6E4ih0';
  // Service-role anahtarı güvenlik nedeniyle kod deposunda saklanmaz; derleme anında --dart-define ile verilebilir
  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: '',
  );

  // Süper admin e-posta listesi (ek kontrol için)
  static const List<String> superAdminEmails = [
    'admin@sinif360.com',
  ];

  // Tahta durum sabitleri
  static const int offlineThresholdMinutes = 5;

  // Uygulama adı
  static const String appName = 'Sınıf360 Web Paneli';
}
