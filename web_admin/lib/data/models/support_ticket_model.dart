// lib/data/models/support_ticket_model.dart

class SupportTicketModel {
  final String id;
  final String? schoolId;
  final String? schoolName;
  final String? boardId;
  final String? boardName;
  final String reporterId;
  final String reporterName;
  final String reporterRole;
  final String category;
  final String description;
  final String status; // 'pending', 'in_progress', 'resolved', 'rejected'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SupportTicketModel({
    required this.id,
    this.schoolId,
    this.schoolName,
    this.boardId,
    this.boardName,
    required this.reporterId,
    required this.reporterName,
    required this.reporterRole,
    required this.category,
    required this.description,
    this.status = 'pending',
    this.adminNotes,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicketModel.fromMap(Map<String, dynamic> map, {String? schoolName}) {
    return SupportTicketModel(
      id: map['id']?.toString() ?? '',
      schoolId: map['school_id']?.toString(),
      schoolName: schoolName ?? map['school_name']?.toString(),
      boardId: map['board_id']?.toString(),
      boardName: map['board_name']?.toString(),
      reporterId: map['reporter_id']?.toString() ?? '',
      reporterName: map['reporter_name']?.toString() ?? 'Kullanıcı',
      reporterRole: map['reporter_role']?.toString() ?? 'teacher',
      category: map['category']?.toString() ?? 'Diğer',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      adminNotes: map['admin_notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'board_id': boardId,
      'board_name': boardName,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'reporter_role': reporterRole,
      'category': category,
      'description': description,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  SupportTicketModel copyWith({
    String? id,
    String? schoolId,
    String? schoolName,
    String? boardId,
    String? boardName,
    String? reporterId,
    String? reporterName,
    String? reporterRole,
    String? category,
    String? description,
    String? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupportTicketModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      boardId: boardId ?? this.boardId,
      boardName: boardName ?? this.boardName,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterRole: reporterRole ?? this.reporterRole,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'İnceleniyor';
      case 'resolved':
        return 'Çözüldü';
      case 'rejected':
        return 'Reddedildi';
      case 'pending':
      default:
        return 'Yeni / Beklemede';
    }
  }

  String get roleLabel {
    switch (reporterRole) {
      case 'school_admin':
        return 'Kurum Yöneticisi';
      case 'super_admin':
        return 'Sistem Yöneticisi';
      case 'teacher':
      default:
        return 'Öğretmen';
    }
  }
}
