import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz
const Color cardColor = Color(0xFFFFFFFF);    // Saf Beyaz 
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz 
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz 
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi 
const Color successGreen = Color(0xFF10B981); // Zümrüt Yeşili 
const Color warningOrange = Color(0xFFF59E0B); // Kehribar 
const Color dangerRed = Color(0xFFF43F5E);    // Gül Kırmızısı 

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
  bool _isLoading = true;

  late final SupabaseClient _adminClient;
  final String _supabaseUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  final String _serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mjk4Nzg4NCwiZXhwIjoyMDk4NTYzODg0fQ.Pe4I_qm_qr3HfGNoPFTbbEoQbP1ZD0-KOVZfpI1OJ8c';

  @override
  void initState() {
    super.initState();
    _adminClient = SupabaseClient(_supabaseUrl, _serviceRoleKey);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final profile = await _client.from('user_profiles').select('school_id').eq('id', user.id).single();
      
      setState(() {
        _schoolId = profile['school_id'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- YENİ: Aşağı Kaydırınca Yenileme ---
  Future<void> _refreshTeachers() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // --- YENİ: Modern Snackbar ---
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

  // --- MODERN DİYALOG: Yeni Öğretmen Ekleme ---
  Future<void> _showAddTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdding = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Yeni Öğretmen Ekle', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      labelStyle: const TextStyle(color: textGrey),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-Posta Adresi',
                      labelStyle: const TextStyle(color: textGrey),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Şifre (En az 6 hane)',
                      labelStyle: const TextStyle(color: textGrey),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
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
                  if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.length < 6) {
                    _showModernSnackbar('Lütfen tüm alanları geçerli şekilde doldurun.', isSuccess: false, bgColor: warningOrange);
                    return;
                  }
                  
                  setDialogState(() => isAdding = true);
                  
                  try {
                    final response = await _adminClient.auth.admin.createUser(
                      AdminUserAttributes(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        emailConfirm: true, 
                      )
                    );

                    final newUserId = response.user!.id;

                    await _adminClient.from('user_profiles').insert({
                      'id': newUserId,
                      'school_id': _schoolId,
                      'role': 'teacher',
                      'full_name': nameController.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      _showModernSnackbar('${nameController.text} başarıyla eklendi!', isSuccess: true, bgColor: successGreen);
                    }
                  } catch (e) {
                    setDialogState(() => isAdding = false);
                    _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
                  }
                },
                child: isAdding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- MODERN DİYALOG: Öğretmen Silme ---
  Future<void> _deleteTeacher(String teacherId, String teacherName) async {
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
        content: Text('$teacherName adlı öğretmenin sisteme erişimi kalıcı olarak silinecek. Emin misiniz?', style: const TextStyle(color: textGrey, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('İptal', style: TextStyle(color: textGrey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminClient.auth.admin.deleteUser(teacherId);
        if (mounted) _showModernSnackbar('$teacherName sistemden silindi.', isSuccess: true, bgColor: textDark);
      } catch (e) {
        if (mounted) _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
      }
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
        iconTheme: const IconThemeData(color: textDark), // Geri butonu rengi
        title: const Text('Öğretmenler', style: TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text('Okuldaki yetkili öğretmen kadrosunu buradan yönetebilirsiniz.', style: TextStyle(color: textGrey, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminClient.from('user_profiles').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: dangerRed)));
                }

                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryBlue));
                
                final teachers = snapshot.data!
                    .where((user) => user['school_id'] == _schoolId && user['role'] == 'teacher')
                    .toList();

                if (teachers.isEmpty) {
                  return RefreshIndicator(
                    color: primaryBlue,
                    backgroundColor: Colors.white,
                    onRefresh: _refreshTeachers,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        const Icon(Icons.people_outline_rounded, size: 80, color: textGrey),
                        const SizedBox(height: 16),
                        const Center(child: Text('Henüz kadroya öğretmen eklenmemiş.\nSağ alttaki butondan ekleme yapabilirsiniz.', textAlign: TextAlign.center, style: TextStyle(color: textGrey, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryBlue,
                  backgroundColor: Colors.white,
                  onRefresh: _refreshTeachers,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100), 
                    itemCount: teachers.length,
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      
                      // --- YEPYENİ UX ODAKLI ÖĞRETMEN KART TASARIMI ---
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
                        ),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.person_rounded, color: primaryBlue, size: 28),
                            ),
                            title: Text(teacher['full_name'] ?? 'İsimsiz', style: const TextStyle(color: textDark, fontWeight: FontWeight.w800, fontSize: 18)),
                            subtitle: const Text('Yetki: Öğretmen', style: TextStyle(color: textGrey, fontWeight: FontWeight.w500, fontSize: 13)),
                            // Tehlikeli silme işlemi gizli Popup menüye taşındı
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: textGrey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: Colors.white,
                              onSelected: (value) {
                                if (value == 'delete') _deleteTeacher(teacher['id'], teacher['full_name'] ?? 'İsimsiz');
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_remove_rounded, color: dangerRed, size: 20),
                                      SizedBox(width: 12),
                                      Text('Sistemden Sil', style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        backgroundColor: primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
        label: const Text('Öğretmen Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}