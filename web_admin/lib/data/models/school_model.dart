// lib/data/models/school_model.dart
class SchoolModel {
  final String id;
  final String name;
  final String city;
  final DateTime createdAt;
  final int boardCount;
  final int userCount;
  final int teacherCount;
  final int adminCount;
  final bool isLicensed;
  final DateTime? licenseExpiresAt;
  final String? licenseNotes;
  final String? boardAdminPassword;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.city,
    required this.createdAt,
    this.boardCount = 0,
    this.userCount = 0,
    this.teacherCount = 0,
    this.adminCount = 0,
    this.isLicensed = true,
    this.licenseExpiresAt,
    this.licenseNotes,
    this.boardAdminPassword,
  });

  /// Lisansın anlık olarak aktif olup olmadığını hesaplar
  bool get isLicenseActive {
    if (!isLicensed) return false;
    if (licenseExpiresAt == null) return true;
    return licenseExpiresAt!.isAfter(DateTime.now());
  }

  /// Kalan lisans günü sayısı
  int get remainingLicenseDays {
    if (licenseExpiresAt == null) return 9999;
    return licenseExpiresAt!.difference(DateTime.now()).inDays;
  }

  /// Lisansın bitmesine 15 gün veya daha az kalmış mı?
  bool get isExpiringSoon => isLicenseActive && remainingLicenseDays <= 15;

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    return SchoolModel(
      id: map['id'] as String,
      name: map['name'] as String,
      city: map['city'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      boardCount: map['board_count'] as int? ?? 0,
      userCount: map['user_count'] as int? ?? 0,
      teacherCount: map['teacher_count'] as int? ?? 0,
      adminCount: map['admin_count'] as int? ?? 0,
      isLicensed: map['is_licensed'] as bool? ?? true,
      licenseExpiresAt: map['license_expires_at'] != null
          ? DateTime.tryParse(map['license_expires_at'] as String)
          : null,
      licenseNotes: map['license_notes'] as String?,
      boardAdminPassword: map['board_admin_password'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'created_at': createdAt.toIso8601String(),
      'is_licensed': isLicensed,
      'license_expires_at': licenseExpiresAt?.toIso8601String(),
      'license_notes': licenseNotes,
      'board_admin_password': boardAdminPassword,
    };
  }

  SchoolModel copyWith({
    String? id,
    String? name,
    String? city,
    DateTime? createdAt,
    int? boardCount,
    int? userCount,
    int? teacherCount,
    int? adminCount,
    bool? isLicensed,
    DateTime? licenseExpiresAt,
    String? licenseNotes,
    String? boardAdminPassword,
  }) {
    return SchoolModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      boardCount: boardCount ?? this.boardCount,
      userCount: userCount ?? this.userCount,
      teacherCount: teacherCount ?? this.teacherCount,
      adminCount: adminCount ?? this.adminCount,
      isLicensed: isLicensed ?? this.isLicensed,
      licenseExpiresAt: licenseExpiresAt ?? this.licenseExpiresAt,
      licenseNotes: licenseNotes ?? this.licenseNotes,
      boardAdminPassword: boardAdminPassword ?? this.boardAdminPassword,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
