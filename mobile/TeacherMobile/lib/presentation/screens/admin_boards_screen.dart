import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_teachers_screen.dart';
import '../widgets/report_issue_dialog.dart';
import '../widgets/tutorial_tips_dialog.dart';
import '../../data/datasources/supabase_datasource.dart';

// --- RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);
const Color cardColor = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF0F172A);
const Color textGrey = Color(0xFF64748B);
const Color primaryBlue = Color(0xFF3B82F6);
const Color successGreen = Color(0xFF10B981);
const Color warningOrange = Color(0xFFF59E0B);
const Color dangerRed = Color(0xFFF43F5E);

class AdminBoardsScreen extends StatefulWidget {
  const AdminBoardsScreen({super.key});

  @override
  State<AdminBoardsScreen> createState() => _AdminBoardsScreenState();
}

class _AdminBoardsScreenState extends State<AdminBoardsScreen> {
  final _client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _boardChannel;
  RealtimeChannel? _schoolChannel;

  String? _schoolId;
  String? _schoolName;
  String? _adminName;
  bool _isLoadingProfile = true;
  bool _isSchoolLicensed = true;
  DateTime? _licenseExpiresAt;
  int _remainingLicenseDays = 0;

  // Sayfalama (Lazy Loading) ve Filtreleme
  final List<Map<String, dynamic>> _boards = [];
  final int _limit = 6;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Kademe ve 1-12 Sınıf Filtreleri
  String _selectedKademe = 'Tümü';
  final List<String> _kademeOptions = ['Tümü', 'İlkokul (1-4)', 'Ortaokul (5-8)', 'Lise (9-12)', 'Diğer'];

  String _selectedGrade = 'Tümü';
  final List<String> _gradeOptions = [
    'Tümü',
    '1', '2', '3', '4',
    '5', '6', '7', '8',
    '9', '10', '11', '12',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _initData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _fetchBoards();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _boardChannel?.unsubscribe();
    _schoolChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadAdminData();
    if (_schoolId != null) {
      await _fetchBoards(refresh: true);
      _setupRealtime();
    }
  }

