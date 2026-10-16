// lib/core/constants/app_constants.dart
class AppConstants {
  // Supabase bilgileri
  static const String supabaseUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0'
      '.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8';
  static const String supabaseServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mjk4Nzg4NCwiZXhwIjoyMDk4NTYzODg0fQ'
      '.Pe4I_qm_qr3HfGNoPFTbbEoQbP1ZD0-KOVZfpI1OJ8c';

  // Süper admin e-posta listesi (ek kontrol için)
  static const List<String> superAdminEmails = [
    'admin@sinif360.com',
  ];

  // Tahta durum sabitleri
  static const int offlineThresholdMinutes = 5;

  // Otomatik kilit süreleri
  static const List<int> autoLockOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  // Uygulama adı
  static const String appName = 'Sınıf360 Web Paneli';
}
