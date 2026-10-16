// lib/presentation/layout/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/school_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/admin_repository.dart';
import 'sidebar.dart';
import 'top_bar.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  final String title;
  final bool isSuperAdmin;

  const MainShell({
    super.key,
    required this.child,
    required this.title,
    required this.isSuperAdmin,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;
    final currentRoute = GoRouterState.of(context).uri.path;
    final authProvider = context.watch<AuthProvider>();
    final repo = context.read<AdminRepository>();

    final effectiveCollapsed = isNarrow || _sidebarCollapsed;
    final schoolId = authProvider.currentUser?.schoolId;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AppSidebar(
            isCollapsed: effectiveCollapsed,
            isSuperAdmin: widget.isSuperAdmin,
            currentRoute: currentRoute,
            onToggleCollapse: isNarrow
                ? null
                : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),

          // Ana içerik
          Expanded(
            child: Column(
              children: [
                // TopBar
                TopBar(title: widget.title),

                // Sayfa içeriği ve Lisans Kontrolü
                Expanded(
                  child: !widget.isSuperAdmin && schoolId != null
                      ? StreamBuilder<SchoolModel?>(
                          stream: repo.streamSchool(schoolId),
                          builder: (context, snapshot) {
                            final school = snapshot.data;
                            final isExpired = school != null && !school.isLicenseActive;

                            return Stack(
                              children: [
                                IgnorePointer(
                                  ignoring: isExpired,
                                  child: ColorFiltered(
                                    colorFilter: isExpired
                                        ? const ColorFilter.mode(
                                            Colors.grey,
                                            BlendMode.saturation,
                                          )
                                        : const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.multiply,
                                          ),
                                    child: widget.child,
                                  ),
                                ),
                                if (isExpired)
                                  _buildLicenseExpiredBlocker(context, school, authProvider),
                              ],
                            );
                          },
                        )
                      : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseExpiredBlocker(
    BuildContext context,
    SchoolModel school,
    AuthProvider authProvider,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: AppColors.danger,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kurumunuzun Lisans Süresi Dolmuştur',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${school.name} akıllı tahta koruma ve yönetim lisansı sona ermiştir.\n'
              'Eğitim-öğretimin aksamaması amacıyla tahtalarınız açık tutulmaktadır; '
              'ancak web ve mobil yönetim yetkileri güvenlik gerekçesiyle duraklatılmıştır.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textGrey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Geliştirici & Teknik Destek Ekibi',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                        ),
                      ),
                      SelectableText(
                        'emrecanardc.dev@gmail.com',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Oturumu Kapat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => authProvider.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
