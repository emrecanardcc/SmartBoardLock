// lib/data/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile_model.dart';
import '../repositories/admin_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AdminRepository _repository;

  UserProfileModel? _currentUser;
  bool _isLoading = true;
  String? _error;

  AuthProvider(this._repository) {
    _init();
  }

  UserProfileModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  bool get isSuperAdmin {
    if (_currentUser == null) return false;
    return _currentUser!.isSuperAdmin;
  }

  bool get isSchoolAdmin {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.admin && _currentUser!.schoolId != null;
  }

  void _init() {
    // Auth state değişikliklerini dinle
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        await _loadProfile();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      }
    });

    // Başlangıçta mevcut session varsa profili yükle
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _loadProfile();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _repository.getCurrentUserProfile();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> refresh() async {
    await _loadProfile();
  }
}
