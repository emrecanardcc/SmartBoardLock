import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/totp_service.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz
const Color cardColor = Color(0xFFFFFFFF);    // Saf Beyaz 
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz 
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz 
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi 
const Color warningOrange = Color(0xFFF59E0B); // Kehribar (Dikkat / İnternet Yok)

class TotpScreen extends StatefulWidget {
  // YENİ: Artık test verisi yerine, bu ekrana gelirken bilgileri dinamik olarak alacağız.
  final String boardId;
  final String offlineSecret;
  final String boardName;

  const TotpScreen({
    super.key,
    required this.boardId,
    required this.offlineSecret,
    required this.boardName,
  });

  @override
  State<TotpScreen> createState() => _TotpScreenState();
}

class _TotpScreenState extends State<TotpScreen> {
  String _currentCode = "Yükleniyor...";
  int _remainingSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateCode();
    _startTimer();
  }

  void _updateCode() {
    if (!mounted) return;
    
    setState(() {
      _currentCode = TotpService.generateCode(
        // YENİ: Dinamik parametreler kullanılıyor
        boardId: widget.boardId,
        offlineSecret: widget.offlineSecret,
        time: DateTime.now().toUtc(), // C# ile aynı evrensel saati baz alıyoruz
      );
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        // Bir sonraki dakikaya kaç saniye kaldığını hesapla
        _remainingSeconds = 60 - DateTime.now().second;
      });

      // Saniye 0 olduğunda (yeni dakikaya girildiğinde) şifreyi otomatik yenile
      if (DateTime.now().second == 0) {
        _updateCode();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text('${widget.boardName} - Acil Durum', style: const TextStyle(color: textDark, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- MODERN WİFİ YOK İKONU ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: warningOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 64,
                  color: warningOrange,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'İnternet Bağlantısı Yoksa',
                style: TextStyle(
                  color: textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              
              const Text(
                'Tahtadaki tuş takımını kullanarak aşağıdaki 6 haneli şifreyi girin. Bu şifre güvenlik amacıyla her dakika otomatik olarak yenilenir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 48),
              
              // --- DEVASA MODERN ŞİFRE GÖSTERİM KARTI ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryBlue.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(color: primaryBlue.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8)),
                  ]
                ),
                child: Text(
                  _currentCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                    letterSpacing: 12,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // --- MODERN KALAN SÜRE SAYACI ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100), // Kapsül (Pill) görünümü
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ]
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _remainingSeconds / 60,
                        color: warningOrange,
                        backgroundColor: Colors.grey.shade200,
                        strokeWidth: 3.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Yeni şifreye $_remainingSeconds saniye kaldı',
                      style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}