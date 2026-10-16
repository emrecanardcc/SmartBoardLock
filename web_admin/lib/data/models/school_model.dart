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

  const SchoolModel({
    required this.id,
    required this.name,
    required this.city,
    required this.createdAt,
    this.boardCount = 0,
    this.userCount = 0,
    this.teacherCount = 0,
    this.adminCount = 0,
  });

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
    );
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
