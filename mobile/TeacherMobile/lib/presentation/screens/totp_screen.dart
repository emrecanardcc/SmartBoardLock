import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/totp_service.dart';

class TotpScreen extends StatefulWidget {
  const TotpScreen({super.key});

  @override
  State<TotpScreen> createState() => _TotpScreenState();
}

class _TotpScreenState extends State<TotpScreen> {
  String _currentCode = "Yükleniyor...";
  int _remainingSeconds = 60;
  Timer? _timer;

  // C# ile BİREBİR aynı olan test verilerimizi kullanıyoruz.
  // Not: Sistemin tam bittiğinde bunları veritabanından dinamik çekeceğiz.
  final String _boardId = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
  final String _offlineSecret = "TAHTA_OZEL_GIZLI_TUZ_12345";

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
        boardId: _boardId,
        offlineSecret: _offlineSecret,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Acil Durum Şifresi'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.signal_wifi_off,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Text(
                'İnternet Bağlantısı Yoksa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tahtadaki tuş takımını kullanarak aşağıdaki 6 haneli şifreyi girin. Bu şifre her dakika otomatik olarak yenilenir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // ŞİFRE GÖSTERİM KUTUSU
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _currentCode,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    letterSpacing: 8,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // KALAN SÜRE SAYACI
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: _remainingSeconds / 60,
                      color: Colors.orange,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Yeni şifreye $_remainingSeconds saniye kaldı',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}