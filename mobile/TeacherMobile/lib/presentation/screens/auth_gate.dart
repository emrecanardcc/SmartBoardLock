import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'admin_boards_screen.dart';

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
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );
  }
}