import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/totp_service.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      
const Color cardColor = Color(0xFFFFFFFF);    
const Color textDark = Color(0xFF0F172A);     
const Color textGrey = Color(0xFF64748B);     
const Color primaryBlue = Color(0xFF3B82F6);  
const Color warningOrange = Color(0xFFF59E0B); 
const Color successGreen = Color(0xFF10B981);

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
  final FocusNode _challengeFocusNode = FocusNode();
  String _generatedPin = "";

  @override
  void dispose() {
    _challengeController.dispose();
    _challengeFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _challengeFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _calculatePin(String challenge) {
    final cleanChallenge = challenge.trim();
    if (cleanChallenge.length == 4) {
      // 4 hane tamamlandığında klavyeyi otomatik kapat (şifre perdelenmesin)
      _dismissKeyboard();

      setState(() {
        _generatedPin = TotpService.generateResponse(
          offlineSecret: widget.offlineSecret,
          challengeCode: cleanChallenge,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: Scaffold(
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- MODERN WİFİ YOK İKONU ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: warningOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 64,
                    color: warningOrange,
                  ),
                ),
                const SizedBox(height: 24),
                
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
                const SizedBox(height: 28),
                
                // --- KOD GİRİŞ ALANI ---
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: TextField(
                    controller: _challengeController,
                    focusNode: _challengeFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12, color: textDark),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '0000',
                      hintStyle: TextStyle(color: textGrey.withValues(alpha: 0.3), letterSpacing: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      suffixIcon: _challengeController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Klavyeyi Kapat',
                              icon: const Icon(Icons.keyboard_hide_rounded, color: textGrey),
                              onPressed: _dismissKeyboard,
                            )
                          : null,
                    ),
                    onChanged: _calculatePin,
                  ),
                ),
                
                const SizedBox(height: 12),

                // --- MANUEL KLAVYEYİ KAPAT BUTONU ---
                TextButton.icon(
                  onPressed: _dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_rounded, size: 20, color: textGrey),
                  label: const Text(
                    'Klavyeyi Kapat / Kodu Göster',
                    style: TextStyle(color: textGrey, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 24),
                
                // --- DEVASA MODERN ŞİFRE GÖSTERİM KARTI ---
                if (_generatedPin.isNotEmpty) ...[
                  const Text('GİRİLECEK ŞİFRE (TAHTAYA YAZIN)', style: TextStyle(color: successGreen, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(color: primaryBlue.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
                      ]
                    ),
                    child: Column(
                      children: [
                        SelectableText(
                          _generatedPin,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: primaryBlue,
                            letterSpacing: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bu 6 haneli kodu akıllı tahta ekranındaki tuşlarla giriniz.',
                          style: TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}