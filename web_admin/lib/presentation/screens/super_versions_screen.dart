// lib/presentation/screens/super_versions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_version_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/app_dialog.dart';

class SuperVersionsScreen extends StatefulWidget {
  const SuperVersionsScreen({super.key});

  @override
  State<SuperVersionsScreen> createState() => _SuperVersionsScreenState();
}

class _SuperVersionsScreenState extends State<SuperVersionsScreen> {
  late Future<List<AppVersionModel>> _versionsFuture;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    final repo = context.read<AdminRepository>();
    _versionsFuture = repo.getAppVersions();
  }

  void _refresh() {
    setState(() => _loadVersions());
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Yeni Sürüm Butonu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sürüm & Güncelleme Merkezi',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Sistem güncellemelerini yönetin ve yeni sürüm yayınlayın.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Yeni Sürüm Yayınla'),
                onPressed: () =>
                    _showAddEditVersionDialog(context, repo),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bilgi Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En son kayıt aktif sürüm olarak esas alınır. Tahta uygulaması ve mobil uygulama bu listeyi okuyarak güncelleme yapar.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sürüm listesi
          Expanded(
            child: FutureBuilder<List<AppVersionModel>>(
              future: _versionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Hata: ${snapshot.error}',
                        style:
                            const TextStyle(color: AppColors.danger)),
                  );
                }

                final versions = snapshot.data ?? [];

                if (versions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.system_update_outlined,
                            size: 56, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz sürüm kaydı yok.',
                          style: GoogleFonts.inter(
                              color: AppColors.textGrey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.border)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      itemCount: versions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final version = versions[index];
                        final isLatest = index == 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isLatest
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.bgPage,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLatest
                                    ? AppColors.success.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              isLatest
                                  ? Icons.check_circle_rounded
                                  : Icons.history_rounded,
                              color: isLatest
                                  ? AppColors.success
                                  : AppColors.textGrey,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'v${version.versionNumber}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (isLatest) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.success
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'GÜNCEL',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.link_rounded,
                                      size: 12, color: AppColors.textLight),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      version.downloadUrl,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.info,
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Yayınlanma: ${DateFormat('dd.MM.yyyy HH:mm').format(version.createdAt.toLocal())}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // URL Aç
                              IconButton(
                                icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    color: AppColors.info,
                                    size: 18),
                                tooltip: 'İndirme Linkini Aç',
                                onPressed: () async {
                                  final uri = Uri.tryParse(
                                      version.downloadUrl);
                                  if (uri != null &&
                                      await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode
                                            .externalApplication);
                                  }
                                },
                              ),
                              // Kopyala
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    color: AppColors.textGrey, size: 18),
                                tooltip: 'Linki Kopyala',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: version.downloadUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'İndirme linki kopyalandı.'),
                                      backgroundColor:
                                          AppColors.textDark,
                                    ),
                                  );
                                },
                              ),
                              // Düzenle
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: AppColors.info, size: 18),
                                tooltip: 'Düzenle',
                                onPressed: () =>
                                    _showAddEditVersionDialog(context,
                                        repo, version: version),
                              ),
                              // Sil
                              IconButton(
                                icon: const Icon(Icons.delete_rounded,
                                    color: AppColors.danger, size: 18),
                                tooltip: 'Sil',
                                onPressed: () async {
                                  final confirmed = await showConfirmDialog(
                                    context,
                                    title: 'Sürümü Sil',
                                    content:
                                        'v${version.versionNumber} kaydını silmek istediğinize emin misiniz?',
                                    confirmLabel: 'Sil',
                                    icon: Icons.delete_rounded,
                                  );
                                  if (confirmed && context.mounted) {
                                    try {
                                      await repo.deleteAppVersion(
                                          version.id);
                                      if (context.mounted) {
                                        _refresh();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Sürüm kaydı silindi.'),
                                            backgroundColor:
                                                AppColors.textDark,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Hata: $e'),
                                            backgroundColor:
                                                AppColors.danger,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditVersionDialog(
    BuildContext context,
    AdminRepository repo, {
    AppVersionModel? version,
  }) async {
    final isEditing = version != null;
    final versionController =
        TextEditingController(text: version?.versionNumber ?? '');
    final urlController =
        TextEditingController(text: version?.downloadUrl ?? '');
    bool isSaving = false;
    bool isUploading = false;
    String? uploadedFileName;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing
                            ? 'Sürümü Düzenle'
                            : 'Yeni Sürüm Yayınla',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dosya Yükleme Alanı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUploading
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isUploading) ...[
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Dosya Supabase Storage\'a yükleniyor...',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_upload_rounded,
                                    color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uploadedFileName != null
                                          ? 'Yüklenen: $uploadedFileName'
                                          : 'Güncelleme Paketi Yükle (.zip, .exe)',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      uploadedFileName != null
                                          ? 'Buluta yüklendi ve link atandı ✓'
                                          : 'Dosyayı seçtiğinizde otomatik olarak buluta yüklenir.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: uploadedFileName != null
                                            ? AppColors.success
                                            : AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.folder_open_rounded, size: 16),
                                label: Text(uploadedFileName != null ? 'Değiştir' : 'Dosya Seç'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['zip', 'exe', 'msi', 'apk'],
                                      withData: true,
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final picked = result.files.first;
                                      final bytes = picked.bytes;
                                      if (bytes != null) {
                                        setDialogState(() => isUploading = true);
                                        final publicUrl = await repo.uploadUpdatePackage(
                                          fileName: picked.name,
                                          bytes: bytes,
                                        );
                                        setDialogState(() {
                                          isUploading = false;
                                          uploadedFileName = picked.name;
                                          urlController.text = publicUrl;
                                          if (versionController.text.trim().isEmpty) {
                                            final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(picked.name);
                                            if (match != null) {
                                              versionController.text = match.group(1)!;
                                            }
                                          }
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Yükleme hatası: $e'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: versionController,
                    decoration: const InputDecoration(
                      labelText: 'Sürüm Numarası',
                      hintText: 'Örn: 2.0.9',
                      prefixIcon: Icon(Icons.tag_rounded,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'İndirme URL\'si',
                      hintText: 'https://... (Yukarıdan dosya seçtiğinizde otomatik dolar)',
                      prefixIcon: Icon(Icons.link_rounded,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: (isSaving || isUploading)
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (isSaving || isUploading)
                            ? null
                            : () async {
                                if (versionController.text.trim().isEmpty ||
                                    urlController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Sürüm numarası ve URL zorunludur.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                try {
                                  if (isEditing) {
                                    await repo.updateAppVersion(
                                      id: version.id,
                                      versionNumber: versionController.text,
                                      downloadUrl: urlController.text,
                                    );
                                  } else {
                                    await repo.createAppVersion(
                                      versionNumber: versionController.text,
                                      downloadUrl: urlController.text,
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _refresh();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Sürüm güncellendi.'
                                            : 'v${versionController.text} yayınlandı! 🚀'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text('Hata: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'Güncelle' : 'Yayınla 🚀'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
