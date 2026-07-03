import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'board_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
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

      // Öğretmenin hangi okula bağlı olduğunu kendi profilinden çekiyoruz
      final profile = await _client
          .from('user_profiles')
          .select('school_id')
          .eq('id', user.id)
          .single();
      
      setState(() {
        _schoolId = profile['school_id'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Colors.green))
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sınıflarım'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await _client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (context) => const LoginScreen()), 
                (route) => false
              );
            },
          ),
        ],
      ),
      body: _schoolId == null 
        ? const Center(child: Text('Okul bilginiz bulunamadı.', style: TextStyle(color: Colors.red)))
        : StreamBuilder<List<Map<String, dynamic>>>(
            // Öğretmenin okulundaki tüm tahtaları getir
            stream: _client.from('boards').stream(primaryKey: ['id']).eq('school_id', _schoolId!),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }
              
              final boards = snapshot.data!;
              if (boards.isEmpty) {
                return const Center(child: Text('Okulunuzda henüz aktif tahta bulunmuyor.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: boards.length,
                itemBuilder: (context, index) {
                  final board = boards[index];
                  final isUnlocked = board['is_unlocked'] ?? false;
                  
                  return Card(
                    color: Colors.grey[850],
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        isUnlocked ? Icons.lock_open : Icons.lock, 
                        color: isUnlocked ? Colors.green : Colors.red
                      ),
                      title: Text(
                        board['name'] ?? 'İsimsiz Tahta', 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      subtitle: Text(
                        isUnlocked ? 'Tahta Açık' : 'Tahta Kilitli', 
                        style: TextStyle(color: isUnlocked ? Colors.green : Colors.redAccent)
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                      onTap: () {
                        // Tahtaya tıklandığında o tahtanın özel kontrol ekranına git
                        // offlineSecret verisini eksiksiz bir şekilde yolluyoruz!
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
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}