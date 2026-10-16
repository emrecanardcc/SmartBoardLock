// lib/data/providers/school_selector_provider.dart
import 'package:flutter/foundation.dart';
import '../models/school_model.dart';
import '../repositories/admin_repository.dart';

/// Süper Admin'in seçtiği okulu global olarak tutar.
/// null = "Tüm Sistem" görünümü
class SchoolSelectorProvider extends ChangeNotifier {
  SchoolModel? _selectedSchool;
  List<SchoolModel> _allSchools = [];
  bool _isLoading = false;

  SchoolModel? get selectedSchool => _selectedSchool;
  List<SchoolModel> get allSchools => _allSchools;
  bool get isLoading => _isLoading;

  /// Aktif çalışma okul ID'si (süper admin seçtiyse o, müdür ise kendi okulu)
  String? get activeSchoolId => _selectedSchool?.id;

  void setSchools(List<SchoolModel> schools) {
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
    if (_selectedSchool?.id == school?.id) return;
    _selectedSchool = school;
    notifyListeners();
  }

  void selectSchoolById(String? schoolId) {
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
      _allSchools = list;
      if (_selectedSchool != null) {
        _selectedSchool = list.cast<SchoolModel?>().firstWhere(
          (s) => s?.id == _selectedSchool!.id,
          orElse: () => null,
        );
      }
    } catch (e) {
      debugPrint('SchoolSelectorProvider loadSchools error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
