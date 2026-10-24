// lib/data/providers/school_selector_provider.dart
import 'package:flutter/foundation.dart';
import '../models/school_model.dart';
import '../repositories/admin_repository.dart';
import 'auth_provider.dart';

/// Süper Admin'in seçtiği okulu global olarak tutar.
/// null = "Tüm Sistem" görünümü
/// Okul Müdürü oturum açtığında yalnızca kendi okuluna kilitlenir.
class SchoolSelectorProvider extends ChangeNotifier {
  SchoolModel? _selectedSchool;
  List<SchoolModel> _allSchools = [];
  bool _isLoading = false;
  String? _restrictedSchoolId;

  SchoolModel? get selectedSchool => _selectedSchool;
  List<SchoolModel> get allSchools => _allSchools;
  bool get isLoading => _isLoading;

  /// Aktif çalışma okul ID'si (süper admin seçtiyse o, müdür ise kendi okulu)
  String? get activeSchoolId => _restrictedSchoolId ?? _selectedSchool?.id;

  /// Oturum ve kullanıcı yetkisine göre okul seçici durumunu senkronize eder
  void syncWithAuth(AuthProvider auth) {
    if (!auth.isLoggedIn || auth.currentUser == null) {
      if (_selectedSchool != null || _allSchools.isNotEmpty || _restrictedSchoolId != null) {
        reset();
      }
      return;
    }

    if (!auth.isSuperAdmin) {
      final userSchoolId = auth.currentUser?.schoolId;
      final schoolName = auth.currentUser?.schoolName ?? 'Okulunuz';
      final hasChanged = _restrictedSchoolId != userSchoolId;
      _restrictedSchoolId = userSchoolId;

      if (userSchoolId == null) {
        _selectedSchool = null;
        _allSchools = [];
        if (hasChanged) notifyListeners();
        return;
      }

      // Okul yöneticisinin okulu bellekte yoksa oluştur
      SchoolModel? matched = _allSchools.cast<SchoolModel?>().firstWhere(
        (s) => s?.id == userSchoolId,
        orElse: () => null,
      );

      matched ??= SchoolModel(
        id: userSchoolId,
        name: schoolName,
        city: '',
        createdAt: DateTime.now(),
      );

      _selectedSchool = matched;
      _allSchools = [matched];
      if (hasChanged) notifyListeners();
    } else {
      // Süper Admin
      if (_restrictedSchoolId != null) {
        _restrictedSchoolId = null;
        notifyListeners();
      }
    }
  }

  /// Tüm durumu tamamen sıfırlar (çıkış yapıldığında çağrılır)
  void reset() {
    _selectedSchool = null;
    _allSchools = [];
    _restrictedSchoolId = null;
    _isLoading = false;
    notifyListeners();
  }

  void setSchools(List<SchoolModel> schools) {
    if (_restrictedSchoolId != null) {
      // Müdür ise sadece kendi okulunu kabul et
      final onlyMySchool = schools.where((s) => s.id == _restrictedSchoolId).toList();
      _allSchools = onlyMySchool;
      if (onlyMySchool.isNotEmpty) {
        _selectedSchool = onlyMySchool.first;
      }
      notifyListeners();
      return;
    }

    if (listEquals(_allSchools, schools)) return;
    _allSchools = schools;
    // Eğer seçili okul listede varsa referansını güncelle
    if (_selectedSchool != null) {
      final match = schools.cast<SchoolModel?>().firstWhere(
        (s) => s?.id == _selectedSchool!.id,
        orElse: () => null,
      );
      _selectedSchool = match;
    }
    notifyListeners();
  }

  void selectSchool(SchoolModel? school) {
    if (_restrictedSchoolId != null && school?.id != _restrictedSchoolId) return;
    if (_selectedSchool?.id == school?.id) return;
    _selectedSchool = school;
    notifyListeners();
  }

  void selectSchoolById(String? schoolId) {
    if (_restrictedSchoolId != null && schoolId != _restrictedSchoolId) return;
    if (_selectedSchool?.id == schoolId) return;
    if (schoolId == null) {
      _selectedSchool = null;
    } else {
      _selectedSchool = _allSchools.cast<SchoolModel?>().firstWhere(
        (s) => s?.id == schoolId,
        orElse: () => null,
      );
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_restrictedSchoolId != null) return;
    if (_selectedSchool == null) return;
    _selectedSchool = null;
    notifyListeners();
  }

  Future<void> loadSchools(AdminRepository repo, {bool force = false}) async {
    if (_allSchools.isNotEmpty && !force) return;
    _isLoading = true;
    notifyListeners();
    try {
      final list = await repo.getSchools();
      if (_restrictedSchoolId != null) {
        final onlyMySchool = list.where((s) => s.id == _restrictedSchoolId).toList();
        _allSchools = onlyMySchool;
        if (onlyMySchool.isNotEmpty) {
          _selectedSchool = onlyMySchool.first;
        }
      } else {
        _allSchools = list;
        if (_selectedSchool != null) {
          _selectedSchool = list.cast<SchoolModel?>().firstWhere(
            (s) => s?.id == _selectedSchool!.id,
            orElse: () => null,
          );
        }
      }
    } catch (e) {
      debugPrint('SchoolSelectorProvider loadSchools error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
