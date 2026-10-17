import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/data/services/totp_service.dart';

void main() {
  group('TotpService Cross-Platform RFC 4226 Tests', () {
    test('Vector 1 matches C# OfflineTotpEngine output exactly', () {
      const secret = 'TEST_SECRET_SINIF360_SECURITY_KEY';
      const challenge = '4829';

      final pin = TotpService.generateResponse(
        offlineSecret: secret,
        challengeCode: challenge,
      );

      // C# OfflineTotpEngineTests ile birebir aynı değer
      expect(pin, equals('396995'));
      expect(pin.length, equals(6));
    });

    test('Vector 2 matches C# OfflineTotpEngine output exactly', () {
      const secret = 'OKUL_123_SECRET';
      const challenge = '9182';

      final pin = TotpService.generateResponse(
        offlineSecret: secret,
        challengeCode: challenge,
      );

      expect(pin, equals('961147'));
      expect(pin.length, equals(6));
    });

    test('Empty secret or challenge returns empty string', () {
      expect(
        TotpService.generateResponse(offlineSecret: '', challengeCode: '1234'),
        equals(''),
      );
      expect(
        TotpService.generateResponse(offlineSecret: 'SECRET', challengeCode: ''),
        equals(''),
      );
      expect(
        TotpService.generateResponse(offlineSecret: '   ', challengeCode: '1234'),
        equals(''),
      );
    });

    test('PIN is deterministic and always 6 digits', () {
      const secret = 'RANDOM_BOARD_SECRET_XYZ_987';
      const challenge = '7412';

      final pin1 = TotpService.generateResponse(
        offlineSecret: secret,
        challengeCode: challenge,
      );
      final pin2 = TotpService.generateResponse(
        offlineSecret: secret,
        challengeCode: challenge,
      );

      expect(pin1, equals(pin2));
      expect(pin1.length, equals(6));
      expect(int.tryParse(pin1), isNotNull);
    });
  });
}
