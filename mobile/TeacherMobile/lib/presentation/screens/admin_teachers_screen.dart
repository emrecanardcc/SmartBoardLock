import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
  bool _isLoading = true;

  // DİKKAT: Buraya Supabase panelindeki 'service_role' (secret) anahtarını yapıştır!
  // Normal URL'ni de url kısmına yaz.
  late final SupabaseClient _adminClient;
  final String _supabaseUrl = 'https://clkasnbpmhddhstoixdz.supabase.co';
  final String _serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Mjk4Nzg4NCwiZXhwIjoyMDk4NTYzODg0fQ.Pe4I_qm_qr3HfGNoPFTbbEoQbP1ZD0-KOVZfpI1OJ8c';

  @override
  void initState() {
    super.initState();
    _adminClient = SupabaseClient(_supabaseUrl, _serviceRoleKey);
    _loadAdminData();
  }

  // Adminin okul bilgisini çek
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

  // Yeni Öğretmen Ekleme Modalı
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
            backgroundColor: Colors.grey[900],
            title: const Text('Yeni Öğretmen Ekle', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Ad Soyad', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-Posta', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Şifre (En az 6 hane)', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isAdding ? null : () async {
                  if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.length < 6) return;
                  
                  setDialogState(() => isAdding = true);
                  
                  try {
                    // 1. Master Key ile Admin API üzerinden kullanıcıyı oluştur (Oturum kapanmaz)
                    final response = await _adminClient.auth.admin.createUser(
                      AdminUserAttributes(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        emailConfirm: true, // Doğrulama beklemeden direkt onaylı aç
                      )
                    );

                    final newUserId = response.user!.id;

                    // 2. Oluşan kullanıcıyı okuluna 'teacher' rolüyle kaydet
                    await _adminClient.from('user_profiles').insert({
                      'id': newUserId,
                      'school_id': _schoolId,
                      'role': 'teacher',
                      'full_name': nameController.text.trim(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Öğretmen başarıyla eklendi!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setDialogState(() => isAdding = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                  }
                },
                child: isAdding ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                : const Text('Kaydet', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // Öğretmeni Sistemden Silme
  Future<void> _deleteTeacher(String teacherId, String teacherName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Öğretmeni Sil', style: TextStyle(color: Colors.redAccent)),
        content: Text('$teacherName adlı öğretmenin sisteme erişimi tamamen silinecek. Emin misiniz?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Master Key ile öğretmeni auth tablosundan tamamen sil (Cascade sayesinde profili de silinir)
        await _adminClient.auth.admin.deleteUser(teacherId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Öğretmen silindi.'), backgroundColor: Colors.redAccent));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.green)));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Öğretmen Yönetimi'), backgroundColor: Colors.grey[900]),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 1. _client yerine _adminClient kullanıyoruz (RLS duvarına takılmamak için)
        stream: _adminClient.from('user_profiles').stream(primaryKey: ['id']),
        builder: (context, snapshot) {
          // 2. Eğer arkada bir hata olursa sonsuz dönmek yerine hatayı ekrana bas
          if (snapshot.hasError) {
            return Center(
              child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
          
          // Dart tarafında kendi okulumuzun öğretmenlerini filtreliyoruz
          final teachers = snapshot.data!
              .where((user) => user['school_id'] == _schoolId && user['role'] == 'teacher')
              .toList();

          if (teachers.isEmpty) return const Center(child: Text('Henüz öğretmen eklenmemiş.', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return Card(
                color: Colors.grey[850],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(teacher['full_name'] ?? 'İsimsiz', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteTeacher(teacher['id'], teacher['full_name'] ?? 'İsimsiz'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Öğretmen Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}