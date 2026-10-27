import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/data/services/app_update_service.dart';

void main() {
  group('AppUpdateService Version Comparison Tests', () {
    test('isVersionOlder accurately identifies older versions', () {
      expect(AppUpdateService.isVersionOlder('2.1.1', '2.1.2'), isTrue);
      expect(AppUpdateService.isVersionOlder('2.1.2', '2.1.3'), isTrue);
      expect(AppUpdateService.isVersionOlder('2.0.9', '2.1.0'), isTrue);
      expect(AppUpdateService.isVersionOlder('1.9.9', '2.0.0'), isTrue);
      expect(AppUpdateService.isVersionOlder('2.1.0', '2.1.1'), isTrue);
    });

    test('isVersionOlder returns false for equal or newer versions', () {
      expect(AppUpdateService.isVersionOlder('2.1.2', '2.1.2'), isFalse);
      expect(AppUpdateService.isVersionOlder('2.1.3', '2.1.3'), isFalse);
      expect(AppUpdateService.isVersionOlder('2.1.3', '2.1.2'), isFalse);
      expect(AppUpdateService.isVersionOlder('3.0.0', '2.1.2'), isFalse);
      expect(AppUpdateService.isVersionOlder('2.2.0', '2.1.9'), isFalse);
    });

    test('isVersionOlder handles build numbers with plus sign', () {
      expect(AppUpdateService.isVersionOlder('2.1.1+2', '2.1.2'), isTrue);
      expect(AppUpdateService.isVersionOlder('2.1.2+3', '2.1.2'), isFalse);
      expect(AppUpdateService.isVersionOlder('2.1.2+3', '2.1.2+5'), isFalse); // Semver base is equal
      expect(AppUpdateService.isVersionOlder('2.1.2+3', '2.1.3+1'), isTrue);
    });

    test('isVersionOlder gracefully handles two-digit or short versions', () {
      expect(AppUpdateService.isVersionOlder('2.1', '2.1.2'), isTrue); // 2.1.0 < 2.1.2
      expect(AppUpdateService.isVersionOlder('2.2', '2.1.2'), isFalse); // 2.2.0 > 2.1.2
    });
  });
}
