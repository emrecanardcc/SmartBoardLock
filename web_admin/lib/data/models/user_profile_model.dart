// lib/data/models/user_profile_model.dart
import '../../core/constants/app_constants.dart';

enum UserRole { admin, teacher, unknown }

class UserProfileModel {
  final String id;
  final String? schoolId;
  final String? schoolName;
  final String? fullName;
  final UserRole role;
  final String? email;

  const UserProfileModel({
    required this.id,
    this.schoolId,
    this.schoolName,
    this.fullName,
    required this.role,
    this.email,
  });

  factory UserProfileModel.fromMap(
    Map<String, dynamic> map, {
    String? schoolName,
  }) {
    UserRole role;
    final roleStr = map['role']?.toString();
    switch (roleStr) {
      case 'admin':
        role = UserRole.admin;
        break;
      case 'teacher':
        role = UserRole.teacher;
        break;
      default:
        role = UserRole.unknown;
    }

    return UserProfileModel(
      id: map['id']?.toString() ?? '',
      schoolId: map['school_id']?.toString(),
      schoolName: schoolName ?? map['school_name']?.toString(),
      fullName: map['full_name']?.toString(),
      role: role,
      email: map['email']?.toString(),
    );
  }

  String get displayName => fullName ?? email ?? 'İsimsiz';

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'U';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'Yönetici';
      case UserRole.teacher:
        return 'Öğretmen';
      case UserRole.unknown:
        return 'Bilinmiyor';
    }
  }

  String get roleKey {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.unknown:
        return 'teacher';
    }
  }

  /// Süper Admin mi? (admin rolü + school_id null VEYA superAdminEmails listesinde tanımlı)
  bool get isSuperAdmin =>
      (role == UserRole.admin && schoolId == null) ||
      (email != null && AppConstants.superAdminEmails.contains(email));

  UserProfileModel copyWith({
    String? id,
    String? schoolId,
    String? schoolName,
    String? fullName,
    UserRole? role,
    String? email,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
