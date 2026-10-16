// lib/presentation/layout/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

    // Dar ekranda sidebar otomatik daralt
    final effectiveCollapsed = isNarrow || _sidebarCollapsed;

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

                // Sayfa içeriği
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
