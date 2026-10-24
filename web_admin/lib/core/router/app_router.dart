// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../presentation/layout/main_shell.dart';
import '../../presentation/screens/access_denied_screen.dart';
import '../../presentation/screens/boards_manage_screen.dart';
import '../../presentation/screens/live_boards_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/super_schools_screen.dart';
import '../../presentation/screens/super_versions_screen.dart';
import '../../presentation/screens/super_issues_screen.dart';
import '../../presentation/screens/teachers_manage_screen.dart';
import '../../presentation/screens/media_manage_screen.dart';
import '../../presentation/screens/license_manage_screen.dart';
import '../../presentation/screens/downloads_screen.dart';

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final authProvider = context.read<AuthProvider>();

        if (authProvider.isLoading) return null;

        final isLoginPage = state.uri.path == '/login';

        if (!authProvider.isLoggedIn) {
          return isLoginPage ? null : '/login';
        }

        // Giriş yapmış ama öğretmense — erişim engeli
        if (authProvider.currentUser?.role == UserRole.teacher) {
          return state.uri.path == '/access-denied' ? null : '/access-denied';
        }

        // Süper admin olmayan biri süper admin sayfasına giremesin
        if (!authProvider.isSuperAdmin) {
          if (state.uri.path == '/schools' ||
              state.uri.path == '/versions' ||
              state.uri.path == '/issues') {
            return '/dashboard';
          }
        }

        // Giriş yapmış ve admin ise login'e gitmesin
        if (isLoginPage) return '/dashboard';

        return null;
      },
      refreshListenable: context.read<AuthProvider>(),
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/access-denied',
          name: 'access-denied',
          builder: (context, state) => const AccessDeniedScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final authProvider = context.read<AuthProvider>();
            final isSuperAdmin = authProvider.isSuperAdmin;

            String title;
            final path = state.uri.path;
            if (path == '/dashboard') {
              title = 'Canlı İzleme';
            } else if (path == '/boards') {
              title = 'Tahta Yönetimi';
            } else if (path == '/media') {
              title = 'Afiş & Duyuru Yönetimi';
            } else if (path == '/teachers') {
              title = 'Öğretmenler';
            } else if (path == '/schools') {
              title = 'Okul Yönetimi';
            } else if (path == '/versions') {
              title = 'Sürüm & Güncelleme';
            } else if (path == '/issues') {
              title = 'Sorun Bildirimleri';
            } else if (path == '/license') {
              title = 'Kurumsal Lisans';
            } else if (path == '/downloads') {
              title = 'Uygulama İndir';
            } else {
              title = 'Sınıf360';
            }

            return MainShell(
              title: title,
              isSuperAdmin: isSuperAdmin,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              name: 'dashboard',
              builder: (context, state) => const LiveBoardsScreen(),
            ),
            GoRoute(
              path: '/boards',
              name: 'boards',
              builder: (context, state) => const BoardsManageScreen(),
            ),
            GoRoute(
              path: '/media',
              name: 'media',
              builder: (context, state) => const MediaManageScreen(),
            ),
            GoRoute(
              path: '/teachers',
              name: 'teachers',
              builder: (context, state) => const TeachersManageScreen(),
            ),
            GoRoute(
              path: '/license',
              name: 'license',
              builder: (context, state) => const LicenseManageScreen(),
            ),
            GoRoute(
              path: '/downloads',
              name: 'downloads',
              builder: (context, state) => const DownloadsScreen(),
            ),
            GoRoute(
              path: '/schools',
              name: 'schools',
              builder: (context, state) => const SuperSchoolsScreen(),
            ),
            GoRoute(
              path: '/versions',
              name: 'versions',
              builder: (context, state) => const SuperVersionsScreen(),
            ),
            GoRoute(
              path: '/issues',
              name: 'issues',
              builder: (context, state) => const SuperIssuesScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
