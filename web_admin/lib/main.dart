// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/school_selector_provider.dart';
import 'data/repositories/admin_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase başlatma
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  runApp(const WebAdminApp());
}

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repository — tüm CRUD ve Realtime operasyonları
        Provider<AdminRepository>(
          create: (_) => AdminRepository(),
        ),

        // Auth state yönetimi
        ChangeNotifierProxyProvider<AdminRepository, AuthProvider>(
          create: (context) =>
              AuthProvider(context.read<AdminRepository>()),
          update: (context, repo, previous) =>
              previous ?? AuthProvider(repo),
        ),

        // Süper Admin okul seçici
        ChangeNotifierProvider<SchoolSelectorProvider>(
          create: (_) => SchoolSelectorProvider(),
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final _router = AppRouter.createRouter(context);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