  bool _evalLicense(Map<String, dynamic>? data) {
    if (data == null) return true;
    final isLicensed = data['is_licensed'] as bool? ?? true;
    if (!isLicensed) return false;
    final expiresAtStr = data['license_expires_at'] as String?;
    if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
      final dt = DateTime.tryParse(expiresAtStr);
      if (dt != null && dt.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _client.from('user_profiles').select('school_id, full_name').eq('id', user.id).single();
        _schoolId = profile['school_id'];
        _adminName = profile['full_name'] ?? 'Kurum Yöneticisi';

        if (_schoolId != null) {
          final schoolData = await _client.from('schools').select('name, is_licensed, license_expires_at').eq('id', _schoolId!).maybeSingle();
          _schoolName = schoolData?['name'];
          _isSchoolLicensed = _evalLicense(schoolData);
          final expStr = schoolData?['license_expires_at'] as String?;
          if (expStr != null && expStr.isNotEmpty) {
            _licenseExpiresAt = DateTime.tryParse(expStr);
            if (_licenseExpiresAt != null) {
              _remainingLicenseDays = _licenseExpiresAt!.difference(DateTime.now()).inDays;
            }
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  List<String> _getFilteredGradesForCurrentKademe() {
    if (_selectedKademe == 'İlkokul (1-4)') {
      return ['Tümü', '1', '2', '3', '4'];
    } else if (_selectedKademe == 'Ortaokul (5-8)') {
      return ['Tümü', '5', '6', '7', '8'];
    } else if (_selectedKademe == 'Lise (9-12)') {
      return ['Tümü', '9', '10', '11', '12'];
    } else if (_selectedKademe == 'Diğer') {
      return ['Tümü', 'Diğer'];
    }
    return _gradeOptions;
  }

  // --- LAZY LOADING SORGUSU ---
  Future<void> _fetchBoards({bool refresh = false}) async {
    if (refresh) {
      _boards.clear();
      _hasMore = true;
    }
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      // Müdür tüm tahtaları (aktif ve pasif) görür
      var query = _client.from('boards').select().eq('school_id', _schoolId!);

      // Sınıf veya Kademe Filtresi
      if (_selectedGrade != 'Tümü') {
        query = query.eq('grade', _selectedGrade);
      } else if (_selectedKademe == 'İlkokul (1-4)') {
        query = query.inFilter('grade', ['1', '2', '3', '4']);
      } else if (_selectedKademe == 'Ortaokul (5-8)') {
        query = query.inFilter('grade', ['5', '6', '7', '8']);
      } else if (_selectedKademe == 'Lise (9-12)') {
        query = query.inFilter('grade', ['9', '10', '11', '12']);
      } else if (_selectedKademe == 'Diğer') {
        query = query.or('grade.eq.Diğer,grade.is.null');
      }

      final from = _boards.length;
      final to = from + _limit - 1;

      final response = await query.order('name', ascending: true).range(from, to);
      final List<Map<String, dynamic>> newBoards = List<Map<String, dynamic>>.from(response);

      if (newBoards.length < _limit) _hasMore = false;

      setState(() {
        _boards.addAll(newBoards);
      });
    } catch (e) {
      debugPrint("Fetch hatası: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // --- REALTIME DİNLEYİCİ ---
  void _setupRealtime() {
    if (_schoolId == null) return;

    _boardChannel = _client.channel('admin_realtime:$_schoolId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'boards',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'school_id',
        value: _schoolId!,
      ),
      callback: (payload) {
        setState(() {
          if (payload.eventType == PostgresChangeEvent.insert) {
            _boards.insert(0, payload.newRecord);
          } else if (payload.eventType == PostgresChangeEvent.update) {
            final idx = _boards.indexWhere((b) => b['id'] == payload.newRecord['id']);
            if (idx != -1) _boards[idx] = payload.newRecord;
          } else if (payload.eventType == PostgresChangeEvent.delete) {
            _boards.removeWhere((b) => b['id'] == payload.oldRecord['id']);
          }
        });
      },
    ).subscribe();

    if (_schoolId != null) {
      _schoolChannel = _client.channel('admin_school_realtime:$_schoolId').onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'schools',
        callback: (payload) {
          if (payload.newRecord['id'] == _schoolId) {
            setState(() {
              _isSchoolLicensed = _evalLicense(payload.newRecord);
              if (payload.newRecord['name'] != null) {
                _schoolName = payload.newRecord['name'];
              }
              final expStr = payload.newRecord['license_expires_at'] as String?;
              if (expStr != null && expStr.isNotEmpty) {
                _licenseExpiresAt = DateTime.tryParse(expStr);
                if (_licenseExpiresAt != null) {
                  _remainingLicenseDays = _licenseExpiresAt!.difference(DateTime.now()).inDays;
                }
              }
            });
          }
        },
      ).subscribe();
    }
  }

  // --- YARDIMCI METOTLAR ---
  String _generateOfflineSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _showModernSnackbar(String message, {required bool isSuccess, required Color bgColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleBoardLock(String boardId, bool currentStatus) async {
    if (!_isSchoolLicensed) {
      _showModernSnackbar('Kurum lisansı sona ermiştir. İşlem yapılamaz. Lisans yenileme: emrecanardc.dev@gmail.com', isSuccess: false, bgColor: dangerRed);
      return;
    }

    final newStatus = !currentStatus;
    final index = _boards.indexWhere((b) => b['id'] == boardId);

    // İyimser UI Güncellemesi (Kullanıcı anında tepki görür)
    if (index != -1) {
      setState(() {
        _boards[index]['is_unlocked'] = newStatus;
        if (newStatus) {
          _boards[index]['last_unlocked_by'] = _adminName;
        } else {
          _boards[index]['last_locked_by'] = _adminName;
        }
      });
    }

    try {
      final updateData = <String, dynamic>{'is_unlocked': newStatus};
      if (newStatus) {
        updateData['last_unlocked_by'] = _adminName;
      } else {
        updateData['last_locked_by'] = _adminName;
      }

      final success = await SupabaseDatasource.syncBoardPatch(boardId: boardId, patchData: updateData);
      if (success) {
        if (mounted) {
          _showModernSnackbar(
            newStatus ? 'Tahta kilidi başarıyla açıldı.' : 'Tahta başarıyla kilitlendi.',
            isSuccess: true,
            bgColor: textDark,
          );
        }
      } else {
        // Hata durumunda iyimser güncellemeyi geri al
        if (index != -1) {
          setState(() {
            _boards[index]['is_unlocked'] = currentStatus;
          });
        }
        if (mounted) {
          _showModernSnackbar('Kilit durumu sunucuya iletilemedi.', isSuccess: false, bgColor: dangerRed);
        }
      }
    } catch (e) {
      if (index != -1) {
        setState(() {
          _boards[index]['is_unlocked'] = currentStatus;
        });
      }
      if (mounted) {
        _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
      }
    }
  }

  Future<void> _lockAllBoards() async {
    if (!_isSchoolLicensed) {
      _showModernSnackbar('Kurum lisansı sona ermiştir. İşlem yapılamaz. Lisans yenileme: emrecanardc.dev@gmail.com', isSuccess: false, bgColor: dangerRed);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tümünü Kilitle', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        content: const Text('Okuldaki tüm akıllı tahtaları kilitlemek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hepsini Kilitle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final patch = {'is_unlocked': false, 'last_locked_by': _adminName};
      await Future.wait([
        SupabaseDatasource.primaryClient.from('boards').update(patch).eq('school_id', _schoolId!).catchError((_) => null),
        SupabaseDatasource.fallbackClient.from('boards').update(patch).eq('school_id', _schoolId!).catchError((_) => null),
        _client.from('boards').update(patch).eq('school_id', _schoolId!).catchError((_) => null),
      ]);
      setState(() {
        for (var b in _boards) {
          b['is_unlocked'] = false;
          b['last_locked_by'] = _adminName;
        }
      });
      if (mounted) _showModernSnackbar('Tüm tahtalar kilitlendi.', isSuccess: true, bgColor: textDark);
    } catch (e) {
      if (mounted) _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
  }

  Future<void> _unpairBoard(String boardId, String boardName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [Icon(Icons.warning_rounded, color: dangerRed), SizedBox(width: 12), Text('Dikkat')]),
        content: Text('$boardName adlı tahtanın eşleşmesini kalıcı olarak kaldırmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _client.from('boards').delete().eq('id', boardId);
      if (mounted) _showModernSnackbar('$boardName kaldırıldı.', isSuccess: true, bgColor: textDark);
    } catch (e) {
      if (mounted) _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
  }

  // --- EKLEME VE DÜZENLEME DİYALOĞU ---
  Future<void> _showAddEditBoardDialog({Map<String, dynamic>? board}) async {
    final isEditing = board != null;
    final nameController = TextEditingController(text: board?['name'] ?? '');
    final gradeController = TextEditingController(text: board?['grade'] ?? '');
    final branchController = TextEditingController(text: board?['branch'] ?? '');
    bool isActive = board?['is_active'] ?? true;
    String pairingCode = "";
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(isEditing ? 'Tahtayı Düzenle' : 'Yeni Tahta Eşleştir', style: const TextStyle(color: textDark, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Görünen Ad (Örn: Sınıf 1)',
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: gradeController,
                            decoration: InputDecoration(
                              labelText: 'Sınıf (1-12)',
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: branchController,
                            decoration: InputDecoration(
                              labelText: 'Şube (Örn: A)',
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? successGreen.withValues(alpha: 0.1) : dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isActive ? successGreen.withValues(alpha: 0.3) : dangerRed.withValues(alpha: 0.3)),
                      ),
                      child: SwitchListTile(
                        value: isActive,
                        onChanged: (val) => setDialogState(() => isActive = val),
                        title: Text('Durum: ${isActive ? 'Aktif' : 'Pasif'}', style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? successGreen : dangerRed)),
                        activeThumbColor: successGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 24),
                      const Text('6 Haneli Kod', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      OtpInputBoxes(onCodeChanged: (code) => pairingCode = code),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSaving ? null : () async {
                  final cleanPairingCode = pairingCode.replaceAll(RegExp(r'\D'), '').trim();
                  if (nameController.text.trim().isEmpty || (!isEditing && cleanPairingCode.length != 6)) {
                    _showModernSnackbar('Lütfen zorunlu alanları doldurun (6 haneli eşleşme kodu).', isSuccess: false, bgColor: warningOrange);
                    return;
                  }
                  setDialogState(() => isSaving = true);

                  try {
                    if (isEditing) {
                      await SupabaseDatasource.syncBoardPatch(
                        boardId: board['id'],
                        patchData: {
                          'name': nameController.text.trim(),
                          'grade': gradeController.text.trim(),
                          'branch': branchController.text.trim(),
                          'is_active': isActive,
                        },
                      );
                      if (dialogCtx.mounted) {
                        _showModernSnackbar('Tahta güncellendi.', isSuccess: true, bgColor: successGreen);
                        Navigator.pop(dialogCtx);
                      }
                    } else {
                      final pairingData = await _client.from('board_pairings').select().eq('pairing_code', cleanPairingCode).eq('status', 'pending').maybeSingle();
                      if (pairingData == null) {
                        setDialogState(() => isSaving = false);
                        _showModernSnackbar('Geçersiz veya süresi dolmuş kod!', isSuccess: false, bgColor: dangerRed);
                        return;
                      }
                      final offlineSecret = _generateOfflineSecret();
                      final boardResponse = await _client.from('boards').insert({
                        'school_id': _schoolId,
                        'name': nameController.text.trim(),
                        'grade': gradeController.text.trim(),
                        'branch': branchController.text.trim(),
                        'is_active': isActive,
                        'is_unlocked': false,
                        'offline_secret': offlineSecret,
                      }).select().single();
                      await _client.from('board_pairings').update({
                        'board_id': boardResponse['id'],
                        'offline_secret': offlineSecret,
                        'status': 'completed',
                      }).eq('pairing_code', cleanPairingCode);
                      if (dialogCtx.mounted) {
                        _showModernSnackbar('Tahta eşleştirildi!', isSuccess: true, bgColor: successGreen);
                        Navigator.pop(dialogCtx);
                      }
                    }
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Güncelle' : 'Eşleştir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Profil Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0D9488), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName ?? 'Yönetici',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Okul Müdürü',
                                style: TextStyle(
                                  color: Color(0xFF0D9488),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _schoolName ?? '',
                                style: const TextStyle(fontSize: 12, color: textGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Kurumsal Lisans Kartı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isSchoolLicensed && _remainingLicenseDays > 0
                    ? successGreen.withValues(alpha: 0.08)
                    : dangerRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSchoolLicensed && _remainingLicenseDays > 0
                      ? successGreen.withValues(alpha: 0.3)
                      : dangerRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _isSchoolLicensed && _remainingLicenseDays > 0
                        ? successGreen.withValues(alpha: 0.15)
                        : dangerRed.withValues(alpha: 0.15),
                    child: Icon(
                      _isSchoolLicensed && _remainingLicenseDays > 0
                          ? Icons.verified_user_rounded
                          : Icons.gpp_bad_rounded,
                      color: _isSchoolLicensed && _remainingLicenseDays > 0
                          ? successGreen
                          : dangerRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSchoolLicensed && _remainingLicenseDays > 0
                              ? 'Kurumsal Lisans: Aktif'
                              : 'Lisans Süresi Sona Erdi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isSchoolLicensed && _remainingLicenseDays > 0
                                ? successGreen
                                : dangerRed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isSchoolLicensed && _remainingLicenseDays > 0
                              ? '$_remainingLicenseDays gün kaldı • Bitiş: ${_formatDateTr(_licenseExpiresAt)}'
                              : 'Lisans doldu. Destek: emrecanardc.dev@gmail.com',
                          style: const TextStyle(fontSize: 11, color: textGrey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isSchoolLicensed && _remainingLicenseDays > 0
                          ? successGreen
                          : dangerRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isSchoolLicensed && _remainingLicenseDays > 0
                          ? '$_remainingLicenseDays GÜN'
                          : 'SÜRE BİTTİ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Seçenekler
            _buildSettingsActionItem(
              icon: Icons.verified_user_rounded,
              iconColor: _isSchoolLicensed && _remainingLicenseDays > 0 ? successGreen : dangerRed,
              title: 'Kurumsal Lisans Detayları',
              subtitle: _isSchoolLicensed && _remainingLicenseDays > 0
                  ? 'Kalan gün ve lisans sözleşme bilgilerini inceleyin'
                  : 'Lisans doldu - Yenileme ve iletişim bilgileri',
              onTap: () {
                Navigator.pop(ctx);
                _showLicenseDetailsModal(context);
              },
            ),
            _buildSettingsActionItem(
              icon: Icons.group_rounded,
              iconColor: primaryBlue,
              title: 'Öğretmen Yetkilendirme',
              subtitle: 'Öğretmen hesaplarını onayla veya yönet',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTeachersScreen()));
              },
            ),
            _buildSettingsActionItem(
              icon: Icons.bug_report_rounded,
              iconColor: dangerRed,
              title: 'Sorun / Arıza Bildir',
              subtitle: 'Geliştirici & Teknik Destek Ekibine arıza kaydı gönder',
              onTap: () {
                Navigator.pop(ctx);
                ReportIssueDialog.show(
                  context,
                  schoolId: _schoolId ?? '',
                  userRole: 'school_admin',
                  userName: _adminName ?? 'Kurum Yöneticisi',
                );
              },
            ),
            _buildSettingsActionItem(
              icon: Icons.lightbulb_rounded,
              iconColor: warningOrange,
              title: 'Kurum Yöneticisi Rehberi & İpuçları',
              subtitle: 'Toplu kilit, kademe ve eşleştirme yöntemleri',
              onTap: () {
                Navigator.pop(ctx);
                TutorialTipsDialog.show(context, userRole: 'school_admin');
              },
            ),
            const Divider(height: 16),
            _buildSettingsActionItem(
              icon: Icons.logout_rounded,
              iconColor: dangerRed,
              title: 'Çıkış Yap',
              subtitle: 'Kurum yöneticisi oturumunu güvenle sonlandır',
              textColor: dangerRed,
              onTap: () async {
                Navigator.pop(ctx);
                await _client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? textDark,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGrey),
      onTap: onTap,
    );
  }

  String _formatDateTr(DateTime? date) {
    if (date == null) return '-';
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showLicenseDetailsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _isSchoolLicensed && _remainingLicenseDays > 0 ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
              color: _isSchoolLicensed && _remainingLicenseDays > 0 ? successGreen : dangerRed,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text(
              'Kurumsal Lisans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_schoolName ?? 'Kurum Adı', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Lisans Durumu: ', style: TextStyle(fontSize: 12, color: textGrey)),
                      Text(
                        _isSchoolLicensed && _remainingLicenseDays > 0 ? 'Aktif' : 'Süresi Doldu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isSchoolLicensed && _remainingLicenseDays > 0 ? successGreen : dangerRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Kalan Süre: ', style: TextStyle(fontSize: 12, color: textGrey)),
                      Text(
                        _isSchoolLicensed && _remainingLicenseDays > 0 ? '$_remainingLicenseDays Gün' : '0 Gün',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Bitiş Tarihi: ', style: TextStyle(fontSize: 12, color: textGrey)),
                      Text(
                        _formatDateTr(_licenseExpiresAt),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lisans Yenileme & Destek:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lisans sürenizi uzatmak veya yeni akıllı tahta lisansı tanımlamak için Teknik Destek Ekibi ile iletişime geçebilirsiniz.',
              style: TextStyle(fontSize: 11, color: textGrey, height: 1.3),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'emrecanardc.dev@gmail.com'));
                _showModernSnackbar('Destek e-posta adresi panoya kopyalandı.', isSuccess: true, bgColor: textDark);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: primaryBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'emrecanardc.dev@gmail.com',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                      ),
                    ),
                    Icon(Icons.copy_rounded, size: 14, color: primaryBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold, color: textGrey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));

    final visibleGrades = _getFilteredGradesForCurrentKademe();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgLight,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _schoolName ?? 'Yükleniyor...',
            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_rounded, color: dangerRed),
            tooltip: 'Tümünü Kilitle',
            onPressed: _lockAllBoards,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: textGrey),
            tooltip: 'İpuçları & Rehber',
            onPressed: () => TutorialTipsDialog.show(context, userRole: 'school_admin'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: textGrey),
            tooltip: 'Ayarlar ve Yönetim',
            onPressed: () => _showSettingsSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isSchoolLicensed) _buildLicenseWarningBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba $_adminName,', style: const TextStyle(color: textGrey, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Kurum Yönetim Paneli', style: TextStyle(color: primaryBlue, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),

          // --- 1. SEVİYE: KADEME SEÇİCİ ÇUBUĞU ---
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _kademeOptions.map((kademe) {
                final isSelected = _selectedKademe == kademe;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(kademe, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : textDark, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    selectedColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? primaryBlue : Colors.grey.shade300),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedKademe = kademe;
                        _selectedGrade = 'Tümü';
                      });
                      _fetchBoards(refresh: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // --- 2. SEVİYE: 1-12 SINIF SEÇİCİ ÇUBUĞU ---
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: visibleGrades.map((grade) {
                final isSelected = _selectedGrade == grade;
                final displayText = grade == 'Tümü' ? 'Tüm Sınıflar' : (grade == 'Diğer' ? 'Diğer' : '$grade. Sınıf');

                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(displayText, style: TextStyle(fontSize: 11, color: isSelected ? primaryBlue : textGrey, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    selectedColor: primaryBlue.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? primaryBlue : Colors.grey.shade200),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedGrade = grade;
                      });
                      _fetchBoards(refresh: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: _boards.isEmpty && !_isLoadingMore
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: textGrey),
                        const SizedBox(height: 12),
                        const Text('Kriterlere uygun tahta bulunamadı.', style: TextStyle(color: textGrey, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (_selectedGrade != 'Tümü' || _selectedKademe != 'Tümü')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedGrade = 'Tümü';
                                _selectedKademe = 'Tümü';
                              });
                              _fetchBoards(refresh: true);
                            },
                            child: const Text('Filtreleri Sıfırla'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: primaryBlue,
                    backgroundColor: Colors.white,
                    onRefresh: () => _fetchBoards(refresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _boards.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _boards.length) {
                          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: primaryBlue)));
                        }

                        final board = _boards[index];
                        final isUnlocked = board['is_unlocked'] ?? false;
                        final isActive = board['is_active'] ?? true;
                        final lastUnlockedBy = board['last_unlocked_by'] ?? '-';
                        final lastLockedBy = board['last_locked_by'] ?? '-';
                        final gradeText = board['grade'] != null && board['grade'].toString().isNotEmpty ? "${board['grade']}. Sınıf " : "";
                        final branchText = board['branch'] != null && board['branch'].toString().isNotEmpty ? board['branch'] : "";

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 1)),
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: isUnlocked ? successGreen.withValues(alpha: 0.15) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                                            child: Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded, color: isUnlocked ? successGreen : textGrey, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(board['name'] ?? 'İsimsiz Tahta', style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                                                if (gradeText.isNotEmpty || branchText.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text('$gradeText$branchText'.trim(), style: const TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: textGrey),
                                          tooltip: 'Düzenle',
                                          onPressed: () => _showAddEditBoardDialog(board: board),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.link_off_rounded, color: dangerRed),
                                          tooltip: 'Eşleşmeyi Kaldır',
                                          onPressed: () => _unpairBoard(board['id'], board['name'] ?? 'Tahta'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isUnlocked ? 'Son Açan: $lastUnlockedBy' : 'Son Kilitleyen: $lastLockedBy', style: const TextStyle(color: textGrey, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? successGreen : dangerRed, shape: BoxShape.circle)),
                                            const SizedBox(width: 6),
                                            Text(isActive ? 'Sistemde Aktif' : 'Pasife Alındı', style: TextStyle(color: isActive ? successGreen : dangerRed, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isUnlocked ? dangerRed : successGreen,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        elevation: 0,
                                      ),
                                      icon: Icon(isUnlocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 18, color: Colors.white),
                                      label: Text(isUnlocked ? 'Kilitle' : 'Aç', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      onPressed: () => _toggleBoardLock(board['id'], isUnlocked),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Yeni Tahta Eşle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditBoardDialog(),
      ),
    );
  }

  Widget _buildLicenseWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dangerRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dangerRed.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.gpp_bad_rounded, color: dangerRed, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurum Lisansı Sona Ermiştir',
                  style: TextStyle(
                    color: dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Akıllı tahtalar açık tutulmaktadır; kilit kontrolü duraklatılmıştır.\nLisans yenileme için: emrecanardc.dev@gmail.com',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OtpInputBoxes extends StatefulWidget {
  final Function(String) onCodeChanged;
  const OtpInputBoxes({super.key, required this.onCodeChanged});
  @override
  State<OtpInputBoxes> createState() => _OtpInputBoxesState();
}

class _OtpInputBoxesState extends State<OtpInputBoxes> {
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length > 1) {
      for (int i = 0; i < 6 && (index + i) < 6 && i < clean.length; i++) {
        _controllers[index + i].text = clean[i];
      }
      int nextIndex = index + clean.length;
      if (nextIndex >= 6) {
        _focusNodes[5].unfocus();
      } else {
        _focusNodes[nextIndex].requestFocus();
      }
      String fullCode = _controllers.map((e) => e.text).join();
      widget.onCodeChanged(fullCode);
      return;
    }

    if (clean.isNotEmpty) {
      _controllers[index].text = clean;
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      _controllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    String fullCode = _controllers.map((e) => e.text).join();
    widget.onCodeChanged(fullCode);
  }

  Widget _buildBox(int index) {
    return SizedBox(
      width: 35,
      height: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 2)),
        ),
        onChanged: (value) => _onChanged(value, index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBox(0),
        _buildBox(1),
        _buildBox(2),
        const Text('-', style: TextStyle(fontSize: 24, color: textGrey, fontWeight: FontWeight.w900)),
        _buildBox(3),
        _buildBox(4),
        _buildBox(5),
      ],
    );
  }
}