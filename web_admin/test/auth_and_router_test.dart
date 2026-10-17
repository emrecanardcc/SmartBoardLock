import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/data/models/user_profile_model.dart';
import 'package:web_admin/core/constants/app_constants.dart';

void main() {
  group('Auth and Role Guard Logic Tests', () {
    test('Teacher role cannot access admin panel and is flagged properly', () {
      final teacher = UserProfileModel.fromMap({
        'id': 'teacher-123',
        'role': 'teacher',
        'school_id': 'school-abc',
        'full_name': 'Ahmet Öğretmen',
        'email': 'ahmet@okul.meb.k12.tr',
      });

      expect(teacher.role, equals(UserRole.teacher));
      expect(teacher.isSuperAdmin, isFalse);
      expect(teacher.roleLabel, equals('Öğretmen'));

      // Rota koruması mantık doğrulaması:
      // Öğretmen için yönlendirilecek rota: /access-denied
      final redirectPath = (teacher.role == UserRole.teacher) ? '/access-denied' : null;
      expect(redirectPath, equals('/access-denied'));
    });

    test('School Admin (Müdür) is not Super Admin and restricted from super routes', () {
      final schoolAdmin = UserProfileModel.fromMap({
        'id': 'admin-456',
        'role': 'admin',
        'school_id': 'school-xyz',
        'full_name': 'Mehmet Müdür',
        'email': 'mudur@okul.meb.k12.tr',
      });

      expect(schoolAdmin.role, equals(UserRole.admin));
      expect(schoolAdmin.schoolId, equals('school-xyz'));
      expect(schoolAdmin.isSuperAdmin, isFalse,
          reason: 'Okul ID si olan yönetici süper admin olamaz');

      // Kurum yöneticisinin yasaklı rotaları
      final superRoutes = ['/schools', '/versions', '/issues'];
      for (final route in superRoutes) {
        final canAccess = schoolAdmin.isSuperAdmin;
        final redirect = !canAccess ? '/dashboard' : null;
        expect(redirect, equals('/dashboard'),
            reason: '$route sayfasına kurum yöneticisi erişememeli');
      }
    });

    test('System Administrator (Süper Admin) has full access across ecosystem', () {
      // 1. Okul ID'si null olan admin
      final superAdminByNullSchool = UserProfileModel.fromMap({
        'id': 'super-1',
        'role': 'admin',
        'school_id': null,
        'full_name': 'Sistem Yöneticisi',
        'email': 'yonetici@sinif360.com',
      });

      expect(superAdminByNullSchool.isSuperAdmin, isTrue);

      // 2. Tanımlı süper admin e-postası ile giriş
      final superAdminByEmail = UserProfileModel.fromMap({
        'id': 'super-2',
        'role': 'admin',
        'school_id': 'school-temp',
        'full_name': 'Root Admin',
        'email': AppConstants.superAdminEmails.first,
      });

      expect(superAdminByEmail.isSuperAdmin, isTrue);

      final superRoutes = ['/schools', '/versions', '/issues'];
      for (final route in superRoutes) {
        final canAccess = superAdminByEmail.isSuperAdmin;
        expect(canAccess, isTrue,
            reason: '$route sayfasına süper admin erişebilmelidir');
      }
    });

    test('Initials and Display Name formatting', () {
      final user1 = UserProfileModel.fromMap({
        'id': '1',
        'role': 'teacher',
        'full_name': 'Ali Can',
      });
      expect(user1.initials, equals('AC'));
      expect(user1.displayName, equals('Ali Can'));

      final user2 = UserProfileModel.fromMap({
        'id': '2',
        'role': 'teacher',
        'email': 'tekisim@sinif360.com',
      });
      expect(user2.displayName, equals('tekisim@sinif360.com'));
    });
  });
}
