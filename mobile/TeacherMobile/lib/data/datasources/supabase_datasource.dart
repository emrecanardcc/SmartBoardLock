import '../../core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  // İkincil / Yedek sunucu bilgileri (Cloud Supabase)
  static String get fallbackUrl => SupabaseConfig.fallbackUrl;
  static String get fallbackKey => SupabaseConfig.fallbackKey;

  // Birincil sunucu bilgileri (Oracle Cloud Self-Hosted Supabase)
  static String get primaryUrl => SupabaseConfig.primaryUrl;
  static String get primaryKey => SupabaseConfig.primaryKey;

  // Statik ve UTF-8 garantili Supabase istemcileri (güvenli ortam değişkenleri)
  static SupabaseClient? _primaryClient;
  static SupabaseClient get primaryClient {
    return _primaryClient ??= SupabaseClient(primaryUrl, primaryKey);
  }

  static SupabaseClient? _fallbackClient;
  static SupabaseClient get fallbackClient {
    return _fallbackClient ??= SupabaseClient(fallbackUrl, fallbackKey);
  }

  /// Hem aktif sunucuya hem de yedek/ikincil sunucuya aynı anda yazan çift-sunucu kalkanı (Tam UTF-8 Uyumlu)
  static Future<bool> syncBoardPatch({
    required String boardId,
    required Map<String, dynamic> patchData,
  }) async {
    bool primarySuccess = false;
    bool fallbackSuccess = false;
    bool activeSuccess = false;

    // Eşzamanlı (Paralel) çoklu sunucu yazımı ile minimum gecikme
    await Future.wait([
      // 1. Birincil Sunucu (Oracle Cloud VM)
      if (primaryKey.isNotEmpty)
        () async {
          try {
            await primaryClient.from('boards').update(patchData).eq('id', boardId);
            primarySuccess = true;
          } catch (e) {
            // ignore: avoid_print
            print('[SupabaseDatasource] Primary update error: $e');
          }
        }(),

      // 2. İkincil / Yedek Sunucu (Cloud Supabase)
      if (fallbackKey.isNotEmpty)
        () async {
          try {
            await fallbackClient.from('boards').update(patchData).eq('id', boardId);
            fallbackSuccess = true;
          } catch (e) {
            // ignore: avoid_print
            print('[SupabaseDatasource] Fallback update error: $e');
          }
        }(),

      // 3. Aktif oturum istemcisi üzerinden güncelleme
      () async {
        try {
          await Supabase.instance.client.from('boards').update(patchData).eq('id', boardId);
          activeSuccess = true;
        } catch (e) {
          // ignore: avoid_print
          print('[SupabaseDatasource] Active client update error: $e');
        }
      }(),
    ]);

    return primarySuccess || fallbackSuccess || activeSuccess;
  }

  Future<bool> updateLockStatus({
    required String boardId,
    required bool isUnlocked,
    String? unlockedBy,
  }) async {
    final patch = <String, dynamic>{
      'is_unlocked': isUnlocked,
    };
    if (unlockedBy != null && unlockedBy.trim().isNotEmpty) {
      if (isUnlocked) {
        patch['last_unlocked_by'] = unlockedBy.trim();
      } else {
        patch['last_locked_by'] = unlockedBy.trim();
      }
    }
    return await syncBoardPatch(boardId: boardId, patchData: patch);
  }

  Stream<List<Map<String, dynamic>>> streamBoardStatus(String boardId) {
    return _client
        .from('boards')
        .stream(primaryKey: ['id'])
        .eq('id', boardId);
  }

  Stream<Map<String, dynamic>?> streamSchoolLicense(String schoolId) {
    return _client
        .from('schools')
        .stream(primaryKey: ['id'])
        .eq('id', schoolId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }
}