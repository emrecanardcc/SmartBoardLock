import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  // İkincil / Yedek sunucu bilgileri (Cloud Supabase)
  static const String fallbackUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  static const String fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8';

  // Birincil sunucu bilgileri (Oracle Cloud Self-Hosted Supabase)
  static const String primaryUrl = 'http://130.61.78.192:8000';
  static const String primaryKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkyMjI1OTQ5LCJleHAiOjE5NDk5MDU5NDl9.sk8yBULVd4I88d6zbbvYFBtLETiDhr0Ipq2gG6E4ih0';

  /// Hem aktif sunucuya hem de yedek/ikincil sunucuya aynı anda yazan çift-sunucu kalkanı
  static Future<void> syncBoardPatch({
    required String boardId,
    required Map<String, dynamic> patchData,
  }) async {
    // 1. Aktif istemci üzerinden güncelleme
    try {
      final client = Supabase.instance.client;
      await client.from('boards').update(patchData).eq('id', boardId);
    } catch (_) {}

    // 2. Birincil (Oracle VM) REST PATCH çağrısı
    try {
      final uri = Uri.parse('$primaryUrl/rest/v1/boards?id=eq.$boardId');
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 4);
      final request = await httpClient.patchUrl(uri);
      request.headers.set('apikey', primaryKey);
      request.headers.set('Authorization', 'Bearer $primaryKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Prefer', 'return=minimal');
      request.write(jsonEncode(patchData));
      await request.close();
      httpClient.close();
    } catch (_) {}

    // 3. İkincil / Yedek (Cloud Supabase) REST PATCH çağrısı
    try {
      final uri = Uri.parse('$fallbackUrl/rest/v1/boards?id=eq.$boardId');
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 4);
      final request = await httpClient.patchUrl(uri);
      request.headers.set('apikey', fallbackKey);
      request.headers.set('Authorization', 'Bearer $fallbackKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Prefer', 'return=minimal');
      request.write(jsonEncode(patchData));
      await request.close();
      httpClient.close();
    } catch (_) {}
  }

  Future<void> updateLockStatus({
    required String boardId,
    required bool isUnlocked,
    String? unlockedBy,
  }) async {
    final patch = <String, dynamic>{
      'is_unlocked': isUnlocked,
    };
    if (unlockedBy != null) {
      if (isUnlocked) {
        patch['last_unlocked_by'] = unlockedBy;
      } else {
        patch['last_locked_by'] = unlockedBy;
      }
    }
    await syncBoardPatch(boardId: boardId, patchData: patch);
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