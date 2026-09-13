import 'package:flutter/material.dart';
import '../../data/services/totp_service.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      
const Color cardColor = Color(0xFFFFFFFF);    
const Color textDark = Color(0xFF0F172A);     
const Color textGrey = Color(0xFF64748B);     
const Color primaryBlue = Color(0xFF3B82F6);  
const Color warningOrange = Color(0xFFF59E0B); 

class TotpScreen extends StatefulWidget {
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
  final TextEditingController _challengeController = TextEditingController();
  String _generatedPin = "";

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  void _calculatePin(String challenge) {
    if (challenge.length == 4) {
      setState(() {
        _generatedPin = TotpService.generateResponse(
          offlineSecret: widget.offlineSecret,
          challengeCode: challenge,
        );
      });
    } else {
      if (_generatedPin.isNotEmpty) {
        setState(() => _generatedPin = "");
      }
    }
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
                'Tahtadaki ekranda yazan 4 haneli çevrimdışı kilit açma kodunu aşağıya girerek 6 haneli şifrenizi oluşturabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGrey, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              
              // --- KOD GİRİŞ ALANI ---
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ]
                ),
                child: TextField(
                  controller: _challengeController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12, color: textDark),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0000',
                    hintStyle: TextStyle(color: textGrey.withOpacity(0.3), letterSpacing: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onChanged: _calculatePin,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // --- DEVASA MODERN ŞİFRE GÖSTERİM KARTI ---
              if (_generatedPin.isNotEmpty) ...[
                const Text('GİRİLECEK ŞİFRE', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
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
                  child: SelectableText(
                    _generatedPin,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                      letterSpacing: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}