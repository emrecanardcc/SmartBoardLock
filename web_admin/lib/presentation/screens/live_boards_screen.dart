// lib/presentation/screens/live_boards_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/board_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/school_selector_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/board_card.dart';
import '../widgets/kpi_card.dart';
import '../widgets/app_dialog.dart';

class LiveBoardsScreen extends StatefulWidget {
  const LiveBoardsScreen({super.key});

  @override
  State<LiveBoardsScreen> createState() => _LiveBoardsScreenState();
}

class _LiveBoardsScreenState extends State<LiveBoardsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'Tümü';
  String _gradeFilter = 'Tümü';
  String? _latestVersion;

  List<BoardModel> _allBoards = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<BoardModel>>? _boardsSub;
  String? _lastLoadedSchoolId;
  bool _isInit = false;
  bool _isSelectMode = false;
  final Set<String> _selectedBoardIds = {};

  final List<String> _gradeOptions = [
    'Tümü',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLatestVersion();
  }

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

  Future<void> _fetchLatestVersion() async {
    try {
      final repo = context.read<AdminRepository>();
      final v = await repo.getLatestVersionNumber();
      if (mounted) {
        setState(() => _latestVersion = v);
      }
    } catch (_) {}
  }

  Future<void> _initBoards(String? schoolId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = context.read<AdminRepository>();

    // 1. Önce REST ile ilk veriyi anında (50ms) getir — böylece UI hiç takılmaz
    try {
      final initialBoards = await repo.getBoards(schoolId);
      if (mounted) {
        setState(() {
          _allBoards = initialBoards;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('getBoards initial error: $e');
    }

    // 2. Realtime stream aboneliğini başlat (canlı durum güncellemeleri için)
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
        debugPrint('streamBoards error: $e');
        if (mounted && _allBoards.isEmpty) {
          setState(() {
            _errorMessage = 'Canlı bağlantı hatası: $e';
            _isLoading = false;
          });
        }
      },
    );
  }

  List<BoardModel> _applyFilters(List<BoardModel> boards) {
    var filtered = boards;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        return b.name.toLowerCase().contains(q) ||
            (b.grade?.toLowerCase().contains(q) ?? false) ||
            (b.branch?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_statusFilter != 'Tümü') {
      filtered = filtered.where((b) {
        switch (_statusFilter) {
          case 'Açık':
            return b.isUnlocked && b.isActive;
          case 'Kilitli':
            return !b.isUnlocked && b.isActive;
          case 'Açık PC':
            return b.isOnline;
          case 'Kapalı PC':
            return !b.isOnline;
          case 'Pasif':
            return !b.isActive;
          default:
            return true;
        }
      }).toList();
    }

    if (_gradeFilter != 'Tümü') {
      filtered = filtered.where((b) {
        if (_gradeFilter == 'Diğer') {
          return b.grade == null ||
              b.grade!.isEmpty ||
              !['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'].contains(b.grade);
        }
        return b.grade == _gradeFilter;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final repo = context.read<AdminRepository>();
    final actorName =
        authProvider.currentUser?.displayName ?? 'Yönetici (Web Panel)';

    final schoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    final filteredBoards = _applyFilters(_allBoards);

    // KPI hesaplamaları
    final totalBoards = _allBoards.length;
    final openBoards = _allBoards
        .where((b) => b.isUnlocked && b.isActive)
        .length;
    final lockedBoards = _allBoards
        .where((b) => !b.isUnlocked && b.isActive)
        .length;
    final onlineComputers = _allBoards
        .where((b) => b.isOnline)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // İçerik başlığı
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canlı Tahta İzleme',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _isLoading && _allBoards.isEmpty
                          ? 'Yükleniyor...'
                          : '$totalBoards kayıtlı tahta • Canlı senkronize',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),

              // Yenile butonu
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
                tooltip: 'Yenile',
                onPressed: () => _initBoards(schoolId),
              ),
              const SizedBox(width: 8),

              // Toplu aksiyon butonları
              if (schoolId != null || !authProvider.isSuperAdmin) ...[
                _BulkActionButton(
                  label: 'Tümünü Kilitle',
                  icon: Icons.lock_rounded,
                  color: AppColors.danger,
                  onPressed: () async {
                    final sid = authProvider.isSuperAdmin
                        ? selectorProvider.activeSchoolId
                        : authProvider.currentUser?.schoolId;
                    if (sid == null) return;

                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Tümünü Kilitle',
                      content:
                          'Okuldaki tüm aktif tahtalar kilitlenecektir. Onaylıyor musunuz?',
                      confirmLabel: 'Hepsini Kilitle',
                      icon: Icons.lock_rounded,
                    );
                    if (confirmed && context.mounted) {
                      try {
                        await repo.lockAllBoards(
                            schoolId: sid, actorName: actorName);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tüm tahtalar kilitlendi.'),
                              backgroundColor: AppColors.success,
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
                  },
                ),
                const SizedBox(width: 8),
                _BulkActionButton(
                  label: 'Tümünü Aç',
                  icon: Icons.lock_open_rounded,
                  color: AppColors.success,
                  onPressed: () async {
                    final sid = authProvider.isSuperAdmin
                        ? selectorProvider.activeSchoolId
                        : authProvider.currentUser?.schoolId;
                    if (sid == null) return;

                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Tümünü Aç',
                      content:
                          'Okuldaki tüm aktif tahtalar kullanıma açılacaktır. Onaylıyor musunuz?',
                      confirmLabel: 'Hepsini Aç',
                      confirmColor: AppColors.success,
                      icon: Icons.lock_open_rounded,
                    );
                    if (confirmed && context.mounted) {
                      try {
                        await repo.unlockAllBoards(
                            schoolId: sid, actorName: actorName);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tüm tahtalar açıldı.'),
                              backgroundColor: AppColors.success,
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
                  },
                ),
                const SizedBox(width: 8),
                _BulkActionButton(
                  label: 'Bilgisayarları Kapat',
                  icon: Icons.power_settings_new_rounded,
                  color: const Color(0xFFDC2626),
                  onPressed: () async {
                    final onlineBoards = _allBoards.where((b) => b.isOnline).toList();
                    if (onlineBoards.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Şu an açık olan tahta bilgisayarı bulunmuyor.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Tüm Açık Bilgisayarları Kapat',
                      content:
                          'Okulda o an açık çalışan ${onlineBoards.length} adet akıllı tahta bilgisayarı uzaktan kapatılacaktır.\n\nBu işlem Windows işletim sistemini güvenli şekilde kapatır. Onaylıyor musunuz?',
                      confirmLabel: 'Hepsini Kapat (${onlineBoards.length})',
                      confirmColor: AppColors.danger,
                      icon: Icons.power_settings_new_rounded,
                    );
                    if (confirmed && context.mounted) {
                      try {
                        await repo.sendBulkRemoteShutdown(
                            onlineBoards.map((b) => b.id).toList());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${onlineBoards.length} akıllı tahtaya uzaktan kapatma komutu iletildi.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kapatma hatası: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: Icon(
                      _isSelectMode
                          ? Icons.close_rounded
                          : Icons.checklist_rounded,
                      size: 16),
                  label: Text(_isSelectMode ? 'Seçimi Kapat' : 'Çoklu Seçim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isSelectMode
                        ? AppColors.danger
                        : AppColors.primary,
                    side: BorderSide(
                        color: _isSelectMode
                            ? AppColors.danger
                            : AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSelectMode = !_isSelectMode;
                      if (!_isSelectMode) _selectedBoardIds.clear();
                    });
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // KPI Kartları
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _KpiRow(
            total: totalBoards,
            open: openBoards,
            locked: lockedBoards,
            online: onlineComputers,
          ),
        ),

        const SizedBox(height: 20),

        // Filtre ve Arama Barı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _FilterBar(
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            statusFilter: _statusFilter,
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            gradeFilter: _gradeFilter,
            gradeOptions: _gradeOptions,
            onGradeChanged: (v) => setState(() => _gradeFilter = v),
          ),
        ),

        // Çoklu Seçim Aksiyon Çubuğu
        if (_isSelectMode) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: filteredBoards.isNotEmpty &&
                            filteredBoards.every((b) => _selectedBoardIds.contains(b.id)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedBoardIds.addAll(filteredBoards.map((b) => b.id));
                            } else {
                              _selectedBoardIds.removeAll(filteredBoards.map((b) => b.id));
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      Text(
                        '${_selectedBoardIds.length} / ${filteredBoards.length} tahta seçildi',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Seçilenleri Kapat
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_settings_new_rounded, size: 15),
                        label: Text('Kapat (${_allBoards.where((b) => _selectedBoardIds.contains(b.id) && b.isOnline).length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _selectedBoardIds.isEmpty
                            ? null
                            : () async {
                                final selectedOnline = _allBoards
                                    .where((b) => _selectedBoardIds.contains(b.id) && b.isOnline)
                                    .map((b) => b.id)
                                    .toList();
                                if (selectedOnline.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Seçilen tahtalardan hiçbiri şu an açık değil.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Seçilen Bilgisayarları Kapat',
                                  content:
                                      '${selectedOnline.length} adet akıllı tahta bilgisayarı uzaktan kapatılacaktır. Onaylıyor musunuz?',
                                  confirmLabel: 'Kapat (${selectedOnline.length})',
                                  confirmColor: AppColors.danger,
                                  icon: Icons.power_settings_new_rounded,
                                );
                                if (confirmed && context.mounted) {
                                  await repo.sendBulkRemoteShutdown(selectedOnline);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${selectedOnline.length} bilgisayara kapatma komutu iletildi.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    setState(() => _selectedBoardIds.clear());
                                  }
                                }
                              },
                      ),
                      // Seçilenleri Kilitle
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lock_rounded, size: 15),
                        label: Text('Kilitle (${_selectedBoardIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _selectedBoardIds.isEmpty
                            ? null
                            : () async {
                                for (final id in _selectedBoardIds) {
                                  await repo.toggleBoardLock(boardId: id, newUnlocked: false, actorName: actorName);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Seçilen tahtalar kilitlendi.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  setState(() => _selectedBoardIds.clear());
                                }
                              },
                      ),
                      // Seçilenleri Aç
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lock_open_rounded, size: 15),
                        label: Text('Aç (${_selectedBoardIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: _selectedBoardIds.isEmpty
                            ? null
                            : () async {
                                for (final id in _selectedBoardIds) {
                                  await repo.toggleBoardLock(boardId: id, newUnlocked: true, actorName: actorName);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Seçilen tahtalar kullanıma açıldı.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  setState(() => _selectedBoardIds.clear());
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Tahta Grid
        Expanded(
          child: _isLoading && _allBoards.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _errorMessage != null && _allBoards.isEmpty
                  ? Center(
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.danger)),
                    )
                  : filteredBoards.isEmpty
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
                                        : 'Bu okulda henüz tahta bulunmuyor.')
                                    : 'Kriterlere uygun tahta bulunamadı.',
                                style: GoogleFonts.inter(
                                  color: AppColors.textGrey,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 350,
                            mainAxisExtent: 335,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredBoards.length,
                          itemBuilder: (context, index) {
                            final board = filteredBoards[index];
                            return BoardCard(
                              board: board,
                              latestVersion: _latestVersion,
                              actorName: actorName,
                              isSuperAdmin: authProvider.isSuperAdmin,
                              isSelectable: _isSelectMode,
                              isSelected: _selectedBoardIds.contains(board.id),
                              onSelectChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedBoardIds.add(board.id);
                                  } else {
                                    _selectedBoardIds.remove(board.id);
                                  }
                                });
                              },
                              onRepairIntegrity: authProvider.isSuperAdmin
                                  ? () async {
                                      await repo.sendRepairIntegrityCommand(board.id);
                                    }
                                  : null,
                              onToggleLock: (newState) async {
                                await repo.toggleBoardLock(
                                  boardId: board.id,
                                  newUnlocked: newState,
                                  actorName: actorName,
                                );
                              },
                              onRemoteShutdown: () async {
                                await repo.sendRemoteShutdown(board.id);
                              },
                              onEdit: () => showBoardDialog(
                                context,
                                board: {
                                  'id': board.id,
                                  'name': board.name,
                                  'grade': board.grade,
                                  'branch': board.branch,
                                  'is_active': board.isActive,
                                },
                                schoolId: board.schoolId ?? '',
                                onPair: ({
                                  required pairingCode,
                                  required name,
                                  grade,
                                  branch,
                                }) async {},
                                onUpdate: ({
                                  required boardId,
                                  required name,
                                  grade,
                                  branch,
                                  required isActive,
                                }) async {
                                  await repo.updateBoard(
                                    boardId: boardId,
                                    name: name,
                                    grade: grade,
                                    branch: branch,
                                    isActive: isActive,
                                  );
                                },
                              ),
                              onDelete: () async {
                                final confirmed = await showConfirmDialog(
                                  context,
                                  title: 'Tahtayı Kaldır',
                                  content:
                                      '"${board.name}" adlı tahtanın eşleşmesi kalıcı olarak silinecek.',
                                  confirmLabel: 'Kaldır',
                                  icon: Icons.link_off_rounded,
                                );
                                if (confirmed && context.mounted) {
                                  await repo.deleteBoard(board.id);
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final int total, open, locked, online;

  const _KpiRow({
    required this.total,
    required this.open,
    required this.locked,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 48) / 4;
      return Row(
        children: [
          SizedBox(
            width: itemWidth,
            child: KpiCard(
              title: 'Toplam Tahta',
              value: total.toString(),
              icon: Icons.tv_rounded,
              color: AppColors.info,
              subtitle: 'Okul geneli kayıtlı',
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: itemWidth,
            child: KpiCard(
              title: 'Kullanıma Açık',
              value: open.toString(),
              icon: Icons.lock_open_rounded,
              color: AppColors.success,
              subtitle: 'Öğretmen ders işliyor',
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: itemWidth,
            child: KpiCard(
              title: 'Kilitli Tahtalar',
              value: locked.toString(),
              icon: Icons.lock_rounded,
              color: AppColors.danger,
              subtitle: 'Güvenli bekleme modunda',
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: itemWidth,
            child: KpiCard(
              title: 'Açık Bilgisayarlar',
              value: online.toString(),
              icon: Icons.power_rounded,
              color: AppColors.primary,
              subtitle: 'O an çalışan cihazlar',
            ),
          ),
        ],
      );
    });
  }
}

class _FilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final String gradeFilter;
  final List<String> gradeOptions;
  final ValueChanged<String> onGradeChanged;

  const _FilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.gradeFilter,
    required this.gradeOptions,
    required this.onGradeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Arama
        SizedBox(
          width: 240,
          height: 44,
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Tahta adı, sınıf, şube...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textGrey, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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

        // Durum filtresi
        for (final label in ['Tümü', 'Açık', 'Kilitli', 'Açık PC', 'Kapalı PC', 'Pasif'])
          _FilterChip(
            label: label,
            isSelected: statusFilter == label,
            onTap: () => onStatusChanged(label),
            color: label == 'Açık'
                ? AppColors.success
                : label == 'Kilitli'
                    ? AppColors.danger
                    : label == 'Açık PC'
                        ? AppColors.primary
                        : label == 'Kapalı PC'
                            ? AppColors.offline
                            : label == 'Pasif'
                                ? AppColors.warning
                                : AppColors.info,
          ),

        const SizedBox(width: 4),

        // Sınıf filtresi dropdown
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: gradeFilter,
              icon: const Icon(Icons.expand_more_rounded,
                  size: 16, color: AppColors.textGrey),
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              items: gradeOptions
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g == 'Tümü'
                            ? 'Tüm Sınıflar'
                            : g == 'Diğer'
                                ? 'Diğer'
                                : '$g. Sınıf'),
                      ))
                  .toList(),
              onChanged: (v) => onGradeChanged(v ?? 'Tümü'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textGrey,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _BulkActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
    );
  }
}
