import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

class SupabaseDatasource {
  final _client = Supabase.instance.client;

  Future<void> updateLockStatus(bool isUnlocked) async {
    await _client
        .from('boards')
        .update({'is_unlocked': isUnlocked})
        .eq('id', AppConstants.boardId); // board_id yerine id yazdık
  }

  Stream<List<Map<String, dynamic>>> streamBoardStatus() {
    return _client
        .from('boards')
        .stream(primaryKey: ['id'])
        .eq('id', AppConstants.boardId); // board_id yerine id yazdık
  }
}