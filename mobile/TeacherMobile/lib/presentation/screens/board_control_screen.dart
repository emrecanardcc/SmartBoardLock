import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/totp_service.dart';


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

  @override
  void initState() {
    super.initState();
    _generateDynamicCode(); // İlk açıldığında kodu üret
    
    // Her 1 saniyede bir kontrol et (Dakika atladığında şifre otomatik değişsin diye)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _generateDynamicCode();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Ekrandan çıkınca sayacı durdur (Performans için)
    super.dispose();
  }

  // Senin yazdıgın TOTP fonksiyonunu çağırıp ekrandaki değişkeni günceller
  void _generateDynamicCode() {
    // Burada da UTC zamanı gönderiyoruz
    final newCode = TotpService.generateCode(
      boardId: widget.boardId,
      offlineSecret: widget.offlineSecret,
      time: DateTime.now().toUtc(), // .toUtc() ekledik!
    );
    // ... geri kalan aynı

    if (_currentTotpCode != newCode) {
      setState(() {
        _currentTotpCode = newCode;
      });
    }
  }

  Future<void> _toggleLockStatus(bool currentStatus) async {
    try {
      await _client
          .from('boards')
          .update({'is_unlocked': !currentStatus})
          .eq('id', widget.boardId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.boardName} Kontrolü'),
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
                  size: 100, 
                  color: isUnlocked ? Colors.green : Colors.redAccent
                ),
                const SizedBox(height: 24),
                Text(
                  widget.boardName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isUnlocked ? 'Tahta şu an AÇIK' : 'Tahta şu an KİLİTLİ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isUnlocked ? Colors.green : Colors.redAccent, fontSize: 18),
                ),
                const SizedBox(height: 48),
                
                // 1. MANUEL AÇ/KAPA BUTONU
                ElevatedButton.icon(
                  onPressed: () => _toggleLockStatus(isUnlocked),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked ? Colors.redAccent : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isUnlocked ? Icons.lock : Icons.lock_open, color: Colors.white),
                  label: Text(
                    isUnlocked ? 'Tahtayı Kilitle' : 'Kilidi Aç', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 16),

                // 2. QR BUTONU 
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR Okuyucu eklenecek!'), backgroundColor: Colors.orange),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: const Text('QR ile Bağlan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),

                // 3. CANLI TOTP ŞİFRESİ (Her dakika değişir)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Çevrimdışı Tahta Şifresi', 
                        style: TextStyle(color: Colors.grey, fontSize: 14)
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(İnternet koptuğunda tahtaya bu kodu girin)', 
                        style: TextStyle(color: Colors.redAccent, fontSize: 11)
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          SelectableText(
                            _currentTotpCode, // Üretilen 6 haneli dinamik şifre burada
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8)
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}