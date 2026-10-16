// lib/presentation/screens/boards_manage_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/board_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/school_selector_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/app_dialog.dart';

class BoardsManageScreen extends StatefulWidget {
  const BoardsManageScreen({super.key});

  @override
  State<BoardsManageScreen> createState() => _BoardsManageScreenState();
}

class _BoardsManageScreenState extends State<BoardsManageScreen> {
  String _searchQuery = '';
  List<BoardModel> _allBoards = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<BoardModel>>? _boardsSub;
  String? _lastLoadedSchoolId;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final currentSchoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    if (!_isInit || currentSchoolId != _lastLoadedSchoolId) {
      _isInit = true;
      _lastLoadedSchoolId = currentSchoolId;
      _initBoards(currentSchoolId);
    }
  }

  @override
  void dispose() {
    _boardsSub?.cancel();
    super.dispose();
  }

  Future<void> _initBoards(String? schoolId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = context.read<AdminRepository>();

    // 1. Önce REST ile anında getir
    try {
      final initialBoards = await repo.getBoards(schoolId);
      if (mounted) {
        setState(() {
          _allBoards = initialBoards;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('getBoards error: $e');
    }

    // 2. Realtime stream dinle
    await _boardsSub?.cancel();
    _boardsSub = repo.streamBoards(schoolId).listen(
      (liveBoards) {
        if (mounted) {
          setState(() {
            _allBoards = liveBoards;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted && _allBoards.isEmpty) {
          setState(() {
            _errorMessage = 'Bağlantı hatası: $e';
            _isLoading = false;
          });
        }
      },
    );
  }

  List<BoardModel> _getFilteredBoards() {
    if (_searchQuery.isEmpty) return _allBoards;
    final q = _searchQuery.toLowerCase();
    return _allBoards.where((b) {
      return b.name.toLowerCase().contains(q) ||
          (b.grade?.toLowerCase().contains(q) ?? false) ||
          (b.branch?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final repo = context.read<AdminRepository>();

    final schoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    final boards = _getFilteredBoards();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Yenile + Ekle Butonu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahta Yönetimi',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _isLoading && _allBoards.isEmpty
                          ? 'Tahtalar yükleniyor...'
                          : '${_allBoards.length} kayıtlı tahta',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
                tooltip: 'Yenile',
                onPressed: () => _initBoards(schoolId),
              ),
              const SizedBox(width: 8),
              if (schoolId != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('Yeni Tahta Eşleştir'),
                  onPressed: () => showBoardDialog(
                    context,
                    schoolId: schoolId,
                    onPair: ({
                      required pairingCode,
                      required name,
                      grade,
                      branch,
                      required autoLockMinutes,
                    }) async {
                      await repo.pairBoard(
                        pairingCode: pairingCode,
                        schoolId: schoolId,
                        name: name,
                        grade: grade,
                        branch: branch,
                        autoLockMinutes: autoLockMinutes,
                      );
                      _initBoards(schoolId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tahta başarıyla eşleştirildi!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    onUpdate: ({
                      required boardId,
                      required name,
                      grade,
                      branch,
                      required autoLockMinutes,
                      required isActive,
                    }) async {},
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Arama
          SizedBox(
            width: 300,
            height: 44,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Tahta adı, sınıf veya şube ara...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textGrey, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: AppColors.bgCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tablo
          Expanded(
            child: _isLoading && _allBoards.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null && _allBoards.isEmpty
                    ? Center(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: AppColors.danger)),
                      )
                    : boards.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tv_off_rounded,
                                    size: 56, color: AppColors.textLight),
                                const SizedBox(height: 16),
                                Text(
                                  _allBoards.isEmpty
                                      ? (schoolId == null
                                          ? 'Sistemde kayıtlı tahta bulunamadı.'
                                          : 'Henüz tahta eklenmemiş. "Yeni Tahta Eşleştir" butonunu kullanın.')
                                      : 'Arama kriterlerine uygun tahta bulunamadı.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textGrey,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppColors.bgPage,
                                  ),
                                  headingTextStyle: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textGrey,
                                    letterSpacing: 0.5,
                                  ),
                                  dataTextStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textDark,
                                  ),
                                  columnSpacing: 24,
                                  horizontalMargin: 20,
                                  columns: const [
                                    DataColumn(label: Text('TAHTA ADI')),
                                    DataColumn(label: Text('SINIF / ŞUBE')),
                                    DataColumn(label: Text('KİLİT DURUMU')),
                                    DataColumn(label: Text('CİHAZ DURUMU')),
                                    DataColumn(label: Text('SÜRÜM')),
                                    DataColumn(label: Text('OTO KİLİT')),
                                    DataColumn(label: Text('İŞLEMLER')),
                                  ],
                                  rows: boards.map((board) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(board.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600))),
                                        DataCell(Text(board.gradeBranchLabel.isEmpty
                                            ? '—'
                                            : board.gradeBranchLabel)),
                                        DataCell(_StatusBadge(board.status)),
                                        DataCell(_DeviceBadge(board.isOnline)),
                                        DataCell(Text(
                                          board.appVersion != null && board.appVersion!.isNotEmpty
                                              ? 'v${board.appVersion}'
                                              : '—',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: board.appVersion != null
                                                ? AppColors.primary
                                                : AppColors.textGrey,
                                          ),
                                        )),
                                        DataCell(Text('${board.autoLockMinutes} dk')),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded,
                                                    color: AppColors.info, size: 18),
                                                tooltip: 'Düzenle',
                                                onPressed: () => showBoardDialog(
                                                  context,
                                                  board: {
                                                    'id': board.id,
                                                    'name': board.name,
                                                    'grade': board.grade ?? '',
                                                    'branch': board.branch ?? '',
                                                    'auto_lock_minutes':
                                                        board.autoLockMinutes,
                                                    'is_active': board.isActive,
                                                  },
                                                  schoolId: board.schoolId ?? '',
                                                  onPair: ({
                                                    required pairingCode,
                                                    required name,
                                                    grade,
                                                    branch,
                                                    required autoLockMinutes,
                                                  }) async {},
                                                  onUpdate: ({
                                                    required boardId,
                                                    required name,
                                                    grade,
                                                    branch,
                                                    required autoLockMinutes,
                                                    required isActive,
                                                  }) async {
                                                    await repo.updateBoard(
                                                      boardId: boardId,
                                                      name: name,
                                                      grade: grade,
                                                      branch: branch,
                                                      autoLockMinutes: autoLockMinutes,
                                                      isActive: isActive,
                                                    );
                                                    _initBoards(schoolId);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content:
                                                              Text('Tahta güncellendi.'),
                                                          backgroundColor:
                                                              AppColors.success,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.link_off_rounded,
                                                    color: AppColors.danger, size: 18),
                                                tooltip: 'Eşleşmeyi Kaldır',
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showConfirmDialog(
                                                    context,
                                                    title: 'Eşleşmeyi Kaldır',
                                                    content:
                                                        '"${board.name}" tahtasını sistemden kaldırmak istiyor musunuz?',
                                                    confirmLabel: 'Kaldır',
                                                    icon: Icons.link_off_rounded,
                                                  );
                                                  if (confirmed && context.mounted) {
                                                    await repo.deleteBoard(board.id);
                                                    _initBoards(schoolId);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              '"${board.name}" kaldırıldı.'),
                                                          backgroundColor:
                                                              AppColors.textDark,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BoardStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case BoardStatus.unlocked:
        color = AppColors.success;
        label = 'Açık';
        break;
      case BoardStatus.locked:
        color = AppColors.danger;
        label = 'Kilitli';
        break;
      case BoardStatus.inactive:
        color = AppColors.offline;
        label = 'Pasif';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _DeviceBadge extends StatelessWidget {
  final bool isOnline;
  const _DeviceBadge(this.isOnline);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.offline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.offline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? AppColors.success : AppColors.offline,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Açık' : 'Kapalı',
            style: TextStyle(
              color: isOnline ? AppColors.success : AppColors.offline,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
