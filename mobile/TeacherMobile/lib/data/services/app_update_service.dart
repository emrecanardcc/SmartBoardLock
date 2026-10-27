import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mobil uygulama sürüm ve zorunlu güncelleme modeli
class AppUpdateInfo {
  final String currentVersion;
  final String minVersion;
  final String latestVersion;
  final String storeUrl;
  final String title;
  final String message;
  final bool isForced;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.minVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.title,
    required this.message,
    required this.isForced,
  });
}

/// Sınıf360 Mobil Zorunlu ve Önerilen Güncelleme Yönetim Motoru.
/// Supabase `mobile_app_versions` tablosundan canlı sürüm gereksinimlerini denetler.
class AppUpdateService {
  /// Bu uygulamanın mevcut sürümü (pubspec.yaml ile senkron)
  static const String currentAppVersion = '2.1.3';
  static const int currentBuildNumber = 4;

  /// İki semantik sürüm dizesini kıyaslar (Örn: '2.1.1' < '2.1.2' -> true)
  static bool isVersionOlder(String current, String target) {
    try {
      final currentClean = current.split('+').first.trim();
      final targetClean = target.split('+').first.trim();

      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = targetClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (targetParts.length < 3) {
        targetParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < targetParts[i]) return true;
        if (currentParts[i] > targetParts[i]) return false;
      }
      return false; // Eşit
    } catch (_) {
      return false;
    }
  }

  /// Sunucudan sürüm gereksinimlerini sorgular ve güncelleme gerekip gerekmediğini döner.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final client = Supabase.instance.client;

      // Platform tespiti: ios, android veya all
      String platformKey = 'all';
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          platformKey = 'ios';
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          platformKey = 'android';
        }
      }

      // 1. Önce platforma özel kaydı dene
      List<dynamic> rows = await client
          .from('mobile_app_versions')
          .select()
          .eq('platform', platformKey)
          .limit(1);

      // 2. Yoksa genel 'all' kaydını dene
      if (rows.isEmpty && platformKey != 'all') {
        rows = await client
            .from('mobile_app_versions')
            .select()
            .eq('platform', 'all')
            .limit(1);
      }

      if (rows.isEmpty) return null;

      final data = rows.first as Map<String, dynamic>;
      final minVersion = (data['min_version'] as String?)?.trim() ?? currentAppVersion;
      final latestVersion = (data['latest_version'] as String?)?.trim() ?? currentAppVersion;
      final storeUrl = (data['store_url'] as String?)?.trim() ?? '';
      final title = (data['title'] as String?)?.trim() ?? 'Zorunlu Güncelleme';
      final message = (data['message'] as String?)?.trim() ??
          'Sınıf360 uygulamasının yeni bir sürümü yayınlandı. Kesintisiz kullanım için lütfen güncelleyin.';
      final isForcedRule = data['is_forced'] as bool? ?? true;

      // Kıyaslama: Mevcut sürüm minimum zorunlu sürümden küçük mü?
      final bool isOlderThanMin = isVersionOlder(currentAppVersion, minVersion);

      if (isOlderThanMin && isForcedRule) {
        return AppUpdateInfo(
          currentVersion: currentAppVersion,
          minVersion: minVersion,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
          title: title,
          message: message,
          isForced: true,
        );
      }

      // İsteğe bağlı güncelleme (minimumun üstünde ama en sondan küçük)
      final bool isOlderThanLatest = isVersionOlder(currentAppVersion, latestVersion);
      if (isOlderThanLatest) {
        return AppUpdateInfo(
          currentVersion: currentAppVersion,
          minVersion: minVersion,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
          title: title,
          message: message,
          isForced: false,
        );
      }

      return null; // Sürüm güncel
    } catch (e) {
      debugPrint('[AppUpdateService] Güncelleme denetim hatası (atlanıyor): $e');
      return null;
    }
  }
}
