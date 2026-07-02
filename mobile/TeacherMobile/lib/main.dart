import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/auth_gate.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yapılandırdığımız sabitlerden Supabase'i ayağa kaldırıyoruz
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const KioskRemoteApp());
}

class KioskRemoteApp extends StatelessWidget {
  const KioskRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'Tahta Kumandası',
  theme: ThemeData(primarySwatch: Colors.green),
  // Supabase'de aktif bir oturum var mı kontrol et
  home:  const AuthGate(),
);
  }
}