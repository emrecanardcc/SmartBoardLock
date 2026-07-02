import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_teachers_screen.dart';

class AdminBoardsScreen extends StatefulWidget {
  const AdminBoardsScreen({super.key});

  @override
  State<AdminBoardsScreen> createState() => _AdminBoardsScreenState();
}

class _AdminBoardsScreenState extends State<AdminBoardsScreen> {
  final _client = Supabase.instance.client;
  String? _schoolId;
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

      final profile = await _client.from('user_profiles').select('school_id').eq('id', user.id).single();
      
      setState(() {
        _schoolId = profile['school_id'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateOfflineSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // YENİ: 6 Haneli kodun girileceği pencere
  Future<void> _showAddBoardDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    bool isAdding = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Tahta Eşleştir', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Sınıf/Tahta Adı (Örn: 7-A)', 
                    labelStyle: TextStyle(color: Colors.grey)
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Tahtadaki 6 Haneli Kod', 
                    labelStyle: TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 0)
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isAdding ? null : () async {
                  if (nameController.text.trim().isEmpty || codeController.text.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen alanları eksiksiz doldurun.'), backgroundColor: Colors.orange));
                    return;
                  }
                  
                  setDialogState(() => isAdding = true);
                  await _pairAndCreateBoard(nameController.text.trim(), codeController.text.trim());
                  
                  if (mounted) Navigator.pop(context); // İşlem bitince pencereyi kapat
                },
                child: isAdding 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Eşleştir ve Kaydet', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // YENİ: Supabase ile konuşan ve eşleşmeyi sağlayan asıl fonksiyon
  Future<void> _pairAndCreateBoard(String boardName, String pairingCode) async {
    if (_schoolId == null) return;

    try {
      // 1. Bu 6 haneli kod veritabanında gerçekten 'pending' (bekliyor) durumunda var mı?
      final pairingData = await _client
          .from('board_pairings')
          .select()
          .eq('pairing_code', pairingCode)
          .eq('status', 'pending')
          .maybeSingle();

      if (pairingData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata: Geçersiz veya süresi dolmuş kod! Lütfen tahtadaki yeni kodu girin.'), backgroundColor: Colors.red));
        return;
      }

      // 2. Kod doğruysa Tahta için yeni bir şifre (tuz) üret
      final offlineSecret = _generateOfflineSecret();

      // 3. Tahtayı asıl 'boards' tablomuza kaydet
      final boardResponse = await _client.from('boards').insert({
        'school_id': _schoolId,
        'name': boardName,
        'is_unlocked': false,
        'auto_lock_minutes': 15,
        'offline_secret': offlineSecret,
      }).select().single();

      final newBoardId = boardResponse['id'];

      // 4. SİHİR BURADA: board_pairings tablosundaki o 6 haneli satıra UPDATE atıyoruz.
      // C# uygulaması bunu canlı dinlediği için bu verileri gördüğü an kendini kuracak!
      await _client.from('board_pairings').update({
        'board_id': newBoardId,
        'offline_secret': offlineSecret,
        'status': 'completed',
      }).eq('pairing_code', pairingCode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$boardName sınıfı başarıyla eşleştirildi!'), backgroundColor: Colors.green));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.green)));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Okul Tahta Yönetimi'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt, color: Colors.blueAccent),
            tooltip: 'Öğretmenler',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminTeachersScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await _client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _client.from('boards').stream(primaryKey: ['id']).eq('school_id', _schoolId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
          
          final boards = snapshot.data!;
          if (boards.isEmpty) return const Center(child: Text('Henüz hiç tahta eklenmemiş.', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: boards.length,
            itemBuilder: (context, index) {
              final board = boards[index];
              final isUnlocked = board['is_unlocked'] ?? false;
              
              return Card(
                color: Colors.grey[850],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(isUnlocked ? Icons.lock_open : Icons.lock, color: isUnlocked ? Colors.green : Colors.red),
                  title: Text(board['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Eşleşti ve Aktif', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBoardDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add_link, color: Colors.white),
        label: const Text('Tahta Eşleştir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}