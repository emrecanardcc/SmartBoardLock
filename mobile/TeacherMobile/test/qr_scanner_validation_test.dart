import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/data/services/qr_validator.dart';

void main() {
  group('QrValidator Hourly Boundary and Security Tests', () {
    const boardId = 'board-uuid-12345';
    const secret = 'OFFLINE_SECRET_KEY_ABC';

    test('Valid QR payload within normal time window passes', () {
      final now = DateTime.utc(2026, 10, 17, 10, 30, 0);
      const timeStr = '202610171030';
      final sig = QrValidator.calculateExpectedSignature(
        boardId: boardId,
        offlineSecret: secret,
        scannedTime: timeStr,
      );

      final payload = '$boardId|$timeStr|$sig';
      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: now,
      );

      expect(result.isValid, isTrue);
      expect(result.boardId, equals(boardId));
    });

    test('Critical Fix: Hour Boundary (10:59 to 11:00) passes seamlessly', () {
      // Eski hatalı kod 1100 - 1059 = 41 > 1 diyerek reddediyordu!
      // Şimdi DateTime farkı kullanıldığı için 60 saniyelik fark geçerlidir.
      const scannedTime = '202610171059'; // 10:59
      final nowAt1100 = DateTime.utc(2026, 10, 17, 11, 0, 15); // 11:00:15 (75 saniye fark)

      final sig = QrValidator.calculateExpectedSignature(
        boardId: boardId,
        offlineSecret: secret,
        scannedTime: scannedTime,
      );

      final payload = '$boardId|$scannedTime|$sig';
      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: nowAt1100,
        toleranceSeconds: 120,
      );

      expect(result.isValid, isTrue,
          reason: 'Saat geçişindeki QR kod reddedilmemelidir');
    });

    test('Critical Fix: Day Boundary (23:59 to 00:00) passes seamlessly', () {
      const scannedTime = '202610172359'; // 17 Ekim 23:59
      final nowNextDay = DateTime.utc(2026, 10, 18, 0, 0, 30); // 18 Ekim 00:00:30

      final sig = QrValidator.calculateExpectedSignature(
        boardId: boardId,
        offlineSecret: secret,
        scannedTime: scannedTime,
      );

      final payload = '$boardId|$scannedTime|$sig';
      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: nowNextDay,
        toleranceSeconds: 120,
      );

      expect(result.isValid, isTrue,
          reason: 'Gün geçişindeki QR kod reddedilmemelidir');
    });

    test('Expired QR code (> tolerance) is rejected', () {
      const scannedTime = '202610171000';
      final nowLater = DateTime.utc(2026, 10, 17, 10, 5, 0); // 5 dakika sonra

      final sig = QrValidator.calculateExpectedSignature(
        boardId: boardId,
        offlineSecret: secret,
        scannedTime: scannedTime,
      );

      final payload = '$boardId|$scannedTime|$sig';
      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: nowLater,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Süresi Dolmuş'));
    });

    test('Target Board ID mismatch is rejected', () {
      const timeStr = '202610171030';
      final sig = QrValidator.calculateExpectedSignature(
        boardId: 'other-board-id',
        offlineSecret: secret,
        scannedTime: timeStr,
      );

      final payload = 'other-board-id|$timeStr|$sig';
      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Kimlik Uyuşmazlığı'));
    });

    test('Forged or invalid signature is rejected', () {
      final now = DateTime.utc(2026, 10, 17, 10, 30, 0);
      const timeStr = '202610171030';
      final payload = '$boardId|$timeStr|INVALID_SIG_1234';

      final result = QrValidator.validatePayload(
        scannedData: payload,
        expectedBoardId: boardId,
        expectedOfflineSecret: secret,
        mockNowUtc: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Geçersiz İmza'));
    });
  });
}
