import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'admin_boards_screen.dart';

// --- YENİ MODERN RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz (Genel Arka Plan)
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi (Ana vurgular)
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz (Ana başlıklar)
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz (Alt metinler)

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Kritik düzeltme: Ekran çizimini bekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRole();
    });
  }

  Future<void> _checkRole() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    // 1. Oturum yoksa Login'e gönder
    if (session == null) {
      _navigate(const LoginScreen());
      return;
    }

    try {
      // 2. Oturum varsa Supabase'den rolünü sor
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('role')
          .eq('id', session.user.id)
          .single();

      // 3. Role göre doğru ekrana yönlendir
      if (profile['role'] == 'admin') {
        _navigate(const AdminBoardsScreen());
      } else {
        _navigate(const DashboardScreen());
      }
    } catch (e) {
      // Hata durumunda çıkış yap ve Login'e at
      await Supabase.instance.client.auth.signOut();
      _navigate(const LoginScreen());
    }
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // YENİ: Profesyonel açılış hissiyatı veren ikon tasarımı
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded, // Güvenliği ve yönetimi temsil eden kalkan ikonu
                size: 64, 
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            // YENİ: Bilgilendirici açılış yazısı
            const Text(
              'Sistem Başlatılıyor...',
              style: TextStyle(
                color: textDark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Güvenlik doğrulanıyor, lütfen bekleyin',
              style: TextStyle(
                color: textGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: primaryBlue,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}