// test/school_selector_and_downloads_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/data/models/school_model.dart';
import 'package:web_admin/data/models/user_profile_model.dart';
import 'package:web_admin/data/providers/auth_provider.dart';
import 'package:web_admin/data/providers/school_selector_provider.dart';
import 'package:web_admin/presentation/screens/downloads_screen.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserProfileModel? _mockUser;

  void setMockUser(UserProfileModel? user) {
    _mockUser = user;
    notifyListeners();
  }

  @override
  UserProfileModel? get currentUser => _mockUser;

  @override
  bool get isLoggedIn => _mockUser != null;

  @override
  bool get isSuperAdmin => _mockUser?.isSuperAdmin ?? false;

  @override
  bool get isSchoolAdmin =>
      _mockUser != null && _mockUser!.role == UserRole.admin && _mockUser!.schoolId != null;

  @override
  String? get error => null;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> signOut() async {
    _mockUser = null;
    notifyListeners();
  }
}

void main() {
  group('SchoolSelectorProvider Security & Reset Tests', () {
    late SchoolSelectorProvider selector;
    late FakeAuthProvider auth;

    final superAdminUser = UserProfileModel(
      id: 'super-admin-1',
      fullName: 'Sistem Yöneticisi',
      role: UserRole.admin,
      schoolId: null, // super admin
    );

    final schoolAdminUser = UserProfileModel(
      id: 'manager-1',
      fullName: 'Okul Müdürü',
      role: UserRole.admin,
      schoolId: 'school-abc',
      schoolName: 'Atatürk Anadolu Lisesi',
    );

    final schoolA = SchoolModel(
      id: 'school-abc',
      name: 'Atatürk Anadolu Lisesi',
      city: 'İstanbul',
      createdAt: DateTime.now(),
    );

    final schoolB = SchoolModel(
      id: 'school-xyz',
      name: 'Cumhuriyet Fen Lisesi',
      city: 'Ankara',
      createdAt: DateTime.now(),
    );

    setUp(() {
      selector = SchoolSelectorProvider();
      auth = FakeAuthProvider();
    });

    test('Super Admin can switch schools freely', () {
      auth.setMockUser(superAdminUser);
      selector.syncWithAuth(auth);
      selector.setSchools([schoolA, schoolB]);

      selector.selectSchool(schoolA);
      expect(selector.activeSchoolId, 'school-abc');

      selector.selectSchool(schoolB);
      expect(selector.activeSchoolId, 'school-xyz');

      selector.clearSelection();
      expect(selector.activeSchoolId, isNull);
    });

    test('Logging out resets all selector state completely', () {
      auth.setMockUser(superAdminUser);
      selector.syncWithAuth(auth);
      selector.setSchools([schoolA, schoolB]);
      selector.selectSchool(schoolB);

      expect(selector.activeSchoolId, 'school-xyz');

      // Logout
      auth.setMockUser(null);
      selector.syncWithAuth(auth);

      expect(selector.activeSchoolId, isNull);
      expect(selector.selectedSchool, isNull);
      expect(selector.allSchools, isEmpty);
    });

    test('School Admin is strictly locked to their own school and cannot select others', () {
      // First Super Admin was logged in
      auth.setMockUser(superAdminUser);
      selector.syncWithAuth(auth);
      selector.setSchools([schoolA, schoolB]);
      selector.selectSchool(schoolB);

      // Now switch to School Admin without page reload
      auth.setMockUser(schoolAdminUser);
      selector.syncWithAuth(auth);

      // Must be locked to Atatürk Anadolu Lisesi (school-abc)
      expect(selector.activeSchoolId, 'school-abc');
      expect(selector.selectedSchool?.name, 'Atatürk Anadolu Lisesi');

      // Attempt to select schoolB (Cumhuriyet Fen Lisesi) must be blocked
      selector.selectSchool(schoolB);
      expect(selector.activeSchoolId, 'school-abc');

      // Attempt to selectById with unauthorized school must be blocked
      selector.selectSchoolById('school-xyz');
      expect(selector.activeSchoolId, 'school-abc');

      // Attempt to clearSelection must be blocked
      selector.clearSelection();
      expect(selector.activeSchoolId, 'school-abc');
    });
  });

  group('DownloadsScreen URLs and Constants Verification', () {
    test('Official download endpoints point to valid setup and apk links', () {
      expect(DownloadsScreen.windowsSetupUrl, contains('Sinif360_Setup.exe'));
      expect(DownloadsScreen.androidApkUrl, contains('Sinif360_TeacherMobile.apk'));
      expect(DownloadsScreen.currentVersion, 'v2.1.3');
    });
  });
}
