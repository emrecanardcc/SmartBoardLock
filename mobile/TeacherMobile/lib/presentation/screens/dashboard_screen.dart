import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'board_control_screen.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz
const Color cardColor = Color(0xFFFFFFFF);    // Saf Beyaz 
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz 
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz 
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi 
const Color successGreen = Color(0xFF10B981); // Zümrüt Yeşili 
const Color dangerRed = Color(0xFFF43F5E);    // Gül Kırmızısı 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
  String? _schoolName;
  String? _teacherName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Öğretmenin okul id'sini ve adını kendi profilinden çekiyoruz
      final profile = await _client
          .from('user_profiles')
          .select('school_id, full_name')
          .eq('id', user.id)
          .single();
      
      _schoolId = profile['school_id'];
      _teacherName = profile['full_name'] ?? 'Öğretmenim';

      // Okulun adını okullar tablosundan çekiyoruz
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

  // Aşağı Kaydırarak Yenileme
  Future<void> _refreshBoards() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // --- HESAP SİLME UYARI PENCERESİ (APPLE ONAYI İÇİN KRİTİK) ---
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF), // cardColor
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)), // warningOrange
              SizedBox(width: 8),
              Text(
                "Hesap Silme",
                style: TextStyle(
                  color: Color(0xFF0F172A), // textDark
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            "Hesabınız ve yetkileriniz okul yönetimi tarafından kurumsal ağ üzerinden oluşturulmuştur.\n\nHesabınızı ve size ait tüm verileri kalıcı olarak silmek için lütfen okulunuzun bilgi işlem (IT) veya yönetim birimi ile iletişime geçin.",
            style: TextStyle(
              color: Color(0xFF64748B), // textGrey
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Anladım",
                style: TextStyle(
                  color: Color(0xFF3B82F6), // primaryBlue
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgLight, 
        body: Center(child: CircularProgressIndicator(color: primaryBlue))
      );
    }

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
          // YENİ: Hesap ayarları menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: textGrey),
            tooltip: 'Ayarlar',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'delete') {
                _showDeleteAccountDialog(context);
              } else if (value == 'logout') {
                await _client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginScreen()), 
                  (route) => false
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: dangerRed, size: 20),
                    SizedBox(width: 8),
                    Text('Hesabımı Sil', style: TextStyle(color: dangerRed, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: textGrey, size: 20),
                    SizedBox(width: 8),
                    Text('Çıkış Yap', style: TextStyle(color: textDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _schoolId == null 
        ? const Center(child: Text('Okul bilginiz bulunamadı.', style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Şık Karşılama Alanı
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Merhaba $_teacherName,', style: const TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Derslikler', style: TextStyle(color: primaryBlue, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  // Öğretmenin okulundaki tüm tahtaları getir
                  stream: _client.from('boards').stream(primaryKey: ['id']).eq('school_id', _schoolId!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: dangerRed)));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: primaryBlue));
                    }
                    
                    final boards = snapshot.data!;
                    
                    // Boş Liste Durumu (Empty State)
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
                            const Center(child: Text('Okulunuzda henüz aktif tahta bulunmuyor.', style: TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      );
                    }

                    // Tahtalar Listesi
                    return RefreshIndicator(
                      color: primaryBlue,
                      backgroundColor: Colors.white,
                      onRefresh: _refreshBoards,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: boards.length,
                        itemBuilder: (context, index) {
                          final board = boards[index];
                          final isUnlocked = board['is_unlocked'] ?? false;
                          final lastUnlockedBy = board['last_unlocked_by'] ?? '-';
                          final lastLockedBy = board['last_locked_by'] ?? '-';
                          
                          // --- YEPYENİ UX ODAKLI ÖĞRETMEN KART TASARIMI ---
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
                            ),
                            color: cardColor,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BoardControlScreen(
                                      boardId: board['id'],
                                      boardName: board['name'] ?? 'İsimsiz Tahta',
                                      offlineSecret: board['offline_secret'] ?? 'ŞİFRE_YOK',
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Durum İkonu (Tahta Açık / Kapalı)
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: isUnlocked ? successGreen.withOpacity(0.1) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        isUnlocked ? Icons.smart_display_rounded : Icons.tv_off_rounded, 
                                        color: isUnlocked ? successGreen : textGrey, 
                                        size: 28
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Tahta Bilgileri
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            board['name'] ?? 'İsimsiz Tahta', 
                                            style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)
                                          ),
                                          const SizedBox(height: 6),
                                          
                                          // Durum Metni (Badge tarzı vurgu)
                                          Text(
                                            isUnlocked ? 'Durum: EĞİTİME AÇIK' : 'Durum: KİLİTLİ', 
                                            style: TextStyle(
                                              color: isUnlocked ? successGreen : textGrey, 
                                              fontWeight: FontWeight.w800, 
                                              fontSize: 12,
                                              letterSpacing: 0.5
                                            )
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          // Loglar (Öğretmenler görsün diye eklendi)
                                          Text('Son İşlem: ${isUnlocked ? lastUnlockedBy : lastLockedBy}', style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    
                                    // İleri Oku
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.chevron_right_rounded, color: primaryBlue, size: 24),
                                    ),
                                  ],
                                ),
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
    );
  }
}