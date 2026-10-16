// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Ana renkler
  static const Color primary = Color(0xFF0D9488);      // Teal / Turkuaz
  static const Color primaryLight = Color(0xFF14B8A6); // Açık Teal
  static const Color primaryDark = Color(0xFF0F766E);  // Koyu Teal
  static const Color accent = Color(0xFF00B4D8);       // Açık Mavi Turkuaz

  // Arka plan renkleri
  static const Color bgPage = Color(0xFFF8FAFC);       // Sayfa arka planı
  static const Color bgSidebar = Color(0xFF0F172A);    // Sidebar Lacivert
  static const Color bgSidebarHover = Color(0xFF1E293B);
  static const Color bgCard = Color(0xFFFFFFFF);       // Kart arka planı
  static const Color bgCardHover = Color(0xFFF1F5F9);  // Kart hover

  // Metin renkleri
  static const Color textDark = Color(0xFF0F172A);     // Ana metin
  static const Color textMedium = Color(0xFF334155);   // Orta metin
  static const Color textGrey = Color(0xFF64748B);     // Gri metin
  static const Color textLight = Color(0xFF94A3B8);    // Açık metin

  // Durum renkleri
  static const Color success = Color(0xFF10B981);      // Yeşil (Açık / Online)
  static const Color warning = Color(0xFFF59E0B);      // Sarı-Turuncu
  static const Color danger = Color(0xFFF43F5E);       // Kırmızı (Kilitli / Hata)
  static const Color info = Color(0xFF3B82F6);         // Mavi (Bilgi)
  static const Color offline = Color(0xFF94A3B8);      // Gri (Çevrimdışı)

  // Roz rozet renkleri (süper admin vs müdür)
  static const Color badgeSuperAdmin = Color(0xFF8B5CF6); // Mor
  static const Color badgeAdmin = Color(0xFF0D9488);       // Teal
  static const Color badgeTeacher = Color(0xFF3B82F6);     // Mavi

  // Kenarlık
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E1);

  // Sidebar metin rengi
  static const Color sidebarText = Color(0xFFCBD5E1);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
  static const Color sidebarIcon = Color(0xFF64748B);
  static const Color sidebarIconActive = Color(0xFF14B8A6);
}
