import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_teachers_screen.dart';

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

  String? _schoolId;
  String? _schoolName;
  String? _adminName;
  bool _isLoadingProfile = true;

  // Sayfalama (Lazy Loading) ve Filtreleme
  final List<Map<String, dynamic>> _boards = [];
  final int _limit = 6;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _selectedGrade = 'Tümü';
  final List<String> _gradeOptions = ['Tümü', '9', '10', '11', '12', 'Diğer'];

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
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadAdminData();
    if (_schoolId != null) {
      await _fetchBoards(refresh: true);
      _setupRealtime();
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final profile = await _client.from('user_profiles').select('school_id, full_name').eq('id', user.id).single();
      _schoolId = profile['school_id'];
      _adminName = profile['full_name'] ?? 'Yönetici';

      if (_schoolId != null) {
        final schoolData = await _client.from('schools').select('name').eq('id', _schoolId!).maybeSingle();
        _schoolName = schoolData?['name'];
      }
    } catch (_) {}
    setState(() => _isLoadingProfile = false);
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

      if (_selectedGrade != 'Tümü') {
        query = query.eq('grade', _selectedGrade);
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
    _boardChannel = _client.channel('admin_realtime').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'boards',
      callback: (payload) {
        setState(() {
          if (payload.eventType == PostgresChangeEvent.insert) {
            if (payload.newRecord['school_id'] == _schoolId) _boards.insert(0, payload.newRecord);
          } else if (payload.eventType == PostgresChangeEvent.update) {
            final idx = _boards.indexWhere((b) => b['id'] == payload.newRecord['id']);
            if (idx != -1) _boards[idx] = payload.newRecord;
          } else if (payload.eventType == PostgresChangeEvent.delete) {
            _boards.removeWhere((b) => b['id'] == payload.oldRecord['id']);
          }
        });
      }
    ).subscribe();
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
      )
    );
  }

  Future<void> _toggleBoardLock(String boardId, bool currentStatus) async {
    try {
      final updateData = <String, dynamic>{'is_unlocked': !currentStatus};
      if (!currentStatus) {
        updateData['last_unlocked_by'] = _adminName;
      } else {
        updateData['last_locked_by'] = _adminName; 
      }
      await _client.from('boards').update(updateData).eq('id', boardId);
    } catch (e) {
      _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
  }

  Future<void> _lockAllBoards() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tümünü Kilitle', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        content: const Text('Okuldaki tüm akıllı tahtaları kilitmek istediğinize emin misiniz?'),
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
      await _client.from('boards').update({'is_unlocked': false, 'last_locked_by': _adminName}).eq('school_id', _schoolId!);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                      decoration: InputDecoration(labelText: 'Görünen Ad (Örn: Sınıf 1)', enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2))),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: gradeController, decoration: InputDecoration(labelText: 'Sınıf (Örn: 11)', enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2))))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: branchController, decoration: InputDecoration(labelText: 'Şube (Örn: A)', enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2))))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: isActive ? successGreen.withOpacity(0.1) : dangerRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: isActive ? successGreen.withOpacity(0.3) : dangerRed.withOpacity(0.3))),
                      child: SwitchListTile(
                        value: isActive,
                        onChanged: (val) => setDialogState(() => isActive = val),
                        title: Text('Durum: ${isActive ? 'Aktif' : 'Pasif'}', style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? successGreen : dangerRed)),
                        activeColor: successGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 24),
                      const Text('6 Haneli Kod', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      OtpInputBoxes(onCodeChanged: (code) => pairingCode = code),
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSaving ? null : () async {
                  if (nameController.text.trim().isEmpty || (!isEditing && pairingCode.length != 6)) {
                    _showModernSnackbar('Lütfen zorunlu alanları doldurun.', isSuccess: false, bgColor: warningOrange);
                    return;
                  }
                  setDialogState(() => isSaving = true);
                  
                  try {
                    if (isEditing) {
                      await _client.from('boards').update({
                        'name': nameController.text.trim(), 'grade': gradeController.text.trim(), 'branch': branchController.text.trim(), 'is_active': isActive
                      }).eq('id', board['id']);
                      if (mounted) {
                        _showModernSnackbar('Tahta güncellendi.', isSuccess: true, bgColor: successGreen);
                        Navigator.pop(context);
                      }
                    } else {
                      final pairingData = await _client.from('board_pairings').select().eq('pairing_code', pairingCode).eq('status', 'pending').maybeSingle();
                      if (pairingData == null) {
                        setDialogState(() => isSaving = false);
                        _showModernSnackbar('Geçersiz veya süresi dolmuş kod!', isSuccess: false, bgColor: dangerRed);
                        return;
                      }
                      final offlineSecret = _generateOfflineSecret();
                      final boardResponse = await _client.from('boards').insert({
                        'school_id': _schoolId, 'name': nameController.text.trim(), 'grade': gradeController.text.trim(), 'branch': branchController.text.trim(), 'is_active': isActive, 'is_unlocked': false, 'auto_lock_minutes': 15, 'offline_secret': offlineSecret,
                      }).select().single();
                      await _client.from('board_pairings').update({'board_id': boardResponse['id'], 'offline_secret': offlineSecret, 'status': 'completed'}).eq('pairing_code', pairingCode);
                      if (mounted) {
                        _showModernSnackbar('Tahta eşleştirildi!', isSuccess: true, bgColor: successGreen);
                        Navigator.pop(context);
                      }
                    }
                  } catch (e) {
                    setDialogState(() => isSaving = false);
                    _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
                  }
                },
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isEditing ? 'Güncelle' : 'Eşleştir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgLight,
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(_schoolName ?? 'Yükleniyor...', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5))),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.shield_rounded, color: textDark), tooltip: 'Tümünü Kilitle', onPressed: _lockAllBoards),
          IconButton(icon: const Icon(Icons.group_rounded, color: primaryBlue), tooltip: 'Öğretmenler', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTeachersScreen()))),
          IconButton(icon: const Icon(Icons.logout_rounded, color: dangerRed), tooltip: 'Çıkış Yap', onPressed: () async {
            await _client.auth.signOut();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba $_adminName,', style: const TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Yönetim Paneli', style: TextStyle(color: primaryBlue, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),

          // --- YATAY SINIF FİLTRESİ ---
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _gradeOptions.map((grade) {
                final isSelected = _selectedGrade == grade;
                final displayText = grade == 'Tümü' ? 'Tüm Sınıflar' : (grade == 'Diğer' ? 'Diğer' : '$grade. Sınıf');
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(displayText),
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() => _selectedGrade = grade);
                      _fetchBoards(refresh: true);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: primaryBlue.withOpacity(0.15),
                    labelStyle: TextStyle(color: isSelected ? primaryBlue : textGrey, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? primaryBlue : Colors.grey.shade300)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: _boards.isEmpty && !_isLoadingMore
              ? const Center(child: Text('Kriterlere uygun tahta bulunamadı.', style: TextStyle(color: textGrey, fontWeight: FontWeight.w600)))
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1)),
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
                                          decoration: BoxDecoration(color: isUnlocked ? successGreen.withOpacity(0.15) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                                          child: Icon(isUnlocked ? Icons.wifi_tethering_rounded : Icons.desktop_windows_rounded, color: isUnlocked ? successGreen : textGrey, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(board['name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                                              if (gradeText.isNotEmpty || branchText.isNotEmpty)
                                                Text('$gradeText$branchText', style: const TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: textGrey),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    color: Colors.white,
                                    onSelected: (value) {
                                      if (value == 'edit') _showAddEditBoardDialog(board: board);
                                      if (value == 'unpair') _unpairBoard(board['id'], board['name']);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: primaryBlue, size: 20), SizedBox(width: 12), Text('Düzenle', style: TextStyle(color: textDark, fontWeight: FontWeight.bold))])),
                                      const PopupMenuItem(value: 'unpair', child: Row(children: [Icon(Icons.link_off_rounded, color: dangerRed, size: 20), SizedBox(width: 12), Text('Eşleşmeyi Kaldır', style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold))])),
                                    ],
                                  ),
                                ],
                              ),
                              
                              const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                              
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: isUnlocked ? successGreen.withOpacity(0.1) : textDark.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                        child: Text(isUnlocked ? 'AÇIK' : 'KİLİTLİ', style: TextStyle(color: isUnlocked ? successGreen : textGrey, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: isActive ? primaryBlue.withOpacity(0.1) : dangerRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text(isActive ? 'AKTİF' : 'PASİF', style: TextStyle(color: isActive ? primaryBlue : dangerRed, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Açan: $lastUnlockedBy', style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('Kapatan: $lastLockedBy', style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              SizedBox(
                                width: double.infinity, height: 52, 
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !isActive ? Colors.grey.shade300 : (isUnlocked ? textDark : successGreen),
                                    foregroundColor: !isActive ? textGrey : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: Icon(!isActive ? Icons.block_rounded : (isUnlocked ? Icons.lock_rounded : Icons.lock_open_rounded), size: 24),
                                  label: Text(
                                    !isActive ? 'Tahta Pasif Durumda' : (isUnlocked ? 'Tahtayı Kilitle' : 'Kilidi Aç'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                  onPressed: !isActive ? null : () => _toggleBoardLock(board['id'], isUnlocked),
                                ),
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
        onPressed: () => _showAddEditBoardDialog(),
        backgroundColor: primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        label: const Text('Yeni Tahta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

// --- OTP KUTUCUKLARI WIDGET'I ---
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
    for (var node in _focusNodes) node.dispose();
    for (var controller in _controllers) controller.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    String fullCode = _controllers.map((e) => e.text).join();
    widget.onCodeChanged(fullCode);
    if (value.isNotEmpty) {
      if (index < 5) _focusNodes[index + 1].requestFocus();
      else _focusNodes[index].unfocus(); 
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
  }

  Widget _buildBox(int index) {
    return SizedBox(
      width: 35, height: 52,
      child: TextField(
        controller: _controllers[index], focusNode: _focusNodes[index],
        textAlign: TextAlign.center, textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number, maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "", contentPadding: EdgeInsets.zero, filled: true, fillColor: Colors.grey.shade50,
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
        _buildBox(0), _buildBox(1), _buildBox(2),
        const Text('-', style: TextStyle(fontSize: 24, color: textGrey, fontWeight: FontWeight.w900)),
        _buildBox(3), _buildBox(4), _buildBox(5),
      ],
    );
  }
}