// lib/data/models/app_version_model.dart
class AppVersionModel {
  final String id;
  final String versionNumber;
  final String downloadUrl;
  final DateTime createdAt;

  const AppVersionModel({
    required this.id,
    required this.versionNumber,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory AppVersionModel.fromMap(Map<String, dynamic> map) {
    return AppVersionModel(
      id: map['id'] as String,
      versionNumber: map['version_number'] as String,
      downloadUrl: map['download_url'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
