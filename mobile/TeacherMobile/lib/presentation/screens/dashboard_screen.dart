import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'board_control_screen.dart';

// --- RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);
const Color cardColor = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF0F172A);
const Color textGrey = Color(0xFF64748B);
const Color primaryBlue = Color(0xFF3B82F6);
const Color successGreen = Color(0xFF10B981);
const Color dangerRed = Color(0xFFF43F5E);
const Color warningOrange = Color(0xFFF59E0B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _boardChannel;

  String? _schoolId;
  String? _schoolName;
  String? _teacherName;
  bool _isLoadingProfile = true;

  // Sayfalama (Lazy Loading) ve Filtreleme Değişkenleri
  final List<Map<String, dynamic>> _boards = [];
  final int _limit = 6;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<String> _favoriteIds = [];
  bool _showFavoritesOnly = false;
  
  // YENİ: Sınıf listesinden "Hazırlık" çıkarıldı, varsayılan "Tümü" yapıldı
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
    await _loadTeacherData();
    await _loadFavorites();
    if (_schoolId != null) {
      await _fetchBoards(refresh: true);
      _setupRealtime();
    }
  }

  Future<void> _loadTeacherData() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final profile = await _client.from('user_profiles').select('school_id, full_name').eq('id', user.id).single();
      _schoolId = profile['school_id'];
      _teacherName = profile['full_name'] ?? 'Öğretmenim';

      if (_schoolId != null) {
        final schoolData = await _client.from('schools').select('name').eq('id', _schoolId!).maybeSingle();
        _schoolName = schoolData?['name'];
      }
    } catch (_) {}
    setState(() => _isLoadingProfile = false);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds = prefs.getStringList('fav_boards') ?? [];
    });
  }

  Future<void> _toggleFavorite(String boardId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(boardId)) {
        _favoriteIds.remove(boardId);
      } else {
        _favoriteIds.add(boardId);
      }
      prefs.setStringList('fav_boards', _favoriteIds);
    });
  }

  Future<void> _fetchBoards({bool refresh = false}) async {
    if (refresh) {
      _boards.clear();
      _hasMore = true;
    }
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      var query = _client.from('boards').select().eq('school_id', _schoolId!).eq('is_active', true);

      if (_selectedGrade != 'Tümü') {
        query = query.eq('grade', _selectedGrade);
      }
      
      if (_showFavoritesOnly) {
        if (_favoriteIds.isEmpty) {
          setState(() {
            _boards.clear();
            _isLoadingMore = false;
            _hasMore = false;
          });
          return;
        }
        query = query.inFilter('id', _favoriteIds);
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

  void _setupRealtime() {
    _boardChannel = _client.channel('public:boards').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'boards',
      callback: (payload) {
        final updatedBoard = payload.newRecord;
        final index = _boards.indexWhere((b) => b['id'] == updatedBoard['id']);
        if (index != -1) {
          setState(() {
            _boards[index] = updatedBoard;
          });
        }
      }
    ).subscribe();
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: warningOrange),
            SizedBox(width: 8),
            Text("Hesap Silme", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Hesabınız ve yetkileriniz okul yönetimi tarafından kurumsal ağ üzerinden oluşturulmuştur.\n\nHesabınızı silmek için okulunuzun yönetim birimi ile iletişime geçin.",
          style: TextStyle(color: textGrey, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Anladım", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgLight,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_schoolName ?? 'Yükleniyor...', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
        ),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: textGrey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'delete') _showDeleteAccountDialog(context);
              if (value == 'logout') {
                await _client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever_rounded, color: dangerRed, size: 20), SizedBox(width: 8), Text('Hesabımı Sil', style: TextStyle(color: dangerRed, fontWeight: FontWeight.w600))])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, color: textGrey, size: 20), SizedBox(width: 8), Text('Çıkış Yap', style: TextStyle(color: textDark))])),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Merhaba $_teacherName,', style: const TextStyle(color: textGrey, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Derslikler', style: TextStyle(color: primaryBlue, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ],
                ),
              ),

              // --- YENİ YATAY FİLTRELEME ÇUBUĞU ---
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Favorilerim Çipi
                    FilterChip(
                      selected: _showFavoritesOnly,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 18, color: _showFavoritesOnly ? warningOrange : textGrey),
                          const SizedBox(width: 6),
                          Text('Favoriler', style: TextStyle(color: _showFavoritesOnly ? textDark : textGrey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: warningOrange.withOpacity(0.2),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _showFavoritesOnly ? warningOrange : Colors.grey.shade300)),
                      onSelected: (val) {
                        setState(() => _showFavoritesOnly = val);
                        _fetchBoards(refresh: true);
                      },
                    ),
                    
                    // Araya İnce Bir Ayırıcı Çizgi
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    
                    // Sınıf Çipleri
                    ..._gradeOptions.map((grade) {
                      final isSelected = _selectedGrade == grade;
                      final displayText = grade == 'Tümü' ? 'Tüm Sınıflar' : (grade == 'Diğer' ? 'Diğer' : '$grade. Sınıf');
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(displayText),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedGrade = grade;
                            });
                            _fetchBoards(refresh: true);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryBlue.withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryBlue : textGrey,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? primaryBlue : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- TAHTALAR LİSTESİ ---
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
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: _boards.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _boards.length) {
                            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: primaryBlue)));
                          }

                          final board = _boards[index];
                          final isUnlocked = board['is_unlocked'] ?? false;
                          final isFav = _favoriteIds.contains(board['id']);
                          final gradeText = board['grade'] != null && board['grade'].toString().isNotEmpty ? "${board['grade']}. Sınıf " : "";
                          final branchText = board['branch'] != null && board['branch'].toString().isNotEmpty ? board['branch'] : "";

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: isFav ? warningOrange.withOpacity(0.5) : Colors.grey.withOpacity(0.15), width: isFav ? 2 : 1),
                            ),
                            color: cardColor,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => BoardControlScreen(
                                    boardId: board['id'],
                                    boardName: board['name'] ?? 'İsimsiz Tahta',
                                    offlineSecret: board['offline_secret'] ?? 'ŞİFRE_YOK',
                                  ),
                                ));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(color: isUnlocked ? successGreen.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                                      child: Icon(isUnlocked ? Icons.smart_display_rounded : Icons.tv_off_rounded, color: isUnlocked ? successGreen : textGrey, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(board['name'] ?? 'İsimsiz Tahta', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
                                          if (gradeText.isNotEmpty || branchText.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text('$gradeText$branchText', style: const TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(isUnlocked ? 'Durum: EĞİTİME AÇIK' : 'Durum: KİLİTLİ', style: TextStyle(color: isUnlocked ? successGreen : textGrey, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded, color: isFav ? warningOrange : Colors.grey.shade300, size: 28),
                                      onPressed: () => _toggleFavorite(board['id']),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),
            ],
          ),
    );
  }
}