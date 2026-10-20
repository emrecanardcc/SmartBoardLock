import '../../core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  // Birincil sunucu bilgileri (Oracle Cloud Self-Hosted Supabase)
  static String get primaryUrl => SupabaseConfig.primaryUrl;
  static String get primaryKey => SupabaseConfig.primaryKey;

  // Statik ve UTF-8 garantili Supabase istemcisi
  static SupabaseClient? _primaryClient;
  static SupabaseClient get primaryClient {
    return _primaryClient ??= SupabaseClient(primaryUrl, primaryKey);
  }

  /// Doğrudan Oracle Cloud VM Supabase sunucusuna yazan tekil ve güvenli veri metodu
  static Future<bool> syncBoardPatch({
    required String boardId,
    required Map<String, dynamic> patchData,
  }) async {
    try {
      await Supabase.instance.client.from('boards').update(patchData).eq('id', boardId);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[SupabaseDatasource] Active client update error: $e');
      try {
        await primaryClient.from('boards').update(patchData).eq('id', boardId);
        return true;
      } catch (e2) {
        // ignore: avoid_print
        print('[SupabaseDatasource] Primary client update error: $e2');
        return false;
      }
    }
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
