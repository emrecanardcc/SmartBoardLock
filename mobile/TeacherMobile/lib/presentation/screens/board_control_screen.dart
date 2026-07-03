import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/totp_service.dart';
import 'qr_scanner_screen.dart';

class BoardControlScreen extends StatefulWidget {
  final String boardId;
  final String boardName;
  final String offlineSecret;

  const BoardControlScreen({
    super.key,
    required this.boardId,
    required this.boardName,
    required this.offlineSecret,
  });

  @override
  State<BoardControlScreen> createState() => _BoardControlScreenState();
}

class _BoardControlScreenState extends State<BoardControlScreen> {
  final _client = Supabase.instance.client;
  
  late Timer _timer;
  String _currentTotpCode = '';
  bool _isOfflineCodeVisible = false;

  @override
  void initState() {
    super.initState();
    _generateDynamicCode();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _generateDynamicCode());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _generateDynamicCode() {
    final newCode = TotpService.generateCode(
      boardId: widget.boardId,
      offlineSecret: widget.offlineSecret,
      time: DateTime.now().toUtc(),
    );
    if (mounted && _currentTotpCode != newCode) {
      setState(() => _currentTotpCode = newCode);
    }
  }

  // Tahtayı doğrudan kilitleme fonksiyonu
  Future<void> _lockBoard() async {
    try {
      await _client.from('boards').update({'is_unlocked': false}).eq('id', widget.boardId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.boardName),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _client.from('boards').stream(primaryKey: ['id']).eq('id', widget.boardId),
        builder: (context, snapshot) {
          bool isUnlocked = false;
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            isUnlocked = snapshot.data!.first['is_unlocked'] ?? false;
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isUnlocked ? Icons.lock_open : Icons.lock, 
                  size: 120, 
                  color: isUnlocked ? Colors.green : Colors.redAccent
                ),
                const SizedBox(height: 24),
                Text(
                  isUnlocked ? 'Tahta Şu An AÇIK' : 'Tahta Şu An KİLİTLİ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isUnlocked ? Colors.green : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 60),

                // DİNAMİK BUTON: Duruma göre değişir
                
                  // board_control_screen.dart içindeki QR butonunun onPressed kısmı:
// DİNAMİK BUTON: Duruma göre değişir
                ElevatedButton.icon(
                  onPressed: () {
                    if (isUnlocked) {
                      // Tahta açıksa doğrudan kilitle
                      _lockBoard();
                    } else {
                      // Tahta kilitliyse QR okutmaya gönder
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QrScannerScreen(
                            expectedBoardId: widget.boardId,
                            expectedOfflineSecret: widget.offlineSecret,
                            boardName: widget.boardName,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked ? Colors.redAccent : Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isUnlocked ? Icons.lock : Icons.qr_code_scanner, color: Colors.white, size: 28),
                  label: Text(
                    isUnlocked ? 'Tahtayı Kilitle' : 'QR ile Kilidi Aç', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
                
                const Spacer(),

                // GİZLENEBİLİR OFFLINE ŞİFRE
                TextButton(
                  onPressed: () => setState(() => _isOfflineCodeVisible = !_isOfflineCodeVisible),
                  child: Text(
                    _isOfflineCodeVisible ? 'Çevrimdışı Şifreyi Gizle' : 'Çevrimdışı Şifreyi Göster',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
                
                if (_isOfflineCodeVisible)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      children: [
                        const Text('Çevrimdışı Şifre', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          _currentTotpCode,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}