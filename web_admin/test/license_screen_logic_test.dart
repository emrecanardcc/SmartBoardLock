import 'package:flutter_test/flutter_test.dart';

class LicenseEvaluator {
  static (bool isActive, int remainingDays, String statusText) evaluate({
    required bool isLicensed,
    DateTime? licenseExpiresAt,
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();

    if (!isLicensed) {
      return (false, 0, 'Süresi Doldu / Pasif');
    }

    if (licenseExpiresAt == null) {
      return (true, 365, 'Aktif Lisans');
    }

    final expUtc = licenseExpiresAt.toUtc();
    if (now.isAfter(expUtc)) {
      return (false, 0, 'Süresi Doldu');
    }

    final remaining = expUtc.difference(now).inDays;
    if (remaining <= 15) {
      return (true, remaining, 'Son $remaining Gün Kaldı');
    }

    return (true, remaining, 'Aktif Lisans');
  }

  static DateTime addDuration(DateTime base, String chip) {
    switch (chip) {
      case '+1 Ay':
        return DateTime.utc(base.year, base.month + 1, base.day);
      case '+6 Ay':
        return DateTime.utc(base.year, base.month + 6, base.day);
      case '+1 Yıl':
        return DateTime.utc(base.year + 1, base.month, base.day);
      case '+3 Yıl':
        return DateTime.utc(base.year + 3, base.month, base.day);
      default:
        return base;
    }
  }
}

void main() {
  group('Web Admin License Evaluation Logic Tests', () {
    final baseNow = DateTime.utc(2026, 10, 17, 12, 0, 0);

    test('Expired license returns 0 remaining days and expired text', () {
      final pastDate = DateTime.utc(2026, 10, 15, 12, 0, 0);
      final result = LicenseEvaluator.evaluate(
        isLicensed: true,
        licenseExpiresAt: pastDate,
        nowUtc: baseNow,
      );

      expect(result.$1, isFalse);
      expect(result.$2, equals(0));
      expect(result.$3, equals('Süresi Doldu'));
    });

    test('isLicensed = false flag immediately disables license', () {
      final futureDate = DateTime.utc(2027, 10, 17, 12, 0, 0);
      final result = LicenseEvaluator.evaluate(
        isLicensed: false,
        licenseExpiresAt: futureDate,
        nowUtc: baseNow,
      );

      expect(result.$1, isFalse);
      expect(result.$2, equals(0));
      expect(result.$3, contains('Pasif'));
    });

    test('Warning state triggers when remaining days <= 15', () {
      final soonDate = baseNow.add(const Duration(days: 7));
      final result = LicenseEvaluator.evaluate(
        isLicensed: true,
        licenseExpiresAt: soonDate,
        nowUtc: baseNow,
      );

      expect(result.$1, isTrue);
      expect(result.$2, equals(7));
      expect(result.$3, equals('Son 7 Gün Kaldı'));
    });

    test('Active state with long remaining duration', () {
      final nextYear = baseNow.add(const Duration(days: 284));
      final result = LicenseEvaluator.evaluate(
        isLicensed: true,
        licenseExpiresAt: nextYear,
        nowUtc: baseNow,
      );

      expect(result.$1, isTrue);
      expect(result.$2, equals(284));
      expect(result.$3, equals('Aktif Lisans'));
    });

    test('Quick extension chips compute future dates correctly', () {
      final start = DateTime.utc(2026, 10, 17);

      final oneMonth = LicenseEvaluator.addDuration(start, '+1 Ay');
      expect(oneMonth.month, equals(11));
      expect(oneMonth.year, equals(2026));

      final oneYear = LicenseEvaluator.addDuration(start, '+1 Yıl');
      expect(oneYear.year, equals(2027));
      expect(oneYear.month, equals(10));

      final threeYears = LicenseEvaluator.addDuration(start, '+3 Yıl');
      expect(threeYears.year, equals(2029));
      expect(threeYears.month, equals(10));
    });
  });
}
