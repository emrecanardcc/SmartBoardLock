// lib/presentation/layout/sidebar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class SidebarItem {
  final String label;
  final IconData icon;
  final String route;
  final bool superAdminOnly;

  const SidebarItem({
    required this.label,
    required this.icon,
    required this.route,
    this.superAdminOnly = false,
  });
}

const List<SidebarItem> _sidebarItems = [
  SidebarItem(
    label: 'Canlı İzleme',
    icon: Icons.dashboard_rounded,
    route: '/dashboard',
  ),
  SidebarItem(
    label: 'Tahta Yönetimi',
    icon: Icons.tv_rounded,
    route: '/boards',
  ),
  SidebarItem(
    label: 'Afiş & Duyuru',
    icon: Icons.campaign_rounded,
    route: '/media',
  ),
  SidebarItem(
    label: 'Öğretmenler',
    icon: Icons.people_alt_rounded,
    route: '/teachers',
  ),
  SidebarItem(
    label: 'Kurumsal Lisans',
    icon: Icons.verified_user_rounded,
    route: '/license',
  ),
  SidebarItem(
    label: 'Uygulama İndir',
    icon: Icons.download_rounded,
    route: '/downloads',
  ),
  SidebarItem(
    label: 'Okul Yönetimi',
    icon: Icons.school_rounded,
    route: '/schools',
    superAdminOnly: true,
  ),
  SidebarItem(
    label: 'Sürüm & Güncelleme',
    icon: Icons.system_update_rounded,
    route: '/versions',
    superAdminOnly: true,
  ),
  SidebarItem(
    label: 'Sorun Bildirimleri',
    icon: Icons.support_agent_rounded,
    route: '/issues',
    superAdminOnly: true,
  ),
];

class AppSidebar extends StatelessWidget {
  final bool isCollapsed;
  final bool isSuperAdmin;
  final String currentRoute;
  final VoidCallback? onToggleCollapse;

  const AppSidebar({
    super.key,
    required this.isCollapsed,
    required this.isSuperAdmin,
    required this.currentRoute,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final width = isCollapsed ? 72.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      color: AppColors.bgSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Başlık
          _buildHeader(context),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 16),

          // Menü öğeleri
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _sidebarItems
                  .where((item) => !item.superAdminOnly || isSuperAdmin)
                  .map((item) => _SidebarNavItem(
                        item: item,
                        isCollapsed: isCollapsed,
                        isActive: currentRoute.startsWith(item.route),
                      ))
                  .toList(),
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 8),

          // Daralt / Genişlet butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Tooltip(
              message: isCollapsed ? 'Menüyü Genişlet' : 'Menüyü Daralt',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggleCollapse,
                child: Container(
                  height: 44,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.bgSidebarHover,
                  ),
                  child: Icon(
                    isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: AppColors.sidebarText,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sınıf360',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      isSuperAdmin ? 'Merkezi Yönetim' : 'Kurum Yönetimi',
                      style: TextStyle(
                        color: AppColors.sidebarText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final SidebarItem item;
  final bool isCollapsed;
  final bool isActive;

  const _SidebarNavItem({
    required this.item,
    required this.isCollapsed,
    required this.isActive,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.primary.withValues(alpha: 0.2)
        : _isHovered
            ? AppColors.bgSidebarHover
            : Colors.transparent;

    final iconColor = widget.isActive
        ? AppColors.sidebarIconActive
        : AppColors.sidebarText;

    final textColor = widget.isActive
        ? AppColors.sidebarTextActive
        : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tooltip(
          message: widget.isCollapsed ? widget.item.label : '',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(widget.item.route),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCollapsed ? 0 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: bg,
                border: widget.isActive
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: widget.isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(widget.item.icon, color: iconColor, size: 20),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: widget.isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.sidebarIconActive,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
