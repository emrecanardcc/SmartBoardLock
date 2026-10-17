import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

// --- RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);
const Color cardColor = Color(0xFFFFFFFF);
const Color textDark = Color(0xFF0F172A);
const Color textGrey = Color(0xFF64748B);
const Color primaryBlue = Color(0xFF3B82F6);
const Color successGreen = Color(0xFF10B981);
const Color warningOrange = Color(0xFFF59E0B);
const Color dangerRed = Color(0xFFF43F5E);

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
  String? _schoolName;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  SupabaseClient _getAdminClient() {
    String? url;
    String? key;
    try {
      if (dotenv.isInitialized) {
        url = dotenv.env['SUPABASE_URL'];
        key = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
      }
    } catch (_) {}
    url ??= SupabaseConfig.primaryUrl;
    key ??= SupabaseConfig.primaryKey;
    return SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _teachers = [];
  bool _hasError = false;

  Future<void> _loadAdminData() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _client.from('user_profiles').select('school_id').eq('id', user.id).single();
        _schoolId = profile['school_id'];

        if (_schoolId != null) {
          final schoolData = await _client.from('schools').select('name').eq('id', _schoolId!).maybeSingle();
          _schoolName = schoolData?['name'];
          await _loadTeachers();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeachers() async {
    if (_schoolId == null) return;
    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('school_id', _schoolId!)
          .eq('role', 'teacher')
          .order('full_name', ascending: true);
      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(data);
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _refreshTeachers() async {
    await _loadTeachers();
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
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'Ö';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // --- MODERN ALT ÇEKMECE: Yeni Öğretmen Ekleme ---
  Future<void> _showAddTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdding = false;
    bool obscurePassword = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(dialogCtx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yeni Öğretmen Yetkilendir',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                            ),
                            Text(
                              'Giriş bilgileriyle akıllı tahtaları açabilir',
                              style: TextStyle(fontSize: 12, color: textGrey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: textGrey),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Ad Soyad
                  const Text('Ad Soyad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Örn: Ahmet Yılmaz',
                      prefixIcon: const Icon(Icons.badge_rounded, color: primaryBlue, size: 20),
                      filled: true,
                      fillColor: bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // E-Posta
                  const Text('E-Posta Adresi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'ornek@meb.k12.tr',
                      prefixIcon: const Icon(Icons.email_rounded, color: primaryBlue, size: 20),
                      filled: true,
                      fillColor: bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Şifre
                  const Text('Geçici Giriş Şifresi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'En az 6 karakter',
                      prefixIcon: const Icon(Icons.lock_rounded, color: primaryBlue, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: textGrey,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                      filled: true,
                      fillColor: bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: isAdding
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        isAdding ? 'Kaydediliyor...' : 'Öğretmeni Kaydet ve Yetkilendir',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: isAdding
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final email = emailController.text.trim();
                              final pass = passwordController.text.trim();

                              if (name.isEmpty || email.isEmpty || pass.length < 6) {
                                _showModernSnackbar('Lütfen tüm alanları geçerli şekilde doldurun (şifre en az 6 hane).',
                                    isSuccess: false, bgColor: warningOrange);
                                return;
                              }

                              setDialogState(() => isAdding = true);

                              final adminClient = _getAdminClient();
                              try {
                                final response = await adminClient.auth.admin.createUser(
                                  AdminUserAttributes(
                                    email: email,
                                    password: pass,
                                    emailConfirm: true,
                                  ),
                                );

                                final newUserId = response.user!.id;

                                await adminClient.from('user_profiles').insert({
                                  'id': newUserId,
                                  'school_id': _schoolId,
                                  'role': 'teacher',
                                  'full_name': name,
                                });

                                await _loadTeachers();

                                if (dialogCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                  _showModernSnackbar('$name başarıyla kadroya eklendi!', isSuccess: true, bgColor: successGreen);
                                }
                              } catch (e) {
                                setDialogState(() => isAdding = false);
                                _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
                              } finally {
                                adminClient.dispose();
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MODERN DİYALOG: Öğretmen Silme ---
  Future<void> _deleteTeacher(String teacherId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: dangerRed, size: 28),
            SizedBox(width: 12),
            Text('Yetkiyi Kaldır', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$teacherName adlı öğretmenin kilit açma yetkisi ve hesabı kalıcı olarak silinecektir. Devam etmek istiyor musunuz?',
          style: const TextStyle(color: textGrey, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final adminClient = _getAdminClient();
      try {
        await adminClient.from('user_profiles').delete().eq('id', teacherId);
        await adminClient.auth.admin.deleteUser(teacherId);
        await _loadTeachers();
        if (mounted) _showModernSnackbar('$teacherName sistemden silindi.', isSuccess: true, bgColor: textDark);
      } catch (e) {
        if (mounted) _showModernSnackbar('Silme hatası: $e', isSuccess: false, bgColor: dangerRed);
      } finally {
        adminClient.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: bgLight, body: Center(child: CircularProgressIndicator(color: primaryBlue)));
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgLight,
        iconTheme: const IconThemeData(color: textDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Öğretmen Yetkilendirme',
              style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
            ),
            if (_schoolName != null)
              Text(
                _schoolName!,
                style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        centerTitle: false,
      ),
      body: Builder(
        builder: (context) {
          final allSchoolTeachers = _teachers;

          final filteredTeachers = allSchoolTeachers.where((teacher) {
            final name = (teacher['full_name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

          return RefreshIndicator(
            color: primaryBlue,
            backgroundColor: Colors.white,
            onRefresh: _refreshTeachers,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dangerRed.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: dangerRed, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sunucu bağlantısı sağlanamadı. Bilgiler çevrimdışı modda gösteriliyor.',
                              style: TextStyle(fontSize: 12, color: dangerRed, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // --- İSTATİSTİK KARTLARI ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.groups_rounded, color: primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${allSchoolTeachers.length}',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textDark),
                                    ),
                                    const Text('Yetkili Öğretmen', style: TextStyle(fontSize: 11, color: textGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: successGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.lock_open_rounded, color: successGreen, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aktif Kadro',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: successGreen),
                                    ),
                                    Text('Tam Yetkilendirildi', style: TextStyle(fontSize: 11, color: textGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- ARAMA ÇUBUĞU ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Öğretmen ara...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 22),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: textGrey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // --- ÖĞRETMENLER LİSTESİ ---
                if (allSchoolTeachers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, size: 60, color: primaryBlue),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Henüz Kadroya Öğretmen Eklenmemiş',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Aşağıdaki butona basarak öğretmenleri sisteme ekleyebilirsiniz.',
                            style: TextStyle(fontSize: 13, color: textGrey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('İlk Öğretmeni Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _showAddTeacherDialog,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (filteredTeachers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: textGrey),
                          const SizedBox(height: 12),
                          Text(
                            '"$_searchQuery" ile eşleşen öğretmen bulunamadı.',
                            style: const TextStyle(color: textGrey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredTeachers.map((teacher) {
                    final name = teacher['full_name'] ?? 'İsimsiz Öğretmen';
                    final initials = _getInitials(name);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Baş Harf Rozeti
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // İsim ve Yetki Rozeti
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: successGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: successGreen.withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 12, color: successGreen),
                                        SizedBox(width: 4),
                                        Text(
                                          'Kilit Açma Yetkili',
                                          style: TextStyle(
                                            color: successGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Silme Butonu
                            IconButton(
                              icon: const Icon(Icons.person_remove_rounded, color: dangerRed, size: 22),
                              tooltip: 'Yetkiyi Kaldır',
                              onPressed: () => _deleteTeacher(teacher['id'], name),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        backgroundColor: primaryBlue,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Öğretmen Ekle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}