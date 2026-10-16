// lib/data/models/board_model.dart

enum BoardStatus { unlocked, locked, inactive }

class BoardModel {
  final String id;
  final String? schoolId;
  final String name;
  final bool isUnlocked;
  final int autoLockMinutes;
  final DateTime? lastPingAt;
  final DateTime createdAt;
  final String? offlineSecret;
  final String? lastUnlockedBy;
  final String? lastLockedBy;
  final String? grade;
  final String? branch;
  final bool isActive;
  final String? appVersion;
  final String? remoteCommand;
  final String activeMediaId;

  const BoardModel({
    required this.id,
    this.schoolId,
    required this.name,
    required this.isUnlocked,
    required this.autoLockMinutes,
    this.lastPingAt,
    required this.createdAt,
    this.offlineSecret,
    this.lastUnlockedBy,
    this.lastLockedBy,
    this.grade,
    this.branch,
    required this.isActive,
    this.appVersion,
    this.remoteCommand,
    this.activeMediaId = 'DEFAULT',
  });

  factory BoardModel.fromMap(Map<String, dynamic> map) {
    return BoardModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String?,
      name: map['name'] as String,
      isUnlocked: map['is_unlocked'] as bool? ?? false,
      autoLockMinutes: map['auto_lock_minutes'] as int? ?? 15,
      lastPingAt: map['last_ping_at'] != null
          ? DateTime.parse(map['last_ping_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      offlineSecret: map['offline_secret'] as String?,
      lastUnlockedBy: map['last_unlocked_by'] as String?,
      lastLockedBy: map['last_locked_by'] as String?,
      grade: map['grade'] as String?,
      branch: map['branch'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      appVersion: map['app_version'] as String?,
      remoteCommand: map['remote_command'] as String?,
      activeMediaId: map['active_media_id']?.toString() ?? 'DEFAULT',
    );
  }

  /// Tahtanın kilit durumu (Açık mı, Kilitli mi, Pasif mi)
  BoardStatus get status {
    if (!isActive) return BoardStatus.inactive;
    if (isUnlocked) return BoardStatus.unlocked;
    return BoardStatus.locked;
  }

  /// Fiziksel bilgisayarın o an açık ve çalışır olup olmadığı (son 5 dk içinde ping)
  bool get isOnline {
    if (!isActive) return false;
    if (lastPingAt == null) return false;
    final diff = DateTime.now().toUtc().difference(lastPingAt!.toUtc());
    return diff.inMinutes < 5;
  }

  bool get isOffline => !isOnline;

  bool get isDefaultMedia => activeMediaId == 'DEFAULT';

  String get gradeLabel {
    if (grade != null && grade!.isNotEmpty) return grade!;
    return '';
  }

  String get branchLabel {
    if (branch != null && branch!.isNotEmpty) return branch!;
    return '';
  }

  String get gradeBranchLabel {
    final parts = <String>[];
    if (grade != null && grade!.isNotEmpty) parts.add('${grade!}. Sınıf');
    if (branch != null && branch!.isNotEmpty) parts.add(branch!);
    return parts.join(' ');
  }

  BoardModel copyWith({
    String? id,
    String? schoolId,
    String? name,
    bool? isUnlocked,
    int? autoLockMinutes,
    DateTime? lastPingAt,
    DateTime? createdAt,
    String? offlineSecret,
    String? lastUnlockedBy,
    String? lastLockedBy,
    String? grade,
    String? branch,
    bool? isActive,
    String? appVersion,
    String? remoteCommand,
    String? activeMediaId,
  }) {
    return BoardModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      createdAt: createdAt ?? this.createdAt,
      offlineSecret: offlineSecret ?? this.offlineSecret,
      lastUnlockedBy: lastUnlockedBy ?? this.lastUnlockedBy,
      lastLockedBy: lastLockedBy ?? this.lastLockedBy,
      grade: grade ?? this.grade,
      branch: branch ?? this.branch,
      isActive: isActive ?? this.isActive,
      appVersion: appVersion ?? this.appVersion,
      remoteCommand: remoteCommand ?? this.remoteCommand,
      activeMediaId: activeMediaId ?? this.activeMediaId,
    );
  }
}
