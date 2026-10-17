import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/core/config/supabase_config.dart';
import 'package:tahta_kumandasi/data/services/qr_validator.dart';

void main() {
  group('Sınıf360 Mobile Core Smoke Tests', () {
    test('SupabaseConfig returns valid non-empty URLs and Keys', () {
      expect(SupabaseConfig.primaryUrl, isNotEmpty);
      expect(SupabaseConfig.primaryKey, isNotEmpty);
      expect(SupabaseConfig.fallbackUrl, isNotEmpty);
      expect(SupabaseConfig.fallbackKey, isNotEmpty);

      expect(SupabaseConfig.primaryUrl, startsWith('http'));
      expect(SupabaseConfig.fallbackUrl, startsWith('https'));
    });

    test('QrValidator accurately computes and validates SHA-256 HMAC signature', () {
      const boardId = 'TEST_BOARD_123';
      const secret = 'TEST_OFFLINE_SECRET';
      final nowUtc = DateTime.utc(2026, 10, 17, 20, 30);
      const timeStr = '202610172030';

      final signature = QrValidator.calculateExpectedSignature(
        boardId: boardId,
        offlineSecret: secret,
        scannedTime: timeStr,
      );

      expect(signature, isNotEmpty);
      expect(signature.length, equals(16));

      // Valid payload check
      final validPayload = '$boardId|$timeStr|$signature';
      final result = QrValidator.validatePayload(
        scannedData: validPayload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: nowUtc,
      );
      expect(result.isValid, isTrue);

      // Wrong signature check
      final invalidPayload = '$boardId|$timeStr|INVALID_SIG_1234';
      final failResult = QrValidator.validatePayload(
        scannedData: invalidPayload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: nowUtc,
      );
      expect(failResult.isValid, isFalse);
    });
  });
}
