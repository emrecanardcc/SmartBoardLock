import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'presentation/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env dosyasını varsa güvenli bir şekilde yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // 2. Supabase'i SupabaseConfig üzerinden güvenle başlat
  await Supabase.initialize(
    url: SupabaseConfig.primaryUrl,
    publishableKey: SupabaseConfig.primaryKey,
  );

  runApp(const KioskRemoteApp());
}

class KioskRemoteApp extends StatelessWidget {
  const KioskRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Tahta Kumandası', 
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}