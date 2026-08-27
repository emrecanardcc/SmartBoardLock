import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // YENİ: URL başlatıcı eklendi
import 'auth_gate.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz
const Color cardColor = Color(0xFFFFFFFF);    // Saf Beyaz 
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz 
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz 
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi 
const Color warningOrange = Color(0xFFF59E0B); // Kehribar (Uyarılar)
const Color dangerRed = Color(0xFFF43F5E);    // Gül Kırmızısı (Hatalar)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false; // YENİ: Şifre göster/gizle özelliği eklendi

  // YENİ: Modern Snackbar
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
        duration: const Duration(seconds: 4),
        elevation: 6,
      )
    );
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showModernSnackbar('Lütfen e-posta ve şifrenizi eksiksiz girin.', isSuccess: false, bgColor: warningOrange);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthGate()));
    } on AuthException catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Giriş Başarısız: E-posta veya şifre hatalı.', isSuccess: false, bgColor: dangerRed);
    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar('Beklenmeyen bir hata oluştu: $e', isSuccess: false, bgColor: dangerRed);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight, // Ferah arduvaz arka plan
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // YENİ: Profesyonel İkon Tasarımı
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded, 
                    size: 80, 
                    color: primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Akıllı Tahta Sistemi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textDark, 
                  fontSize: 28, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5
                ),
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Yönetici & Öğretmen Girişi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textGrey, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 48),
              
              // --- MODERN E-POSTA ALANI ---
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'E-Posta Adresi',
                  labelStyle: const TextStyle(color: textGrey),
                  prefixIcon: const Icon(Icons.email_rounded, color: textGrey),
                  filled: true,
                  fillColor: cardColor,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: primaryBlue, width: 2), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // --- MODERN ŞİFRE ALANI ---
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: const TextStyle(color: textGrey),
                  prefixIcon: const Icon(Icons.lock_rounded, color: textGrey),
                  // Şifreyi göster/gizle butonu
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: textGrey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: cardColor,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: primaryBlue, width: 2), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // --- DEVASA ANA GİRİŞ BUTONU ---
              SizedBox(
                height: 56, // Parmak ucuyla kolay dokunulabilir yükseklik
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)
                    ),
                  ),
                  child: _isLoading 
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                        )
                      : const Text(
                          'GİRİŞ YAP', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)
                        ),
                ),
              ),
              const SizedBox(height: 24), // YENİ: Boşluk eklendi

              // YENİ: Gizlilik Politikası Butonu
              TextButton(
                onPressed: () async {
                  final Uri url = Uri.parse('https://sinif360privacy.vercel.app'); 
                  if (!await launchUrl(url)) {
                    debugPrint('Link açılamadı');
                  }
                },
                child: const Text(
                  'Gizlilik Politikası',
                  style: TextStyle(
                    color: textGrey, // Tasarımına uygun gri bir ton
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}