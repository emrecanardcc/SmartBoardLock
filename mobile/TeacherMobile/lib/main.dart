import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. .env dosyasını güvenli bir şekilde yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  final url = dotenv.env['SUPABASE_URL'] ?? 'http://130.61.78.192:8000';
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // 2. Supabase'i dışarıya kapalı ortam değişkenleriyle başlat
  await Supabase.initialize(
    url: url,
    publishableKey: anonKey,
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