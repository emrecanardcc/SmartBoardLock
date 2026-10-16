// lib/data/models/broadcast_package_model.dart
import 'dart:convert';

class PackageItem {
  final String id;
  final String type; // 'poster' veya 'announcement'
  final String title;
  final String content;
  final String? imageUrl;
  final String? thumbnailBase64;
  final String? imageBase64; // Cihaz ekleme veya yeniden yayına alma için görsel verisi

  const PackageItem({
    required this.id,
    required this.type,
    required this.title,
    this.content = '',
    this.imageUrl,
    this.thumbnailBase64,
    this.imageBase64,
  });

  bool get isPoster => type == 'poster';
  bool get isAnnouncement => type == 'announcement';

  PackageItem copyWith({
    String? id,
    String? type,
    String? title,
    String? content,
    String? imageUrl,
    String? thumbnailBase64,
    String? imageBase64,
  }) {
    return PackageItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'image_url': imageUrl ?? '',
      'thumbnail_base64': thumbnailBase64 ?? '',
      'image_base64': imageBase64 ?? '',
    };
  }

  factory PackageItem.fromMap(Map<String, dynamic> map) {
    return PackageItem(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'poster',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      imageUrl: (map['image_url'] != null && map['image_url'].toString().isNotEmpty)
          ? map['image_url'].toString()
          : null,
      thumbnailBase64: (map['thumbnail_base64'] != null && map['thumbnail_base64'].toString().isNotEmpty)
          ? map['thumbnail_base64'].toString()
          : null,
      imageBase64: (map['image_base64'] != null && map['image_base64'].toString().isNotEmpty)
          ? map['image_base64'].toString()
          : null,
    );
  }
}

class BroadcastPackageModel {
  final String id;
  final String? schoolId;
  final String title;
  final String version;
  final DateTime validFrom;
  final DateTime validTo;
  final List<PackageItem> items;
  final bool isActive;
  final bool isTemplate;
  final String? templateName;
  final List<String> targetBoardIds;
  final DateTime createdAt;

  const BroadcastPackageModel({
    required this.id,
    this.schoolId,
    required this.title,
    this.version = 'v1.0',
    required this.validFrom,
    required this.validTo,
    this.items = const [],
    this.isActive = true,
    this.isTemplate = false,
    this.templateName,
    this.targetBoardIds = const [],
    required this.createdAt,
  });

  List<PackageItem> get posters => items.where((i) => i.isPoster).toList();
  List<PackageItem> get announcements => items.where((i) => i.isAnnouncement).toList();

  bool get isExpired => DateTime.now().isAfter(validTo);

  String get remainingTimeText {
    final now = DateTime.now();
    if (now.isAfter(validTo)) return 'Süresi Doldu';
    final diff = validTo.difference(now);
    if (diff.inDays > 0) {
      final hours = diff.inHours % 24;
      return '${diff.inDays} Gün ${hours > 0 ? '$hours Sa' : ''} Kaldı';
    } else if (diff.inHours > 0) {
      final mins = diff.inMinutes % 60;
      return '${diff.inHours} Saat ${mins > 0 ? '$mins Dk' : ''} Kaldı';
    } else {
      return '${diff.inMinutes} Dakika Kaldı';
    }
  }

  BroadcastPackageModel copyWith({
    String? id,
    String? schoolId,
    String? title,
    String? version,
    DateTime? validFrom,
    DateTime? validTo,
    List<PackageItem>? items,
    bool? isActive,
    bool? isTemplate,
    String? templateName,
    List<String>? targetBoardIds,
    DateTime? createdAt,
  }) {
    return BroadcastPackageModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      version: version ?? this.version,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      items: items ?? this.items,
      isActive: isActive ?? this.isActive,
      isTemplate: isTemplate ?? this.isTemplate,
      templateName: templateName ?? this.templateName,
      targetBoardIds: targetBoardIds ?? this.targetBoardIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'version': version,
      'valid_from': validFrom.toUtc().toIso8601String(),
      'valid_to': validTo.toUtc().toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
      'is_active': isActive,
      'is_template': isTemplate,
      'template_name': templateName,
      'target_board_ids': targetBoardIds,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory BroadcastPackageModel.fromMap(Map<String, dynamic> map) {
    var rawItems = map['items'];
    List<PackageItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((x) => PackageItem.fromMap(Map<String, dynamic>.from(x as Map)))
          .toList();
    } else if (rawItems is String) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          parsedItems = decoded
              .map((x) => PackageItem.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList();
        }
      } catch (_) {}
    }

    List<String> parsedBoardIds = [];
    final rawBoardIds = map['target_board_ids'];
    if (rawBoardIds is List) {
      parsedBoardIds = rawBoardIds.map((x) => x.toString()).toList();
    } else if (rawBoardIds is String) {
      try {
        final decoded = jsonDecode(rawBoardIds);
        if (decoded is List) {
          parsedBoardIds = decoded.map((x) => x.toString()).toList();
        }
      } catch (_) {}
    }

    return BroadcastPackageModel(
      id: map['id']?.toString() ?? '',
      schoolId: map['school_id']?.toString(),
      title: map['title']?.toString() ?? 'Yayın Paketi',
      version: map['version']?.toString() ?? 'v1.0',
      validFrom: map['valid_from'] != null
          ? DateTime.parse(map['valid_from'].toString()).toLocal()
          : DateTime.now(),
      validTo: map['valid_to'] != null
          ? DateTime.parse(map['valid_to'].toString()).toLocal()
          : DateTime.now().add(const Duration(days: 7)),
      items: parsedItems,
      isActive: map['is_active'] as bool? ?? true,
      isTemplate: map['is_template'] as bool? ?? false,
      templateName: map['template_name']?.toString(),
      targetBoardIds: parsedBoardIds,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString()).toLocal()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory BroadcastPackageModel.fromJson(String source) =>
      BroadcastPackageModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
