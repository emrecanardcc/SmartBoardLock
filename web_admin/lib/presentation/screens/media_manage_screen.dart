// lib/presentation/screens/media_manage_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/board_model.dart';
import '../../data/models/broadcast_package_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/school_selector_provider.dart';
import '../../data/repositories/admin_repository.dart';

class MediaManageScreen extends StatefulWidget {
  const MediaManageScreen({super.key});

  @override
  State<MediaManageScreen> createState() => _MediaManageScreenState();
}

class _MediaManageScreenState extends State<MediaManageScreen> {
  String _searchQuery = '';
  String _selectedTab = 'online'; // 'online', 'offline', 'all'
  bool _isLoading = true;
  String? _errorMessage;
  List<BoardModel> _allBoards = [];
  final Set<String> _selectedBoardIds = {};
  BroadcastPackageModel? _activePackage;
  List<BroadcastPackageModel> _allPackages = [];
  List<BroadcastPackageModel> _templates = [];
  String? _lastLoadedSchoolId;
  bool _hasInitialLoaded = false;
  int _loadVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();

    final currentSchoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    if (!_hasInitialLoaded) {
      _hasInitialLoaded = true;
      _lastLoadedSchoolId = currentSchoolId;
      _loadData(currentSchoolId);
    } else if (_lastLoadedSchoolId != currentSchoolId) {
      _lastLoadedSchoolId = currentSchoolId;
      _loadData(currentSchoolId);
    }
  }

  Future<void> _loadData([String? explicitSchoolId]) async {
    final currentVersion = ++_loadVersion;
    final authProvider = context.read<AuthProvider>();
    final selectorProvider = context.read<SchoolSelectorProvider>();
    final repo = context.read<AdminRepository>();

    final schoolId = explicitSchoolId ??
        (authProvider.isSuperAdmin
            ? selectorProvider.activeSchoolId
            : authProvider.currentUser?.schoolId);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final boards = await repo.getBoards(schoolId);
      final activePkg = await repo.getActivePackage(schoolId);
      final allPkgs = await repo.getAllPackages(schoolId);
      final templates = await repo.getTemplates(schoolId);
      repo.cleanupTemporaryMediaFiles();

      if (!mounted || currentVersion != _loadVersion) return;
      setState(() {
        _allBoards = boards;
        _activePackage = activePkg;
        _allPackages = allPkgs;
        _templates = templates;
        _isLoading = false;
        final onlineIds = boards.where((b) => b.isOnline).map((b) => b.id).toSet();
        _selectedBoardIds.removeWhere((id) => !onlineIds.contains(id));
      });
    } catch (e) {
      if (!mounted || currentVersion != _loadVersion) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAllOnlineBoards() {
    setState(() {
      final onlineBoards = _allBoards.where((b) => b.isOnline).map((b) => b.id);
      _selectedBoardIds.addAll(onlineBoards);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBoardIds.clear();
    });
  }

  List<BoardModel> _getFilteredBoards() {
    return _allBoards.where((board) {
      // Tab filtrelemesi
      if (_selectedTab == 'online' && !board.isOnline) return false;
      if (_selectedTab == 'offline' && board.isOnline) return false;

      // Arama filtresi
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = board.name.toLowerCase().contains(query);
        final classMatch = board.gradeBranchLabel.toLowerCase().contains(query);
        final mediaMatch = board.activeMediaId.toLowerCase().contains(query);
        if (!nameMatch && !classMatch && !mediaMatch) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _cleanStorageNow() async {
    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await repo.cleanupTemporaryMediaFiles();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count adet geçici afiş dosyası depolamadan temizlendi!'
                : 'Depolama zaten tertemiz (0 bayt gereksiz dosya).',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Temizlik hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _openPackageDialog({BroadcastPackageModel? editPackage}) {
    final onlineBoards = _allBoards.where((b) => b.isOnline).toList();
    if (onlineBoards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şu an açık tahta bulunmuyor. Yayın paketi açık tahtalara gönderilir.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final targetBoards = _selectedBoardIds.isNotEmpty
        ? _allBoards.where((b) => _selectedBoardIds.contains(b.id)).toList()
        : onlineBoards;

    final authProvider = context.read<AuthProvider>();
    final selectorProvider = context.read<SchoolSelectorProvider>();
    final schoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PackageContainerDialog(
        targetBoards: targetBoards,
        schoolId: schoolId,
        editPackage: editPackage,
        onSuccess: () => _loadData(),
      ),
    );
  }

  void _openAdjustDurationDialog() {
    if (_activePackage == null) return;
    final onlineBoards = _allBoards.where((b) => b.isOnline).toList();
    final targetBoards = _selectedBoardIds.isNotEmpty
        ? _allBoards.where((b) => _selectedBoardIds.contains(b.id)).toList()
        : onlineBoards;

    showDialog(
      context: context,
      builder: (ctx) => _AdjustDurationDialog(
        package: _activePackage!,
        targetBoards: targetBoards,
        onSuccess: () => _loadData(),
      ),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Varsayılana Sıfırla'),
          ],
        ),
        content: const Text(
          'Tüm tahtalardaki özel yayın paketi sonlandırılacak ve tahtalar '
          'varsayılan Türk Bayrağı, Atatürk Portresi ve MEB Kuralları afişlerine dönecektir.\n\n'
          'Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sıfırla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final targetIds = _selectedBoardIds.isNotEmpty
        ? _selectedBoardIds.toList()
        : _allBoards.where((b) => b.isOnline).map((b) => b.id).toList();

    try {
      await repo.resetBoardsMedia(targetIds);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tahtalar varsayılan eğitim afişlerine döndürüldü.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _openAddBoardsDialog(BroadcastPackageModel package) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddBoardsDialog(
        package: package,
        allBoards: _allBoards,
        onSuccess: () => _loadData(),
      ),
    );
  }

  Future<void> _savePackageAsTemplate(BroadcastPackageModel package) async {
    final controller = TextEditingController(text: package.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Hazır Şablon Olarak Kaydet'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu paketi hazır şablon olarak kaydedebilir, daha sonra tek tıkla tahtalara yayınlayabilirsiniz.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Şablon Adı',
                  hintText: 'Örn: Veli Toplantısı Duyurusu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.saveAsTemplate(packageId: package.id, templateName: name);
      messenger.showSnackBar(
        SnackBar(
          content: Text('"$name" hazır şablonlara kaydedildi!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Şablon kaydetme hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _openTemplatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _TemplatesDialog(
        templates: _templates,
        onUseTemplate: (template) {
          Navigator.pop(ctx);
          _openPackageDialog(editPackage: template);
        },
        onRefresh: () => _loadData(),
      ),
    );
  }

  Future<void> _republishPackage(BroadcastPackageModel package) async {
    final onlineBoards = _allBoards.where((b) => b.isOnline).toList();
    if (onlineBoards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şu an açık tahta bulunmuyor. Yayın paketi yalnızca açık tahtalara iletilebilir.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Paketi Yeniden Yayına Al'),
          ],
        ),
        content: Text(
          '"${package.title}" paketi şu an açık olan ${onlineBoards.length} akıllı tahtaya gönderilecek.\n\nOnaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Yayına Al'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final posterInputs = <Map<String, dynamic>>[];
      for (final p in package.posters) {
        Uint8List? rawBytes;
        final b64 = p.imageBase64 ?? p.thumbnailBase64;
        if (b64 != null && b64.isNotEmpty) {
          try {
            rawBytes = base64Decode(b64);
          } catch (_) {}
        }
        posterInputs.add({
          'id': p.id,
          'title': p.title,
          'content': p.content,
          'imageUrl': p.imageUrl,
          'thumbnailBase64': p.thumbnailBase64,
          'imageBase64': p.imageBase64,
          'bytes': rawBytes,
          'fileName': 'poster_${p.id}.jpg',
        });
      }

      final announcementInputs = package.announcements.map((a) => {
        'id': a.id,
        'title': a.title,
        'content': a.content,
      }).toList();

      final authProvider = context.read<AuthProvider>();
      final selectorProvider = context.read<SchoolSelectorProvider>();
      final schoolId = authProvider.isSuperAdmin
          ? selectorProvider.activeSchoolId
          : authProvider.currentUser?.schoolId;

      await repo.dispatchPackageToBoards(
        boardIds: onlineBoards.map((b) => b.id).toList(),
        title: package.title,
        version: package.version,
        validFrom: DateTime.now().subtract(const Duration(minutes: 5)),
        validTo: DateTime.now().add(const Duration(days: 7)),
        posterInputs: posterInputs,
        announcementInputs: announcementInputs,
        schoolId: schoolId,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('"${package.title}" paketi başarıyla yeniden yayına alındı!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Yeniden yayına alma hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _deletePackageFromHistory(BroadcastPackageModel package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Paketi Sil'),
          ],
        ),
        content: Text(
          '"${package.title}" yayını geçmişten ve arşivden silinecektir.\n\nOnaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.deletePackage(package.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Paket arşivden silindi.'), backgroundColor: AppColors.success),
      );
      _loadData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Silme hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _allBoards.where((b) => b.isOnline).length;
    final offlineCount = _allBoards.length - onlineCount;
    final filteredBoards = _getFilteredBoards();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Üst Başlık ve Ana Butonlar
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // 2. Canlı Aktif Yayın Önizlemesi Kartı
                      _buildActiveBroadcastPreviewCard(onlineCount),
                      const SizedBox(height: 28),

                      // 3. Akıllı Tahtalar - Soft & Düzenli Takip Bölümü
                      _buildBoardsSection(onlineCount, offlineCount, filteredBoards),
                      const SizedBox(height: 28),

                      // 4. Yayın Paketleri Geçmişi & Arşiv Bölümü
                      _buildPackageHistorySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: GoogleFonts.inter(color: AppColors.danger)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
            onPressed: () => _loadData(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Afiş & Duyuru Yönetimi',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Akıllı tahtalara anlık versiyonlu yayın paketleri gönderin, süresini yönetin ve canlı takip edin.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Hazır Şablonlar Butonu
            OutlinedButton.icon(
              icon: const Icon(Icons.bookmark_border_rounded, size: 16, color: AppColors.primary),
              label: const Text('📑 Hazır Şablonlar'),
              onPressed: _openTemplatesDialog,
            ),

            // Depo Temizle Butonu
            Tooltip(
              message: 'Supabase depolama alanında birikmiş olabilecek geçici afiş kalıntılarını süpürür.',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: AppColors.textDark),
                label: const Text('Depoyu Temizle'),
                onPressed: _cleanStorageNow,
              ),
            ),

            // Varsayılana Sıfırla
            OutlinedButton.icon(
              icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.warning),
              label: const Text('Varsayılana Sıfırla'),
              onPressed: _resetToDefault,
            ),

            // Yeni Paket Oluştur Butonu
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Yeni Yayın Paketi', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _openPackageDialog(),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 14),
              actionButtons,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 16),
            actionButtons,
          ],
        );
      },
    );
  }

  // ──────────────────────────── AKTİF YAYIN ÖNİZLEMESİ ───────────────────────

  Widget _buildActiveBroadcastPreviewCard(int onlineCount) {
    final pkg = _activePackage;
    final isCustomActive = pkg != null && pkg.isActive && !pkg.isExpired;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCustomActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kart Üst Başlık Şeridi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isCustomActive
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.bgPage,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 960;

                final titleAndBadges = Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCustomActive ? Icons.campaign_rounded : Icons.flag_rounded,
                          color: isCustomActive ? AppColors.primary : AppColors.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCustomActive ? 'Şu An Tahtalarda Yayında Olan Paket' : 'Varsayılan Ekran Yayında',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (isCustomActive) ...[
                      // Versiyon Rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pkg.version,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),

                      // Kalan Süre Rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 13, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              pkg.remainingTimeText,
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Varsayılan Mod (MEB / Atatürk / Bayrak)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ],
                );

                // Kart Aksiyon Butonları
                final actionButtons = isCustomActive
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Tahta Ekle
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            icon: const Icon(Icons.add_to_queue_rounded, size: 16),
                            label: const Text('Tahta Ekle'),
                            onPressed: () => _openAddBoardsDialog(pkg),
                          ),

                          // Şablon Olarak Kaydet
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textDark,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                            label: const Text('Şablon Yap'),
                            onPressed: () => _savePackageAsTemplate(pkg),
                          ),

                          // Süreyi Uzat / Kısalt
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            icon: const Icon(Icons.more_time_rounded, size: 16),
                            label: const Text('Süreyi Değiştir'),
                            onPressed: _openAdjustDurationDialog,
                          ),

                          // Paketi Düzenle
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textDark,
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Paketi Düzenle'),
                            onPressed: () => _openPackageDialog(editPackage: pkg),
                          ),

                          // Yayını Durdur
                          IconButton(
                            tooltip: 'Yayını Durdur ve Varsayılana Dön',
                            icon: const Icon(Icons.stop_circle_outlined, color: AppColors.danger, size: 20),
                            onPressed: _resetToDefault,
                          ),
                        ],
                      )
                    : const SizedBox.shrink();

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleAndBadges,
                      if (isCustomActive) ...[
                        const SizedBox(height: 10),
                        actionButtons,
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Flexible(child: titleAndBadges),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          // Kart İçeriği
          Padding(
            padding: const EdgeInsets.all(20),
            child: isCustomActive
                ? _buildActivePackageDetails(pkg)
                : _buildDefaultModeBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultModeBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final infoWidget = Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🇹🇷', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Şu an akıllı tahtalarda varsayılan eğitim ve milli afişler görüntülenmektedir.',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Şanlı Türk Bayrağı, Gazi Mustafa Kemal Atatürk portresi ve MEB Sınıf & Tahta Kullanım Kuralları kilit ekranında slayt olarak döner.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButton = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          icon: const Icon(Icons.campaign_rounded, size: 18),
          label: const Text('Yeni Paket Yayınla'),
          onPressed: () => _openPackageDialog(),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              infoWidget,
              const SizedBox(height: 14),
              actionButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: infoWidget),
            const SizedBox(width: 16),
            actionButton,
          ],
        );
      },
    );
  }

  Widget _buildActivePackageDetails(BroadcastPackageModel pkg) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final posters = pkg.posters;
    final announcements = pkg.announcements;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        // Sol: Afişler Bölümü
        final postersSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Afişler (${posters.length})',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (posters.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Bu pakette görsel afiş yok (Sadece metin duyurusu içeriyor).',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: posters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, idx) {
                    final item = posters[idx];
                    return _buildPosterPreviewCard(item, idx + 1, posters.length);
                  },
                ),
              ),
          ],
        );

        // Sağ: Duyurular Bölümü
        final announcementsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Duyuru Metinleri (${announcements.length})',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (announcements.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Bu pakette metin duyurusu bulunmuyor.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final ann = announcements[idx];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📢', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ann.title,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                            ),
                          ],
                        ),
                        if (ann.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ann.content,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );

        final titleAndDateWidget = isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.title,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(
                        '${dateFormat.format(pkg.validFrom)} — ${dateFormat.format(pkg.validTo)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pkg.title,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Text(
                        '${dateFormat.format(pkg.validFrom)} — ${dateFormat.format(pkg.validTo)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Paket Başlığı ve Tarih Bilgisi
            titleAndDateWidget,
            const SizedBox(height: 16),

            // Görseller Galerisi ve Duyurular
            if (isNarrow) ...[
              postersSection,
              const SizedBox(height: 20),
              announcementsSection,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol: Afişler Bölümü
                  Expanded(
                    flex: 5,
                    child: postersSection,
                  ),
                  const SizedBox(width: 24),

                  // Sağ: Duyurular Bölümü
                  Expanded(
                    flex: 4,
                    child: announcementsSection,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildPosterPreviewCard(PackageItem item, int index, int total) {
    Widget imageWidget;
    if (item.thumbnailBase64 != null && item.thumbnailBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(item.thumbnailBase64!);
        imageWidget = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        imageWidget = const Center(child: Icon(Icons.broken_image_rounded));
      }
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        item.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_rounded)),
      );
    } else {
      imageWidget = const Center(child: Icon(Icons.image_rounded, size: 36, color: AppColors.textGrey));
    }

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: imageWidget),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$index/$total', style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      const Icon(Icons.visibility_rounded, size: 12, color: AppColors.textGrey),
                    ],
                  ),
                  Text(
                    item.title.isNotEmpty ? item.title : 'Afiş $index',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── AKILLI TAHTALAR BÖLÜMÜ ─────────────────────

  Widget _buildBoardsSection(int onlineCount, int offlineCount, List<BoardModel> filteredBoards) {
    final totalCount = _allBoards.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Sekmeler
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akıllı Tahta Yayın Durumu',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text('Yalnızca açık tahtalara anlık paket iletilebilir.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                  ],
                );

                // Soft Sekmeler: Açık, Kapalı, Tümü
                final tabButtons = Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildTabButton('online', '🟢 Açık ($onlineCount)'),
                      _buildTabButton('offline', '⚪ Kapalı ($offlineCount)'),
                      _buildTabButton('all', '📋 Tümü ($totalCount)'),
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleColumn,
                      const SizedBox(height: 12),
                      tabButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleColumn),
                    const SizedBox(width: 12),
                    tabButtons,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Arama ve Seçim Çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                final searchField = SizedBox(
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Tahta adı veya sınıf ara...',
                      hintStyle: GoogleFonts.inter(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: AppColors.bgPage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Tüm Açıkları Seç
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: Text('Tüm Açıkları Seç ($onlineCount)'),
                      onPressed: onlineCount > 0 ? _selectAllOnlineBoards : null,
                    ),

                    if (_selectedBoardIds.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: Text('Seçimi Temizle (${_selectedBoardIds.length})'),
                        onPressed: _clearSelection,
                      ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              },
            ),
          ),

          // Tahtalar Tablosu
          if (filteredBoards.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  _selectedTab == 'online'
                      ? 'Şu anda açık/çevrimiçi akıllı tahta bulunmuyor.'
                      : 'Kriterlere uygun akıllı tahta bulunamadı.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBoards.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, idx) {
                final board = filteredBoards[idx];
                return _buildBoardRow(board);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label) {
    final isSelected = _selectedTab == tabId;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildBoardRow(BoardModel board) {
    final isOnline = board.isOnline;
    final isSelected = _selectedBoardIds.contains(board.id);
    final isCustomMedia = !board.isDefaultMedia;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // Seçim Checkbox
              Checkbox(
                value: isSelected,
                onChanged: isOnline
                    ? (val) {
                        setState(() {
                          if (val == true) {
                            _selectedBoardIds.add(board.id);
                          } else {
                            _selectedBoardIds.remove(board.id);
                          }
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 8),

              // Tahta İkonu ve Adı
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.success.withValues(alpha: 0.1) : AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tv_rounded,
                  size: 20,
                  color: isOnline ? AppColors.success : AppColors.textGrey,
                ),
              ),
              const SizedBox(width: 12),

              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            board.name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                        ),
                        if (board.gradeBranchLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              board.gradeBranchLabel,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? (board.lastPingAt != null
                              ? 'Çevrimiçi (Sinyal: ${DateTime.now().difference(board.lastPingAt!).inMinutes} dk önce)'
                              : 'Çevrimiçi')
                          : 'Kapalı (Afiş alabilmek için tahtanın açık olması gerekir)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isOnline ? AppColors.success : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Yayın Durumu Rozeti
              Container(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10, vertical: isNarrow ? 3 : 5),
                decoration: BoxDecoration(
                  color: isCustomMedia
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.bgPage,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCustomMedia ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCustomMedia ? Icons.campaign_rounded : Icons.image_rounded,
                      size: isNarrow ? 12 : 14,
                      color: isCustomMedia ? AppColors.primary : AppColors.textGrey,
                    ),
                    if (!isNarrow || constraints.maxWidth > 420) ...[
                      const SizedBox(width: 4),
                      Text(
                        isCustomMedia ? (isNarrow ? 'Özel' : 'Özel Paket Aktif') : (isNarrow ? 'Varsayılan' : 'Varsayılan Mod'),
                        style: GoogleFonts.inter(
                          fontSize: isNarrow ? 10 : 11,
                          fontWeight: FontWeight.w700,
                          color: isCustomMedia ? AppColors.primary : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Hızlı Aksiyon (Sadece bu tahtaya gönder)
              IconButton(
                tooltip: isOnline ? 'Sadece bu tahtaya yayın gönder' : 'Kapalı tahta yayın alamaz',
                icon: Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: isOnline ? AppColors.primary : AppColors.border,
                ),
                onPressed: isOnline
                    ? () {
                        setState(() {
                          _selectedBoardIds.clear();
                          _selectedBoardIds.add(board.id);
                        });
                        _openPackageDialog();
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────── YAYIN PAKETLERİ GEÇMİŞİ & ARŞİV ─────────────

  Widget _buildPackageHistorySection() {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Şeridi
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Yayın Paketleri Geçmişi & Arşiv',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_allPackages.length} Paket',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Yayınlanan paketler kaybolmaz; sonradan açılan cihazları ekleyebilir veya tek tıkla yeniden yayına alabilirsiniz.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Paketler Listesi
          if (_allPackages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.textGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      'Henüz arşivlenmiş yayın paketi bulunmuyor.',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yayınladığınız her paket burada saklanır ve dilediğiniz zaman tekrar kullanılabilir.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allPackages.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final pkg = _allPackages[index];
                final isLive = pkg.isActive && !pkg.isExpired;
                final posters = pkg.posters;
                final announcements = pkg.announcements;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;

                    final titleAndInfo = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Versiyon Rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLive ? AppColors.primary : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isLive ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            pkg.version,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isLive ? Colors.white : AppColors.textGrey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Paket Başlığı
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    pkg.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  // Durum Rozeti
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLive
                                          ? AppColors.success.withValues(alpha: 0.1)
                                          : AppColors.bgPage,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isLive ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isLive ? Icons.check_circle_rounded : Icons.history_rounded,
                                          size: 11,
                                          color: isLive ? AppColors.success : AppColors.textGrey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isLive ? 'Şu An Yayında' : (pkg.isExpired ? 'Süresi Doldu' : 'Pasif'),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isLive ? AppColors.success : AppColors.textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.date_range_rounded, size: 12, color: AppColors.textGrey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${dateFormat.format(pkg.validFrom)} — ${dateFormat.format(pkg.validTo)}',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.tv_rounded, size: 12, color: AppColors.textGrey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${pkg.targetBoardIds.length} Cihaza Gönderildi',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    // Aksiyon Butonları
                    final actionButtons = Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 1. Tahta Ekle
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.add_to_queue_rounded, size: 14),
                          label: const Text('Tahta Ekle'),
                          onPressed: () => _openAddBoardsDialog(pkg),
                        ),

                        // 2. Yeniden Yayına Al
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                          label: const Text('Yeniden Yayına Al'),
                          onPressed: () => _republishPackage(pkg),
                        ),

                        // 3. Düzenle / Klonla
                        IconButton(
                          tooltip: 'Düzenle ve Yeni Versiyon Olarak Yayınla',
                          icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.textDark),
                          onPressed: () => _openPackageDialog(editPackage: pkg),
                        ),

                        // 4. Şablon Yap
                        IconButton(
                          tooltip: 'Hazır Şablon Olarak Kaydet',
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: AppColors.primary),
                          onPressed: () => _savePackageAsTemplate(pkg),
                        ),

                        // 5. Sil
                        IconButton(
                          tooltip: 'Arşivden Sil',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          onPressed: () => _deletePackageFromHistory(pkg),
                        ),
                      ],
                    );

                    final postersWidget = posters.isNotEmpty
                        ? SizedBox(
                            height: 60,
                            child: ListView.separated(
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              itemCount: posters.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, pIdx) {
                                final p = posters[pIdx];
                                Widget imgWidget;
                                if (p.thumbnailBase64 != null && p.thumbnailBase64!.isNotEmpty) {
                                  try {
                                    imgWidget = Image.memory(base64Decode(p.thumbnailBase64!), fit: BoxFit.cover);
                                  } catch (_) {
                                    imgWidget = const Icon(Icons.image_not_supported_rounded, size: 16);
                                  }
                                } else if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
                                  imgWidget = Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 16));
                                } else {
                                  imgWidget = const Icon(Icons.image_rounded, size: 16);
                                }
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgPage,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: imgWidget,
                                  ),
                                );
                              },
                            ),
                          )
                        : null;

                    final announcementsWidget = announcements.isNotEmpty
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: announcements.map((a) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.bgPage,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('📢', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 4),
                                    Text(
                                      a.title,
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        : null;

                    return Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow) ...[
                            titleAndInfo,
                            const SizedBox(height: 10),
                            actionButtons,
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: titleAndInfo),
                                const SizedBox(width: 12),
                                actionButtons,
                              ],
                            ),
                          if (postersWidget != null || announcementsWidget != null) ...[
                            const SizedBox(height: 12),
                            if (isNarrow) ...[
                              if (postersWidget != null) postersWidget,
                              if (postersWidget != null && announcementsWidget != null) const SizedBox(height: 8),
                              if (announcementsWidget != null) announcementsWidget,
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (postersWidget != null) ...[
                                    postersWidget,
                                    const SizedBox(width: 14),
                                  ],
                                  if (announcementsWidget != null)
                                    Expanded(child: announcementsWidget),
                                ],
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAKET KONTEYNERİ DİALOGU (ÇOKLU AFİŞ VE ÇOKLU DUYURU YÖNETİMİ)
// ─────────────────────────────────────────────────────────────────────────────

class _PackageContainerDialog extends StatefulWidget {
  final List<BoardModel> targetBoards;
  final String? schoolId;
  final BroadcastPackageModel? editPackage;
  final VoidCallback onSuccess;

  const _PackageContainerDialog({
    required this.targetBoards,
    this.schoolId,
    this.editPackage,
    required this.onSuccess,
  });

  @override
  State<_PackageContainerDialog> createState() => _PackageContainerDialogState();
}

class _PackageContainerDialogState extends State<_PackageContainerDialog> {
  final _titleController = TextEditingController();
  final _versionController = TextEditingController();
  late DateTime _validFrom;
  late DateTime _validTo;

  // Konteyner Liste Verileri
  final List<Map<String, dynamic>> _posters = [];
  final List<Map<String, dynamic>> _announcements = [];

  bool _isSending = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    final edit = widget.editPackage;
    if (edit != null) {
      _titleController.text = edit.title;
      // Otomatik sonraki versiyon önerisi
      _versionController.text = _getNextVersion(edit.version);
      _validFrom = DateTime.now().subtract(const Duration(minutes: 5));
      _validTo = (edit.validTo.isAfter(DateTime.now()))
          ? edit.validTo
          : DateTime.now().add(const Duration(days: 7));

      // Mevcut afişleri yükle
      for (final p in edit.posters) {
        Uint8List? rawBytes;
        final b64 = p.imageBase64 ?? p.thumbnailBase64;
        if (b64 != null && b64.isNotEmpty) {
          try {
            rawBytes = base64Decode(b64);
          } catch (_) {}
        }
        _posters.add({
          'id': p.id,
          'title': p.title,
          'content': p.content,
          'imageUrl': p.imageUrl,
          'thumbnailBase64': p.thumbnailBase64,
          'imageBase64': p.imageBase64,
          'bytes': rawBytes,
          'fileName': 'poster_${p.id}.jpg',
        });
      }

      // Mevcut duyuruları yükle
      for (final a in edit.announcements) {
        _announcements.add({
          'id': a.id,
          'title': a.title,
          'content': a.content,
        });
      }
    } else {
      _titleController.text = 'Okul Duyuru ve Etkinlik Paketi';
      _versionController.text = 'v1.0';
      _validFrom = DateTime.now().subtract(const Duration(minutes: 5));
      _validTo = DateTime.now().add(const Duration(days: 7));
    }
  }

  String _getNextVersion(String currentVer) {
    if (currentVer.startsWith('v')) {
      final numPart = currentVer.substring(1);
      final parts = numPart.split('.');
      if (parts.length >= 2) {
        final minor = int.tryParse(parts[1]) ?? 0;
        return 'v${parts[0]}.${minor + 1}';
      }
    }
    return '${currentVer}_new';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  void _applyDurationPreset(Duration duration) {
    setState(() {
      _validFrom = DateTime.now().subtract(const Duration(minutes: 5));
      _validTo = DateTime.now().add(duration);
    });
  }

  void _applyTodayPreset() {
    final now = DateTime.now();
    setState(() {
      _validFrom = now.subtract(const Duration(minutes: 5));
      _validTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    });
  }

  Future<void> _pickNewPosterImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          _posters.add({
            'id': 'poster_${DateTime.now().millisecondsSinceEpoch}_${_posters.length}',
            'title': file.name.split('.').first,
            'content': '',
            'bytes': file.bytes,
            'fileName': file.name,
            'thumbnailBase64': file.bytes != null ? base64Encode(file.bytes!) : null,
          });
        }
      });
    }
  }

  void _addEmptyAnnouncement() {
    setState(() {
      _announcements.add({
        'id': 'ann_${DateTime.now().millisecondsSinceEpoch}_${_announcements.length}',
        'title': '',
        'content': '',
      });
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir paket başlığı girin.')),
      );
      return;
    }

    if (_posters.isEmpty && _announcements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az 1 görsel afiş veya 1 metin duyurusu ekleyin.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _statusText = 'Yayın paketi hazırlanıyor...';
    });

    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final boardIds = widget.targetBoards.map((b) => b.id).toList();

    try {
      setState(() => _statusText = 'Afişler yükleniyor ve sinyaller iletiliyor...');
      final pkg = await repo.dispatchPackageToBoards(
        boardIds: boardIds,
        title: _titleController.text,
        version: _versionController.text,
        validFrom: _validFrom,
        validTo: _validTo,
        posterInputs: _posters,
        announcementInputs: _announcements,
        schoolId: widget.schoolId,
      );

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${pkg.version} Yayın Paketi (${boardIds.length} tahtaya) başarıyla iletildi!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final targetCount = widget.targetBoards.length;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.95;
    final dialogHeight = screenSize.height * 0.85;

    return AlertDialog(
      title: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.editPackage != null ? 'Yayın Paketini Düzenle / Güncelle' : 'Yeni Yayın Paketi Oluştur',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$targetCount Açık Tahtaya Gönderilecek',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        ],
      ),
      content: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paket Başlığı ve Versiyon
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Paket Başlığı *',
                        hintText: 'Örn: 29 Ekim Cumhuriyet Bayramı Etkinlikleri',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _versionController,
                      decoration: const InputDecoration(
                        labelText: 'Versiyon',
                        hintText: 'v1.0',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gösterim Süresi & Preset Çipleri
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text('Yayın Geçerlilik Süresi:',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildPresetChip('Bugün', _applyTodayPreset),
                      _buildPresetChip('3 Gün', () => _applyDurationPreset(const Duration(days: 3))),
                      _buildPresetChip('1 Hafta', () => _applyDurationPreset(const Duration(days: 7))),
                      _buildPresetChip('15 Gün', () => _applyDurationPreset(const Duration(days: 15))),
                      _buildPresetChip('1 Ay', () => _applyDurationPreset(const Duration(days: 30))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Başlangıç: ${dateFormat.format(_validFrom)}',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _validFrom,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _validFrom = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_busy_rounded, size: 16),
                      label: Text('Bitiş: ${dateFormat.format(_validTo)}',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _validTo,
                          firstDate: _validFrom,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _validTo = picked.add(const Duration(hours: 23, minutes: 59)));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BÖLÜM 1: AFİŞLER (GÖRSELLER) KONTEYNERİ
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Görsel Afişler (${_posters.length})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                    label: const Text('+ Afiş Görseli Ekle'),
                    onPressed: _pickNewPosterImage,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_posters.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text('Henüz afiş görseli eklenmedi. Yukarıdaki "+ Afiş Görseli Ekle" butonuna tıklayarak JPG/PNG seçebilirsiniz.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _posters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = _posters[idx];
                    return _buildPosterEditItem(item, idx);
                  },
                ),
              const SizedBox(height: 24),

              // BÖLÜM 2: DUYURULAR (METİNLER) KONTEYNERİ
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.announcement_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Duyuru Metinleri (${_announcements.length})',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_comment_rounded, size: 16),
                    label: const Text('+ Duyuru Ekle'),
                    onPressed: _addEmptyAnnouncement,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_announcements.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text('Henüz duyuru metni eklenmedi. İsteğe bağlı olarak "+ Duyuru Ekle" ile ekleyebilirsiniz.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final ann = _announcements[idx];
                    return _buildAnnouncementEditItem(ann, idx);
                  },
                ),

              if (_statusText != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(_statusText!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Yayınla ve Tahtalara Gönder'),
          onPressed: _isSending ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildPosterEditItem(Map<String, dynamic> item, int index) {
    Widget preview;
    if (item['bytes'] != null) {
      preview = Image.memory(item['bytes'] as Uint8List, fit: BoxFit.cover);
    } else if (item['thumbnailBase64'] != null && item['thumbnailBase64'].toString().isNotEmpty) {
      try {
        preview = Image.memory(base64Decode(item['thumbnailBase64']), fit: BoxFit.cover);
      } catch (_) {
        preview = const Icon(Icons.broken_image_rounded);
      }
    } else if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty) {
      preview = Image.network(item['imageUrl'], fit: BoxFit.cover);
    } else {
      preview = const Icon(Icons.image_rounded);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Küçük Önizleme Resmi
          Container(
            width: 70,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(6), child: preview),
          ),
          const SizedBox(width: 12),

          // Başlık ve Not Kutuları
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: TextEditingController(text: item['title'])..selection = TextSelection.collapsed(offset: (item['title'] as String? ?? '').length),
                  onChanged: (val) => item['title'] = val,
                  decoration: InputDecoration(
                    labelText: 'Afiş Başlığı (${index + 1})',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: item['content'])..selection = TextSelection.collapsed(offset: (item['content'] as String? ?? '').length),
                  onChanged: (val) => item['content'] = val,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama / Not (Opsiyonel)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Sil Butonu
          IconButton(
            tooltip: 'Afişi Listeden Çıkar',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () => setState(() => _posters.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementEditItem(Map<String, dynamic> ann, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('📢', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: TextEditingController(text: ann['title'])..selection = TextSelection.collapsed(offset: (ann['title'] as String? ?? '').length),
                  onChanged: (val) => ann['title'] = val,
                  decoration: InputDecoration(
                    labelText: 'Duyuru Başlığı (${index + 1})',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: ann['content'])..selection = TextSelection.collapsed(offset: (ann['content'] as String? ?? '').length),
                  onChanged: (val) => ann['content'] = val,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Duyuru Metni',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Duyuruyu Çıkar',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () => setState(() => _announcements.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SÜRE UZATMA / KISALTMA DİALOGU
// ─────────────────────────────────────────────────────────────────────────────

class _AdjustDurationDialog extends StatefulWidget {
  final BroadcastPackageModel package;
  final List<BoardModel> targetBoards;
  final VoidCallback onSuccess;

  const _AdjustDurationDialog({
    required this.package,
    required this.targetBoards,
    required this.onSuccess,
  });

  @override
  State<_AdjustDurationDialog> createState() => _AdjustDurationDialogState();
}

class _AdjustDurationDialogState extends State<_AdjustDurationDialog> {
  late DateTime _validFrom;
  late DateTime _validTo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _validFrom = widget.package.validFrom;
    _validTo = widget.package.validTo;
  }

  void _addDays(int days) {
    setState(() {
      _validTo = _validTo.add(Duration(days: days));
    });
  }

  void _setEndTonight() {
    final now = DateTime.now();
    setState(() {
      _validTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
    });
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final boardIds = widget.targetBoards.map((b) => b.id).toList();

    try {
      await repo.updatePackageDuration(
        boardIds: boardIds,
        packageId: widget.package.id,
        validFrom: _validFrom,
        validTo: _validTo,
      );

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Yayın süresi başarıyla güncellendi!'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Süre güncelleme hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.92;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.more_time_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Flexible(
            child: Text('Yayın Süresini Güncelle', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paket: ${widget.package.title} (${widget.package.version})',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 16),

              Text('Hızlı Süre Ekle / Değiştir:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('+1 Gün'),
                    onPressed: () => _addDays(1),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('+3 Gün'),
                    onPressed: () => _addDays(3),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('+1 Hafta'),
                    onPressed: () => _addDays(7),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_round, size: 14),
                    label: const Text('Bu Gece Bitir'),
                    onPressed: _setEndTonight,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Yeni Bitiş Tarihi Seçici
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                icon: const Icon(Icons.event_busy_rounded, size: 16),
                label: Text('Bitiş Tarihi: ${dateFormat.format(_validTo)}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _validTo,
                    firstDate: _validFrom,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _validTo = picked.add(const Duration(hours: 23, minutes: 59)));
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'ℹ️ Belirlenen bitiş süresi dolduğunda akıllı tahtalar otomatik olarak varsayılan milli ve eğitim afişlerine geri döner.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Süreyi Kaydet'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAHTA EKLEME DİALOGU (YAYINDAKİ PAKETİ YENİ CİHAZLARA GÖNDERME)
// ─────────────────────────────────────────────────────────────────────────────

class _AddBoardsDialog extends StatefulWidget {
  final BroadcastPackageModel package;
  final List<BoardModel> allBoards;
  final VoidCallback onSuccess;

  const _AddBoardsDialog({
    required this.package,
    required this.allBoards,
    required this.onSuccess,
  });

  @override
  State<_AddBoardsDialog> createState() => _AddBoardsDialogState();
}

class _AddBoardsDialogState extends State<_AddBoardsDialog> {
  final Set<String> _selectedBoardIds = {};
  bool _isSending = false;
  String _filter = 'unassigned_online'; // 'unassigned_online', 'all_online', 'all'
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Varsayılan olarak: Açık olan ve bu pakete henüz sahip OLMAYAN tahtaları otomatik seç
    final unassignedOnline = widget.allBoards
        .where((b) => b.isOnline && !widget.package.targetBoardIds.contains(b.id))
        .map((b) => b.id);
    _selectedBoardIds.addAll(unassignedOnline);
  }

  void _selectAllUnassignedOnline() {
    setState(() {
      _selectedBoardIds.clear();
      final ids = widget.allBoards
          .where((b) => b.isOnline && !widget.package.targetBoardIds.contains(b.id))
          .map((b) => b.id);
      _selectedBoardIds.addAll(ids);
    });
  }

  void _selectAllOnline() {
    setState(() {
      _selectedBoardIds.clear();
      final ids = widget.allBoards.where((b) => b.isOnline).map((b) => b.id);
      _selectedBoardIds.addAll(ids);
    });
  }

  List<BoardModel> _getFilteredList() {
    return widget.allBoards.where((b) {
      if (_filter == 'unassigned_online' && (!b.isOnline || widget.package.targetBoardIds.contains(b.id))) {
        return false;
      }
      if (_filter == 'all_online' && !b.isOnline) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!b.name.toLowerCase().contains(q) && !b.gradeBranchLabel.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _submit() async {
    if (_selectedBoardIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen paketin iletileceği en az 1 tahta seçin.')),
      );
      return;
    }

    setState(() => _isSending = true);
    final repo = context.read<AdminRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await repo.addBoardsToPackage(
        packageId: widget.package.id,
        boardIds: _selectedBoardIds.toList(),
      );

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedBoardIds.length} akıllı tahtaya "${widget.package.title}" paketi başarıyla gönderildi!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Tahta ekleme hatası: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredList();
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.92;
    final dialogHeight = screenSize.height * 0.8;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_to_queue_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pakete Akıllı Tahta Ekle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.package.title} (${widget.package.version})',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sonradan açılan veya yayını almamış akıllı tahtaları seçerek bu paketi anında yüklenmiş gibi gönderebilirsiniz.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),

            // Hızlı Seçim Butonları
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 14),
                  label: const Text('Yeni Açık Tahtaları Seç'),
                  onPressed: _selectAllUnassignedOnline,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.select_all_rounded, size: 14),
                  label: const Text('Tüm Açıkları Seç'),
                  onPressed: _selectAllOnline,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => setState(() => _selectedBoardIds.clear()),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Arama ve Filtre
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Tahta veya sınıf ara...',
                        hintStyle: GoogleFonts.inter(fontSize: 11),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filter,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDark),
                  items: const [
                    DropdownMenuItem(value: 'unassigned_online', child: Text('Paketsiz Açık Tahtalar')),
                    DropdownMenuItem(value: 'all_online', child: Text('Tüm Açık Tahtalar')),
                    DropdownMenuItem(value: 'all', child: Text('Tüm Tahtalar')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _filter = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),

            // Tahtalar Listesi
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('Kriterlere uygun akıllı tahta bulunamadı.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final board = filtered[idx];
                        final isAlreadyAssigned = widget.package.targetBoardIds.contains(board.id);
                        final isSelected = _selectedBoardIds.contains(board.id);

                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedBoardIds.add(board.id);
                              } else {
                                _selectedBoardIds.remove(board.id);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Text(board.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (board.gradeBranchLabel.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgPage,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(board.gradeBranchLabel, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textGrey)),
                                ),
                              ],
                              const Spacer(),
                              if (isAlreadyAssigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('✅ Pakete Sahip', style: GoogleFonts.inter(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            board.isOnline ? '🟢 Çevrimiçi' : '⚪ Kapalı',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: board.isOnline ? AppColors.success : AppColors.textGrey,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text('Bu Cihazlara Gönder (${_selectedBoardIds.length})'),
          onPressed: _isSending ? null : _submit,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HAZIR ŞABLONLAR & PAKETLER DİALOGU
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatesDialog extends StatefulWidget {
  final List<BroadcastPackageModel> templates;
  final Function(BroadcastPackageModel template) onUseTemplate;
  final VoidCallback onRefresh;

  const _TemplatesDialog({
    required this.templates,
    required this.onUseTemplate,
    required this.onRefresh,
  });

  @override
  State<_TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends State<_TemplatesDialog> {
  Future<void> _deleteTemplate(BroadcastPackageModel template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Şablonu Sil'),
          ],
        ),
        content: Text('"${template.templateName ?? template.title}" şablonu silinecektir.\n\nOnaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final repo = context.read<AdminRepository>();
    await repo.deletePackage(template.id);
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.92;
    final dialogHeight = screenSize.height * 0.85;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bookmark_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Flexible(
            child: Text('Hazır Şablonlar & Paketler', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Okul etkinlikleri, törenler ve duyurular için hazır paketleri tek tıkla tahtalara yayınlayabilir veya mevcut paketleri şablon olarak saklayabilirsiniz.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: widget.templates.isEmpty
                  ? Center(
                      child: Text('Kayıtlı şablon bulunamadı.',
                          style: GoogleFonts.inter(color: AppColors.textGrey)),
                    )
                  : ListView.separated(
                      itemCount: widget.templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final t = widget.templates[idx];
                        final isBuiltIn = t.id.startsWith('builtin_');
                        final posters = t.posters;
                        final announcements = t.announcements;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          t.templateName ?? t.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isBuiltIn) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('Sistem Hazır Şablonu',
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (!isBuiltIn)
                                        IconButton(
                                          tooltip: 'Şablonu Sil',
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                          onPressed: () => _deleteTemplate(t),
                                        ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                                        label: const Text('Bu Şablonu Kullan'),
                                        onPressed: () => widget.onUseTemplate(t),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.title,
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (posters.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.image_rounded, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text('${posters.length} Afiş', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  if (announcements.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.announcement_rounded, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text('${announcements.length} Duyuru', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (announcements.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  announcements.first.content.isNotEmpty
                                      ? 'Örnek Metin: "${announcements.first.content}"'
                                      : 'Duyuru: "${announcements.first.title}"',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
