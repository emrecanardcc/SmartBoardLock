import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/totp_service.dart';
import 'qr_scanner_screen.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      
const Color cardColor = Color(0xFFFFFFFF);    
const Color textDark = Color(0xFF0F172A);     
const Color textGrey = Color(0xFF64748B);     
const Color primaryBlue = Color(0xFF3B82F6);  
const Color successGreen = Color(0xFF10B981); 
const Color dangerRed = Color(0xFFF43F5E);    

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
  
  bool _isOfflineModeVisible = false;
  final TextEditingController _challengeController = TextEditingController();
  String _generatedPin = '';
  String? _adminName; 

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _client.from('user_profiles').select('full_name').eq('id', user.id).single();
        _adminName = profile['full_name'];
      }
    } catch (_) {}
  }

  void _calculateOfflinePin(String challenge) {
    if (challenge.length == 4) {
      setState(() {
        _generatedPin = TotpService.generateResponse(
          offlineSecret: widget.offlineSecret,
          challengeCode: challenge,
        );
      });
    } else {
      if (_generatedPin.isNotEmpty) {
        setState(() => _generatedPin = '');
      }
    }
  }

  Future<void> _lockBoard() async {
    try {
      await _client.from('boards').update({
        'is_unlocked': false,
        'last_locked_by': _adminName ?? 'Öğretmen/Yetkili'
      }).eq('id', widget.boardId);
      
      if (mounted) {
        _showModernSnackbar('Tahta başarıyla kilitlendi.', isSuccess: true, bgColor: textDark);
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackbar('Hata: $e', isSuccess: false, bgColor: dangerRed);
      }
    }
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
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text(widget.boardName, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5)),
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
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
                const Spacer(),

                // --- DİNAMİK VE MODERN DURUM İKONU ---
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: isUnlocked ? successGreen.withOpacity(0.1) : textDark.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnlocked ? Icons.smart_display_rounded : Icons.tv_off_rounded, 
                      size: 80, 
                      color: isUnlocked ? successGreen : textGrey,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  isUnlocked ? 'EĞİTİME AÇIK' : 'TAHTA KİLİTLİ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isUnlocked ? successGreen : textDark, 
                    fontSize: 26, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  isUnlocked 
                    ? 'Bu tahta şu anda öğrenciler ve öğretmenler tarafından kullanılabilir durumda.' 
                    : 'Tahta güvenlik amacıyla kilitlenmiştir. Açmak için QR kodu okutabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textGrey, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
                ),
                
                const Spacer(),

                // --- ÇEVRİMDİŞİ ŞİFRE ÜRETİM ALANI ---
                if (_isOfflineModeVisible) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryBlue.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(color: primaryBlue.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                      ]
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, color: primaryBlue, size: 20),
                            SizedBox(width: 8),
                            Text('İnternetsiz Kilit Açma', style: TextStyle(color: textGrey, fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _challengeController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '0000',
                            hintStyle: TextStyle(color: textGrey.withOpacity(0.3), letterSpacing: 8),
                            labelText: 'Tahtadaki 4 Haneli Kodu Girin',
                            floatingLabelAlignment: FloatingLabelAlignment.center,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: primaryBlue, width: 2),
                            ),
                          ),
                          onChanged: _calculateOfflinePin,
                        ),
                        if (_generatedPin.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('GİRİLECEK ŞİFRE', style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          SelectableText(
                            _generatedPin,
                            style: const TextStyle(color: primaryBlue, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 12),
                            textAlign: TextAlign.center,
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- ŞİFRE GÖSTER/GİZLE BUTONU ---
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isOfflineModeVisible = !_isOfflineModeVisible;
                      if (!_isOfflineModeVisible) {
                        _challengeController.clear();
                        _generatedPin = '';
                      }
                    });
                  },
                  icon: Icon(_isOfflineModeVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textGrey),
                  label: Text(
                    _isOfflineModeVisible ? 'Çevrimdışı Paneli Gizle' : 'İnternet Yoksa Buraya Tıklayın',
                    style: const TextStyle(color: textGrey, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                
                const SizedBox(height: 16),

                // --- DEVASA DİNAMİK ANA AKSİYON BUTONU ---
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isUnlocked) {
                        _lockBoard();
                      } else {
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
                      backgroundColor: isUnlocked ? textDark : primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: Icon(isUnlocked ? Icons.lock_rounded : Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                    label: Text(
                      isUnlocked ? 'Tahtayı Kilitle' : 'QR Okutarak Kilidi Aç', 
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}