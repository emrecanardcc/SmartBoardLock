// test/board_security_and_wallpaper_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/data/models/school_model.dart';

void main() {
  group('SchoolModel Board Admin Password Tests', () {
    test('SchoolModel parses board_admin_password from map correctly', () {
      final map = {
        'id': 'school-101',
        'name': 'Gölbaşı Test Okulu',
        'city': 'Ankara',
        'created_at': DateTime.now().toIso8601String(),
        'is_licensed': true,
        'board_admin_password': 'MudurPassword123!',
      };

      final school = SchoolModel.fromMap(map);
      expect(school.id, equals('school-101'));
      expect(school.name, equals('Gölbaşı Test Okulu'));
      expect(school.boardAdminPassword, equals('MudurPassword123!'));
    });

    test('SchoolModel handles null board_admin_password gracefully', () {
      final map = {
        'id': 'school-102',
        'name': 'Safa Okulları',
        'city': 'İstanbul',
        'created_at': DateTime.now().toIso8601String(),
        'is_licensed': true,
      };

      final school = SchoolModel.fromMap(map);
      expect(school.boardAdminPassword, isNull);
    });

    test('SchoolModel toMap includes board_admin_password', () {
      final school = SchoolModel(
        id: 'school-103',
        name: 'Deneme Lisesi',
        city: 'İzmir',
        createdAt: DateTime(2026, 1, 1),
        boardAdminPassword: 'SecretPin99',
      );

      final map = school.toMap();
      expect(map['board_admin_password'], equals('SecretPin99'));
    });

    test('SchoolModel copyWith updates boardAdminPassword', () {
      final school = SchoolModel(
        id: 'school-104',
        name: 'Cumhuriyet İlkokulu',
        city: 'Bursa',
        createdAt: DateTime(2026, 1, 1),
        boardAdminPassword: 'OldPassword',
      );

      final updated = school.copyWith(boardAdminPassword: 'NewPassword2026');
      expect(updated.boardAdminPassword, equals('NewPassword2026'));
      expect(updated.name, equals('Cumhuriyet İlkokulu'));
    });
  });

  group('Wallpaper and Security PIN Command Payload Format Tests', () {
    test('SET_WALLPAPER payload format matches Windows Kiosk expectations', () {
      const url = 'https://example.com/storage/wallpaper.jpg';
      const style = 'fill';

      final payloadMap = {
        'url': url,
        'style': style,
      };
      final commandString = 'SET_WALLPAPER:${jsonEncode(payloadMap)}';

      expect(commandString, startsWith('SET_WALLPAPER:'));
      final decodedJson = jsonDecode(commandString.substring('SET_WALLPAPER:'.length));
      expect(decodedJson['url'], equals(url));
      expect(decodedJson['style'], equals(style));
    });

    test('SET_SECURITY_PIN command string format matches Windows Kiosk expectations', () {
      const pin = 'SecretAdminPIN2026!';
      const commandString = 'SET_SECURITY_PIN:$pin';

      expect(commandString, startsWith('SET_SECURITY_PIN:'));
      final extractedPin = commandString.substring('SET_SECURITY_PIN:'.length).trim();
      expect(extractedPin, equals(pin));
    });
  });
}
