import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  Future<void> updateLockStatus({
    required String boardId,
    required bool isUnlocked,
  }) async {
    await _client
        .from('boards')
        .update({
          'is_unlocked': isUnlocked,
        })
        .eq('id', boardId);
  }

  Stream<List<Map<String, dynamic>>> streamBoardStatus(String boardId) {
    return _client
        .from('boards')
        .stream(primaryKey: ['id'])
        .eq('id', boardId);
  }
}