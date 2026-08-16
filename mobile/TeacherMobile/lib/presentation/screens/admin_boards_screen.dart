import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_teachers_screen.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
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
  String? _schoolId;
  String? _schoolName;
  String? _adminName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
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
        if (schoolData != null) {
          _schoolName = schoolData['name'];
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshBoards() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 800));
  }

  String _generateOfflineSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _unpairBoard(String boardId, String boardName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: dangerRed, size: 28),
            SizedBox(width: 12),
            Text('Dikkat', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('$boardName adlı tahtanın eşleşmesini kalıcı olarak kaldırmak istediğinize emin misiniz?', style: const TextStyle(color: textGrey, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('boards').delete().eq('id', boardId);
      if (!mounted) return;
      _showModernSnackbar('$boardName eşleşmesi kaldırıldı.', isSuccess: true, bgColor: textDark);
    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
  }

  Future<void> _lockAllBoards() async {
    if (_schoolId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tümünü Kilitle', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        content: const Text('Okuldaki tüm akıllı tahtaları kitlemek istediğinize emin misiniz?', style: TextStyle(color: textGrey, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hepsini Kilitle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _client.from('boards').update({
        'is_unlocked': false,
        'last_locked_by': _adminName 
      }).eq('school_id', _schoolId!);

      if (!mounted) return;
      _showModernSnackbar('Tüm tahtalara kilitlenme emri gönderildi.', isSuccess: true, bgColor: textDark);
    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
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
      
      if (!mounted) return;
      _showModernSnackbar(
        !currentStatus ? 'Tahta kullanıma açıldı.' : 'Tahta başarıyla kilitlendi.', 
        isSuccess: true, 
        bgColor: !currentStatus ? successGreen : textDark
      );
    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
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
        elevation: 6,
      )
    );
  }

  Future<void> _showAddBoardDialog() async {
    final nameController = TextEditingController();
    String pairingCode = ""; 
    bool isAdding = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            // YENİ: Pencere daha geniş olsun diye sağdan soldan boşlukları daralttık
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Yeni Tahta Eşleştir', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
            content: SizedBox(
              // YENİ: İçeriğin ekrana tam oturması için genişlik verdik
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Sınıf/Tahta Adı',
                      labelStyle: const TextStyle(color: textGrey),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('6 Haneli Kod', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  OtpInputBoxes(
                    onCodeChanged: (code) {
                      pairingCode = code;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isAdding ? null : () async {
                  if (nameController.text.trim().isEmpty || pairingCode.length != 6) {
                    _showModernSnackbar('Lütfen sınıf adını ve 6 haneli kodu eksiksiz girin.', isSuccess: false, bgColor: warningOrange);
                    return;
                  }
                  setDialogState(() => isAdding = true);
                  await _pairAndCreateBoard(nameController.text.trim(), pairingCode);
                  if (mounted) Navigator.pop(context);
                },
                child: isAdding 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _pairAndCreateBoard(String boardName, String pairingCode) async {
    if (_schoolId == null) return;
    try {
      final pairingData = await _client.from('board_pairings').select().eq('pairing_code', pairingCode).eq('status', 'pending').maybeSingle();
      if (pairingData == null) {
        if (!mounted) return;
        _showModernSnackbar('Geçersiz veya süresi dolmuş kod!', isSuccess: false, bgColor: dangerRed);
        return;
      }
      final offlineSecret = _generateOfflineSecret();
      final boardResponse = await _client.from('boards').insert({
        'school_id': _schoolId, 'name': boardName, 'is_unlocked': false, 'auto_lock_minutes': 15, 'offline_secret': offlineSecret,
      }).select().single();
      
      final newBoardId = boardResponse['id'];
      await _client.from('board_pairings').update({
        'board_id': newBoardId, 'offline_secret': offlineSecret, 'status': 'completed',
      }).eq('pairing_code', pairingCode);

      if (!mounted) return;
      _showModernSnackbar('$boardName sınıfı başarıyla eşleştirildi!', isSuccess: true, bgColor: successGreen);
    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));

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
            icon: const Icon(Icons.shield_rounded, color: textDark),
            tooltip: 'Tümünü Kilitle',
            onPressed: _lockAllBoards,
          ),
          IconButton(
            icon: const Icon(Icons.group_rounded, color: primaryBlue),
            tooltip: 'Öğretmenler',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTeachersScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: dangerRed),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await _client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba $_adminName,', style: const TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Tahta Kontrol Paneli', style: TextStyle(color: primaryBlue, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _client.from('boards').stream(primaryKey: ['id']).eq('school_id', _schoolId!),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: textDark)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryBlue));
                
                final boards = snapshot.data!;
                
                if (boards.isEmpty) {
                  return RefreshIndicator(
                    color: primaryBlue,
                    backgroundColor: Colors.white,
                    onRefresh: _refreshBoards,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        const Icon(Icons.space_dashboard_rounded, size: 80, color: textGrey),
                        const SizedBox(height: 16),
                        const Center(child: Text('Henüz hiç tahta eklenmemiş.\nSağ alttaki butondan eşleştirme yapabilirsiniz.', textAlign: TextAlign.center, style: TextStyle(color: textGrey, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryBlue,
                  backgroundColor: Colors.white,
                  onRefresh: _refreshBoards,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), 
                    padding: const EdgeInsets.only(bottom: 100), 
                    itemCount: boards.length,
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final isUnlocked = board['is_unlocked'] ?? false;
                      final lastUnlockedBy = board['last_unlocked_by'] ?? '-';
                      final lastLockedBy = board['last_locked_by'] ?? '-';
                      
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
                        ),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isUnlocked ? successGreen.withOpacity(0.15) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(isUnlocked ? Icons.wifi_tethering_rounded : Icons.desktop_windows_rounded, 
                                          color: isUnlocked ? successGreen : textGrey, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(board['name'], style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: textGrey),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    color: Colors.white,
                                    onSelected: (value) {
                                      if (value == 'unpair') _unpairBoard(board['id'], board['name']);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'unpair',
                                        child: Row(
                                          children: [
                                            Icon(Icons.link_off_rounded, color: dangerRed, size: 20),
                                            SizedBox(width: 12),
                                            Text('Eşleşmeyi Kaldır', style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                              ),
                              
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isUnlocked ? successGreen.withOpacity(0.1) : textDark.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isUnlocked ? 'EĞİTİME AÇIK' : 'KİLİTLİ',
                                      style: TextStyle(color: isUnlocked ? successGreen : textGrey, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                                    ),
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
                                width: double.infinity,
                                height: 52, 
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUnlocked ? textDark : successGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: Icon(isUnlocked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 24),
                                  label: Text(
                                    isUnlocked ? 'Tahtayı Kilitle' : 'Kilidi Aç',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                  onPressed: () => _toggleBoardLock(board['id'], isUnlocked),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBoardDialog,
        backgroundColor: primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        label: const Text('Yeni Tahta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

// --- YENİLENMİŞ 6 KUTUCUKLU ŞİFRE (OTP) WIDGET'I ---
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
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus(); 
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  // YENİ: Rakamların sıkışmasını önleyen ortalanmış kutu yapısı
  Widget _buildBox(int index) {
    return SizedBox(
      width: 35, // Kutu genişliği biraz artırıldı
      height: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center, // Yazıyı dikeyde merkeze alır
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "", 
          contentPadding: EdgeInsets.zero, // YENİ: Padding sıfırlanarak sıkışma engellendi
          filled: true,
          fillColor: Colors.grey.shade50,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
        ),
        onChanged: (value) => _onChanged(value, index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Kutuları eşit aralıklarla yayar
      children: [
        _buildBox(0),
        _buildBox(1),
        _buildBox(2),
        // YENİ: Araya şık bir tire eklendi
        const Text('-', style: TextStyle(fontSize: 24, color: textGrey, fontWeight: FontWeight.w900)),
        _buildBox(3),
        _buildBox(4),
        _buildBox(5),
      ],
    );
  }
}