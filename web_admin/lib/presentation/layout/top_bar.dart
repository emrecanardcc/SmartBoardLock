// lib/presentation/layout/top_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/school_selector_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/tips_guide_dialog.dart';

class TopBar extends StatefulWidget {
  final String title;

  const TopBar({super.key, required this.title});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final bool _isRealtimeConnected = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final user = authProvider.currentUser;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Başlık / Okul Adı
          Expanded(
            child: authProvider.isSuperAdmin
                ? _SchoolSwitcher(provider: selectorProvider)
                : _SchoolTitle(
                    schoolName: _getSchoolName(user, selectorProvider),
                  ),
          ),

          // Realtime bağlantı göstergesi
          _RealtimeIndicator(connected: _isRealtimeConnected),

          const SizedBox(width: 12),

          // Sunucu Sürüm Rozeti
          const _ServerVersionBadge(),

          const SizedBox(width: 16),

          // İpuçları & Rehber Butonu
          OutlinedButton.icon(
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary),
            label: const Text('Rehber & İpuçları'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showTipsGuideDialog(context, isSuperAdmin: authProvider.isSuperAdmin),
          ),

          const SizedBox(width: 14),

          // Kullanıcı bilgisi + Çıkış
          _UserChip(user: user, onSignOut: () async {
            await authProvider.signOut();
          }),
        ],
      ),
    );
  }

  String _getSchoolName(UserProfileModel? user, SchoolSelectorProvider selector) {
    if (user != null && !user.isSuperAdmin) {
      if (user.schoolName != null && user.schoolName!.isNotEmpty) {
        return user.schoolName!;
      }
      if (selector.selectedSchool != null) return selector.selectedSchool!.name;
      return 'Okul Yönetimi';
    }
    if (selector.selectedSchool != null) return selector.selectedSchool!.name;
    return 'Sınıf360 (Tüm Sistem)';
  }
}

class _SchoolTitle extends StatelessWidget {
  final String schoolName;
  const _SchoolTitle({required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Text(
      schoolName,
      style: const TextStyle(
        color: AppColors.textDark,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.3,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SchoolSwitcher extends StatefulWidget {
  final SchoolSelectorProvider provider;
  const _SchoolSwitcher({required this.provider});

  @override
  State<_SchoolSwitcher> createState() => _SchoolSwitcherState();
}

class _SchoolSwitcherState extends State<_SchoolSwitcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.provider.allSchools.isEmpty) {
        widget.provider.loadSchools(context.read<AdminRepository>());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schools = widget.provider.allSchools;
    final selectedId = widget.provider.activeSchoolId;

    // Seçili id'nin okullar listesinde var olduğunu doğrula (Dropdown assertion crash önlemi)
    final effectiveValue = (selectedId != null && schools.any((s) => s.id == selectedId))
        ? selectedId
        : null;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.badgeSuperAdmin.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: AppColors.badgeSuperAdmin,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: effectiveValue,
              hint: const Text(
                'Tüm Sistem (Global)',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              icon: const Icon(Icons.expand_more_rounded, color: AppColors.textGrey),
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    '🌐 Tüm Sistem (Global)',
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                  ),
                ),
                ...schools.map((school) => DropdownMenuItem<String?>(
                      value: school.id,
                      child: Text(
                        '🏫 ${school.name}',
                        style: const TextStyle(color: AppColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (schoolId) => widget.provider.selectSchoolById(schoolId),
            ),
          ),
        ),
      ],
    );
  }
}

class _RealtimeIndicator extends StatelessWidget {
  final bool connected;
  const _RealtimeIndicator({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected ? 'Canlı bağlantı aktif' : 'Bağlantı kesildi',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: connected
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: connected
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.danger.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected ? AppColors.success : AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'Canlı' : 'Çevrimdışı',
              style: TextStyle(
                color: connected ? AppColors.success : AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  final UserProfileModel? user;
  final VoidCallback onSignOut;

  const _UserChip({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final isAdmin = user?.role == UserRole.admin;

    final badgeColor = isSuperAdmin
        ? AppColors.badgeSuperAdmin
        : isAdmin
            ? AppColors.badgeAdmin
            : AppColors.badgeTeacher;

    final roleLabel = isSuperAdmin
        ? 'Sistem Yöneticisi'
        : isAdmin
            ? 'Kurum Yöneticisi'
            : 'Öğretmen';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rol rozeti
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            roleLabel,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Avatar + İsim
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgPage,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (user?.displayName.isNotEmpty ?? false)
                      ? user!.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user?.displayName ?? 'Kullanıcı',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Çıkış butonu
        Tooltip(
          message: 'Çıkış Yap',
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            onPressed: onSignOut,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.danger.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerVersionBadge extends StatelessWidget {
  const _ServerVersionBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Sınıf360 Sunucu & Panel Sürümü: ${AppConstants.serverVersion}\nSunucu: ${AppConstants.serverHost}\nSon Güncelleme: ${AppConstants.serverReleaseDate}\nDurum: ${AppConstants.serverStatus}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.dns_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Sunucu: ${AppConstants.serverVersion}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                 letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

