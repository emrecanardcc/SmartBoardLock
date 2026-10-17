import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'board_control_screen.dart';
import '../widgets/report_issue_dialog.dart';
import '../widgets/tutorial_tips_dialog.dart';

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
  final String? initialSchoolId;
  final String? initialSchoolName;

  const DashboardScreen({
    super.key,
    this.initialSchoolId,
    this.initialSchoolName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _boardChannel;
  RealtimeChannel? _schoolChannel;

  String? _schoolId;
  String? _schoolName;
  String? _teacherName;
  bool _isLoadingProfile = true;
  bool _isSchoolLicensed = true;

  // Sayfalama (Lazy Loading) ve Filtreleme Değişkenleri
  final List<Map<String, dynamic>> _boards = [];
  final int _limit = 6;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<String> _favoriteIds = [];
  bool _showFavoritesOnly = true; // YENİ: Öğretmen girdiğinde ilk olarak favoriler gösterilir

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
    if (_boardChannel != null) {
      _client.removeChannel(_boardChannel!);
    }
    if (_schoolChannel != null) {
      _client.removeChannel(_schoolChannel!);
    }
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

  Future<void> _loadTeacherData() async {
    try {
      if (widget.initialSchoolId != null) {
        _schoolId = widget.initialSchoolId;
        _schoolName = widget.initialSchoolName ?? 'Örnek Okul';
        _teacherName = 'Öğretmenim';
      }

      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _client.from('user_profiles').select('school_id, full_name').eq('id', user.id).single();
        _schoolId = profile['school_id'];
        _teacherName = profile['full_name'] ?? 'Öğretmenim';

        if (_schoolId != null) {
          final schoolData = await _client.from('schools').select('name, is_licensed, license_expires_at').eq('id', _schoolId!).maybeSingle();
          _schoolName = schoolData?['name'];
          _isSchoolLicensed = _evalLicense(schoolData);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
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

  Future<void> _fetchBoards({bool refresh = false}) async {
    if (refresh) {
      _boards.clear();
      _hasMore = true;
    }
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      var query = _client.from('boards').select().eq('school_id', _schoolId!).eq('is_active', true);

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
    if (_schoolId == null) return;

    _boardChannel = _client.channel('public:boards:$_schoolId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'boards',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'school_id',
        value: _schoolId!,
      ),
      callback: (payload) {
        final updatedBoard = payload.newRecord;
        final index = _boards.indexWhere((b) => b['id'] == updatedBoard['id']);
        if (index != -1) {
          setState(() {
            _boards[index] = updatedBoard;
          });
        }
      },
    ).subscribe();

    if (_schoolId != null) {
      _schoolChannel = _client.channel('public:schools:$_schoolId').onPostgresChanges(
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
            });
          }
        },
      ).subscribe();
    }
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
                    backgroundColor: primaryBlue.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_rounded, color: primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _teacherName ?? 'Öğretmen',
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
                                color: primaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Öğretmen',
                                style: TextStyle(
                                  color: primaryBlue,
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
            const SizedBox(height: 16),

            // Seçenekler
            _buildSettingsActionItem(
              icon: Icons.bug_report_rounded,
              iconColor: dangerRed,
              title: 'Sorun / Arıza Bildir',
              subtitle: 'Kilit veya tahta sorunlarını teknik ekibe iletin',
              onTap: () {
                Navigator.pop(ctx);
                ReportIssueDialog.show(
                  context,
                  schoolId: _schoolId ?? '',
                  userRole: 'teacher',
                  userName: _teacherName ?? 'Öğretmen',
                );
              },
            ),
            _buildSettingsActionItem(
              icon: Icons.lightbulb_rounded,
              iconColor: warningOrange,
              title: 'Kullanım Rehberi & İpuçları',
              subtitle: 'QR okutma, TOTP kodu ve filtreler hakkında bilgi',
              onTap: () {
                Navigator.pop(ctx);
                TutorialTipsDialog.show(context, userRole: 'teacher');
              },
            ),
            _buildSettingsActionItem(
              icon: Icons.security_rounded,
              iconColor: textGrey,
              title: 'Hesap Güvenliği',
              subtitle: 'Kurumsal hesap durumu ve silme politikası',
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteAccountDialog(context);
              },
            ),
            const Divider(height: 16),
            _buildSettingsActionItem(
              icon: Icons.logout_rounded,
              iconColor: dangerRed,
              title: 'Çıkış Yap',
              subtitle: 'Oturumu sonlandır ve giriş ekranına dön',
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));
    }

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
            icon: const Icon(Icons.help_outline_rounded, color: textGrey),
            tooltip: 'İpuçları & Rehber',
            onPressed: () => TutorialTipsDialog.show(context, userRole: 'teacher'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: textGrey),
            tooltip: 'Ayarlar ve Profil',
            onPressed: () => _showSettingsSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _schoolId == null
          ? const Center(child: Text('Okul bilginiz bulunamadı.', style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isSchoolLicensed) _buildLicenseWarningBanner(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Merhaba $_teacherName,', style: const TextStyle(color: textGrey, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text('Derslikler', style: TextStyle(color: primaryBlue, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          const SizedBox(width: 10),
                          if (_showFavoritesOnly)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: warningOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: warningOrange.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: warningOrange),
                                  SizedBox(width: 4),
                                  Text('Favorilerim', style: TextStyle(color: warningOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 1. SEVİYE: KADEME VE FAVORİLER ÇUBUĞU ---
                SizedBox(
                  height: 44,
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
                            Icon(Icons.star_rounded, size: 16, color: _showFavoritesOnly ? warningOrange : textGrey),
                            const SizedBox(width: 6),
                            Text('Favoriler', style: TextStyle(color: _showFavoritesOnly ? textDark : textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: warningOrange.withValues(alpha: 0.2),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _showFavoritesOnly ? warningOrange : Colors.grey.shade300),
                        ),
                        onSelected: (val) {
                          setState(() => _showFavoritesOnly = val);
                          _fetchBoards(refresh: true);
                        },
                      ),

                      // Araya İnce Bir Ayırıcı Çizgi
                      Container(
                        width: 2,
                        height: 24,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),

                      // Kademe Çipleri (İlkokul, Ortaokul, Lise, Diğer)
                      ..._kademeOptions.map((kademe) {
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
                      }),
                    ],
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

                // --- TAHTALAR LİSTESİ ---
                Expanded(
                  child: _showFavoritesOnly && _favoriteIds.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: warningOrange.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_outline_rounded, size: 52, color: warningOrange),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Henüz Favori Derslik Yok',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sık ders verdiğiniz sınıfların yıldızına basarak favorilere ekleyin. Uygulamayı her açtığınızda doğrudan bu sınıflar listelenir.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: textGrey, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.visibility_rounded, size: 18),
                                  label: const Text('Tüm Sınıfları Göster', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    setState(() => _showFavoritesOnly = false);
                                    _fetchBoards(refresh: true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      : _boards.isEmpty && !_isLoadingMore
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 48, color: textGrey),
                                  const SizedBox(height: 12),
                                  const Text('Kriterlere uygun tahta bulunamadı.', style: TextStyle(color: textGrey, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  if (_selectedGrade != 'Tümü' || _selectedKademe != 'Tümü' || _showFavoritesOnly)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedGrade = 'Tümü';
                                          _selectedKademe = 'Tümü';
                                          _showFavoritesOnly = false;
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
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isFav ? warningOrange.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.2),
                                        width: isFav ? 1.5 : 1,
                                      ),
                                    ),
                                    color: cardColor,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BoardControlScreen(
                                              boardId: board['id'],
                                              boardName: board['name'] ?? 'İsimsiz Tahta',
                                              offlineSecret: board['offline_secret'] ?? 'ŞİFRE_YOK',
                                              isSchoolLicensed: _isSchoolLicensed,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: isUnlocked ? successGreen.withValues(alpha: 0.12) : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                isUnlocked ? Icons.smart_display_rounded : Icons.tv_off_rounded,
                                                color: isUnlocked ? successGreen : textGrey,
                                                size: 26,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    board['name'] ?? 'İsimsiz Tahta',
                                                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.3),
                                                  ),
                                                  if (gradeText.isNotEmpty || branchText.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        '$gradeText$branchText'.trim(),
                                                        style: const TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isUnlocked ? 'Durum: EĞİTİME AÇIK' : 'Durum: KİLİTLİ',
                                                    style: TextStyle(
                                                      color: isUnlocked ? successGreen : textGrey,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                                color: isFav ? warningOrange : Colors.grey.shade300,
                                                size: 26,
                                              ),
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

  Widget _buildLicenseWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                  'Okul Lisansı Sona Ermiştir',
                  style: TextStyle(
                    color: dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Akıllı tahtalar açık tutulmaktadır; kilit kontrolü duraklatılmıştır.\nLisans yenileme: emrecanardc.dev@gmail.com',
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