// lib/presentation/screens/super_versions_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_version_model.dart';
import '../../data/models/board_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/app_dialog.dart';

class SuperVersionsScreen extends StatefulWidget {
  const SuperVersionsScreen({super.key});

  @override
  State<SuperVersionsScreen> createState() => _SuperVersionsScreenState();
}

class _SuperVersionsScreenState extends State<SuperVersionsScreen> {
  int _selectedTab = 0; // 0: Sürümler, 1: Uzaktan Onarım (TahtaRepair)
  late Future<List<AppVersionModel>> _versionsFuture;

  // Onarım (TahtaRepair) sekmesi durumu
  List<BoardModel> _boards = [];
  bool _isLoadingBoards = false;
  StreamSubscription<List<BoardModel>>? _boardsSub;
  Map<String, String> _schoolNames = {};
  String _boardSearchQuery = '';
  bool _onlyOnline = false;
  bool _isBulkRepairing = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
    _loadBoards();
  }

  @override
  void dispose() {
    _boardsSub?.cancel();
    super.dispose();
  }

  void _loadVersions() {
    final repo = context.read<AdminRepository>();
    _versionsFuture = repo.getAppVersions();
  }

  void _loadBoards() {
    final repo = context.read<AdminRepository>();
    setState(() => _isLoadingBoards = true);

    // Okul isimlerini al
    repo.getSchools().then((schools) {
      if (mounted) {
        setState(() {
          _schoolNames = {for (var s in schools) s.id: s.name};
        });
      }
    }).catchError((_) {});

    // İlk tahtaları getir
    repo.getBoards(null).then((boards) {
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoadingBoards = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoadingBoards = false);
    });

    // Canlı akışı dinle
    _boardsSub?.cancel();
    _boardsSub = repo.streamBoards(null).listen((boards) {
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoadingBoards = false;
        });
      }
    });
  }

  void _refresh() {
    setState(() {
      _loadVersions();
      _loadBoards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTab == 0
                          ? 'Sürüm & Güncelleme Merkezi'
                          : 'Uzaktan Bütünlük Onarımı (TahtaRepair)',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _selectedTab == 0
                          ? 'Sistem güncellemelerini yönetin ve yeni sürüm yayınlayın.'
                          : 'Sorunlu veya çöken tahtalara uzaktan sıfırdan temiz kurulum sinyali gönderin.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              if (_selectedTab == 0)
                ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Yeni Sürüm Yayınla'),
                  onPressed: () => _showAddEditVersionDialog(context, repo),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
                  tooltip: 'Yenile',
                  onPressed: _loadBoards,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.build_circle_rounded, size: 18),
                  label: Text(
                      'Tüm Çevrimiçi Tahtaları Onar (${_boards.where((b) => b.isOnline).length})'),
                  onPressed: _isBulkRepairing
                      ? null
                      : () => _confirmBulkRepair(context, repo),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Tab Bar (Segmented selector)
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton(0, Icons.folder_zip_rounded, 'Sürüm Paketleri'),
                const SizedBox(width: 6),
                _buildTabButton(1, Icons.build_circle_rounded,
                    'Uzaktan Bütünlük Onarımı (TahtaRepair)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Aktif Tab İçeriği
          if (_selectedTab == 0)
            Expanded(child: _buildVersionsTab(context, repo))
          else
            Expanded(child: _buildRepairTab(context, repo)),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textGrey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionsTab(BuildContext context, AdminRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Hata: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.danger)),
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
                                  color: AppColors.success
                                      .withValues(alpha: 0.1),
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
                                      decoration: TextDecoration.underline,
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
                              icon: const Icon(Icons.open_in_new_rounded,
                                  color: AppColors.info, size: 18),
                              tooltip: 'İndirme Linkini Aç',
                              onPressed: () async {
                                final uri =
                                    Uri.tryParse(version.downloadUrl);
                                if (uri != null &&
                                    await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode:
                                          LaunchMode.externalApplication);
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
                                    content:
                                        Text('İndirme linki kopyalandı.'),
                                    backgroundColor: AppColors.textDark,
                                  ),
                                );
                              },
                            ),
                            // Düzenle
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: AppColors.info, size: 18),
                              tooltip: 'Düzenle',
                              onPressed: () => _showAddEditVersionDialog(
                                  context, repo,
                                  version: version),
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
                                      version.id,
                                      downloadUrl: version.downloadUrl,
                                      versionNumber: version.versionNumber,
                                    );
                                    if (context.mounted) {
                                      _refresh();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('v${version.versionNumber} sürüm kaydı ve paketi silindi.'),
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
                                          backgroundColor: AppColors.danger,
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
    );
  }

  Widget _buildRepairTab(BuildContext context, AdminRepository repo) {
    final onlineCount = _boards.where((b) => b.isOnline).length;
    final totalCount = _boards.length;

    final filtered = _boards.where((b) {
      if (_onlyOnline && !b.isOnline) return false;
      if (_boardSearchQuery.isNotEmpty) {
        final q = _boardSearchQuery.toLowerCase();
        final nameMatch = b.name.toLowerCase().contains(q);
        final schoolMatch =
            (_schoolNames[b.schoolId] ?? '').toLowerCase().contains(q);
        final gradeMatch = b.gradeBranchLabel.toLowerCase().contains(q);
        if (!nameMatch && !schoolMatch && !gradeMatch) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bilgilendirme Kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.build_circle_outlined,
                  color: AppColors.warning, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistem Yöneticisi Uzaktan Onarım Motoru (TahtaRepair.exe)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bu işlem, seçilen akıllı tahtadaki tüm uygulama dosyalarını (KioskLockApp, WatchdogService, TahtaUpdater vb.) en son sürümle sıfırdan indirip temizler ve kurar. Tahtanın eşleştirme ve okul ayarları (Registry) 100% korunur.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Arama ve Filtre Çubuğu
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (v) => setState(() => _boardSearchQuery = v),
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Tahta adı, okul adı veya sınıf ile filtrele...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textGrey, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    filled: true,
                    fillColor: AppColors.bgCard,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Çevrimiçi Filtre Chip
            FilterChip(
              label: Text('Yalnızca Çevrimiçi ($onlineCount / $totalCount)'),
              selected: _onlyOnline,
              onSelected: (v) => setState(() => _onlyOnline = v),
              selectedColor: AppColors.success.withValues(alpha: 0.15),
              checkmarkColor: AppColors.success,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: _onlyOnline ? FontWeight.w700 : FontWeight.w500,
                color: _onlyOnline ? AppColors.success : AppColors.textGrey,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tahtalar Listesi
        Expanded(
          child: _isLoadingBoards && _boards.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Eşleşen tahta bulunamadı.',
                        style: GoogleFonts.inter(
                            color: AppColors.textGrey, fontSize: 14),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.border)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final board = filtered[index];
                            final schoolName =
                                _schoolNames[board.schoolId] ?? 'Bilinmeyen Okul';
                            final isOnline = board.isOnline;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.bgPage,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isOnline
                                        ? AppColors.success
                                            .withValues(alpha: 0.3)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.tv_rounded,
                                  color: isOnline
                                      ? AppColors.success
                                      : AppColors.textGrey,
                                  size: 22,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    board.name,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? AppColors.success
                                              .withValues(alpha: 0.1)
                                          : AppColors.offline
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isOnline
                                            ? AppColors.success
                                                .withValues(alpha: 0.3)
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      isOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDİŞİ',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isOnline
                                            ? AppColors.success
                                            : AppColors.offline,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    '$schoolName • ${board.gradeBranchLabel.isNotEmpty ? board.gradeBranchLabel : "Sınıf Belirtilmemiş"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kurulu Sürüm: ${board.appVersion != null && board.appVersion!.isNotEmpty ? board.appVersion : "Bilinmiyor"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOnline
                                      ? AppColors.warning
                                      : AppColors.bgPage,
                                  foregroundColor: isOnline
                                      ? Colors.white
                                      : AppColors.textGrey,
                                  elevation: isOnline ? 1 : 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.build_circle_rounded,
                                    size: 16),
                                label: const Text('Bütünlüğü Onar'),
                                onPressed: isOnline
                                    ? () => _confirmSingleRepair(
                                        context, repo, board)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _confirmSingleRepair(
      BuildContext context, AdminRepository repo, BoardModel board) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Uygulama Bütünlüğünü Onar (Sıfırdan Yükle)',
      content:
          '"${board.name}" akıllı tahtasındaki tüm sistem dosyaları (KioskLockApp, WatchdogService, TahtaUpdater vb.) en son sürümle sıfırdan indirilerek temizlenip kurulacaktır.\n\nEşleştirme ve okul ayarları (Registry) 100% korunacaktır.\n\nOnarım komutunu göndermek istiyor musunuz?',
      confirmLabel: 'Bütünlüğü Onar',
      icon: Icons.build_circle_rounded,
    );

    if (confirmed && context.mounted) {
      try {
        await repo.sendRepairIntegrityCommand(board.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '"${board.name}" için onarım komutu gönderildi. Tahta onarımı başlatıyor.'),
              backgroundColor: AppColors.textDark,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmBulkRepair(
      BuildContext context, AdminRepository repo) async {
    final onlineBoards = _boards.where((b) => b.isOnline).toList();
    if (onlineBoards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şu an çevrimiçi olan akıllı tahta bulunmuyor.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Toplu Bütünlük Onarımı (Sıfırdan Yükle)',
      content:
          'Şu an açık olan ${onlineBoards.length} adet akıllı tahtaya uzaktan sıfırdan onarım komutu gönderilecektir.\n\nHer tahta en güncel sürüm paketini indirip tüm uygulama dosyalarını temizleyerek sıfırdan kuracaktır. Eşleştirmeler korunacaktır.\n\nİşlemi onaylıyor musunuz?',
      confirmLabel: 'Tümünü Onar (${onlineBoards.length})',
      icon: Icons.build_circle_rounded,
    );

    if (confirmed && context.mounted) {
      setState(() => _isBulkRepairing = true);
      try {
        await repo.sendBulkRepairIntegrityCommand(
            onlineBoards.map((b) => b.id).toList());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${onlineBoards.length} adet açık tahtaya bütünlük onarım komutu başarıyla gönderildi.'),
              backgroundColor: AppColors.textDark,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Toplu onarım hatası: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isBulkRepairing = false);
      }
    }
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
