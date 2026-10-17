import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  // İkincil / Yedek sunucu bilgileri (Cloud Supabase)
  static const String fallbackUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  static const String fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8';

  // Birincil sunucu bilgileri (Oracle Cloud Self-Hosted Supabase)
  static const String primaryUrl = 'http://130.61.78.192:8000';
  static const String primaryKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkyMjI1OTQ5LCJleHAiOjE5NDk5MDU5NDl9.sk8yBULVd4I88d6zbbvYFBtLETiDhr0Ipq2gG6E4ih0';

  // Statik ve UTF-8 garantili Supabase istemcileri
  static final SupabaseClient primaryClient = SupabaseClient(primaryUrl, primaryKey);
  static final SupabaseClient fallbackClient = SupabaseClient(fallbackUrl, fallbackKey);

  /// Hem aktif sunucuya hem de yedek/ikincil sunucuya aynı anda yazan çift-sunucu kalkanı (Tam UTF-8 Uyumlu)
  static Future<bool> syncBoardPatch({
    required String boardId,
    required Map<String, dynamic> patchData,
  }) async {
    bool primarySuccess = false;
    bool fallbackSuccess = false;
    bool activeSuccess = false;

    // 1. Birincil Sunucu (Oracle Cloud VM)
    try {
      await primaryClient
          .from('boards')
          .update(patchData)
          .eq('id', boardId);
      primarySuccess = true;
    } catch (e) {
      // ignore: avoid_print
      print('[SupabaseDatasource] Primary update error: $e');
    }

    // 2. İkincil / Yedek Sunucu (Cloud Supabase)
    try {
      await fallbackClient
          .from('boards')
          .update(patchData)
          .eq('id', boardId);
      fallbackSuccess = true;
    } catch (e) {
      // ignore: avoid_print
      print('[SupabaseDatasource] Fallback update error: $e');
    }

    // 3. Aktif oturum istemcisi üzerinden güncelleme
    try {
      final activeClient = Supabase.instance.client;
      await activeClient
          .from('boards')
          .update(patchData)
          .eq('id', boardId);
      activeSuccess = true;
    } catch (e) {
      // ignore: avoid_print
      print('[SupabaseDatasource] Active client update error: $e');
    }

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