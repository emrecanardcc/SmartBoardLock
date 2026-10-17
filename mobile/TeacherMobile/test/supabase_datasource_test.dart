import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/data/datasources/supabase_datasource.dart';

void main() {
  test('syncBoardPatch updates boards across backends with Turkish characters seamlessly', () async {
    const testBoardId = '2684c356-d6a7-44fd-b68d-416b5a0df7c7';

    // 1. Türkçe karakterler içeren kilit verisi
    final patchData = {
      'is_unlocked': false,
      'last_locked_by': 'Öğretmen Yetkili (Test Çözüm - Emre Can Ardıç)',
    };

    final result = await SupabaseDatasource.syncBoardPatch(
      boardId: testBoardId,
      patchData: patchData,
    );

    expect(result, isTrue, reason: 'En az bir sunucuya başarılı yazılmış olmalıdır');

    // 2. Doğrulama: Oracle VM ve Cloud Supabase üzerinden SELECT yapıp teyit et
    final oracleRow = await SupabaseDatasource.primaryClient
        .from('boards')
        .select('id, is_unlocked, last_locked_by')
        .eq('id', testBoardId)
        .maybeSingle();

    expect(oracleRow, isNotNull);
    expect(oracleRow?['is_unlocked'], isFalse);
    expect(oracleRow?['last_locked_by'], contains('Öğretmen Yetkili'));

    final cloudRow = await SupabaseDatasource.fallbackClient
        .from('boards')
        .select('id, is_unlocked, last_locked_by')
        .eq('id', testBoardId)
        .maybeSingle();

    expect(cloudRow, isNotNull);
    expect(cloudRow?['is_unlocked'], isFalse);
    expect(cloudRow?['last_locked_by'], contains('Öğretmen Yetkili'));
  });
}
