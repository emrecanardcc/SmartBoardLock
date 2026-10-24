// lib/presentation/screens/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  static const String windowsSetupUrl = 'http://130.61.78.192/Sinif360_Setup.exe';
  static const String androidApkUrl = 'http://130.61.78.192/Sinif360_TeacherMobile.apk';
  static const String currentVersion = 'v2.1.2';

  Future<void> _downloadFile(BuildContext context, String url, String filename) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename indirilemedi. Lütfen bağlantıyı kopyalayarak tarayıcınızda açın.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme başlatılamadı: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String url, String title) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('$title indirme bağlantısı panoya kopyalandı!')),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── BAŞLIK & AÇIKLAMA ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.download_for_offline_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uygulama & İstemci İndirme Merkezi',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kurumunuzdaki akıllı tahtalar ve öğretmenler için en güncel ve onaylanmış resmi kurulum dosyaları.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── GÜVENLİK VE BİLGİ BANDI ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Bu alandaki tüm kurulum dosyaları Sınıf360 Güvenli Sunucusu tarafından onaylanmış ve virüs taramasından geçirilmiştir. Kurum yöneticileri diledikleri an doğrudan indirebilir.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── İKİLİ KART DÜZENİ (WINDOWS SETUP & ANDROID APK) ─────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildWindowsCard(context),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildAndroidCard(context),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildWindowsCard(context),
                      const SizedBox(height: 24),
                      _buildAndroidCard(context),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // ─── ALT BİLGİ VE YARDIM KARTI ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.help_outline_rounded, color: AppColors.info, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kurulum ve Eşleştirme Desteği',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tahta kurulumunda veya öğretmen hesaplarının telefona tanımlanmasında teknik desteğe ihtiyaç duyarsanız doğrudan iletişime geçebilirsiniz: emrecanardc.dev@gmail.com',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── WINDOWS KURULUM KARTI ──────────────────────────────────────────────────
  Widget _buildWindowsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: İkon ve Rozet
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0078D4), Color(0xFF005A9E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.desktop_windows_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akıllı Tahta İstemcisi',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$currentVersion • Resmi Kurulum',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '~3.4 MB',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Sınıftaki akıllı tahtalara kurularak merkezi yönetim, güvenli kilit koruması, duyuru/afiş gösterimi ve mobil kilit açmayı devreye alır.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Özellikler & Gereksinimler
          _buildInfoRow(Icons.check_circle_outline_rounded, 'Windows 10 / 11 (64-bit) ve Pardus uyumlu'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.security_rounded, 'Masaüstü kilit sistemi & Kiosk modu koruması'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.sync_rounded, 'Otomatik arka plan sessiz güncelleme altyapısı'),

          const SizedBox(height: 20),

          // Kurulum Rehberi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hızlı Kurulum Adımları:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStepRow('1', 'Setup dosyasını tahtada çalıştırıp kurulumu tamamlayın.'),
                _buildStepRow('2', 'Ekrandaki 6 haneli Eşleştirme Kodunu "Tahta Ekle" alanına girin.'),
                _buildStepRow('3', 'Tahta anında okulunuza bağlanır ve kilit aktif olur.'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Windows Setup İndir (.exe)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _downloadFile(context, windowsSetupUrl, 'Sinif360_Setup.exe'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Doğrudan indirme bağlantısını kopyala',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _copyToClipboard(context, windowsSetupUrl, 'Windows Setup'),
                  child: const Icon(Icons.link_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ANDROID MOBİL KURULUM KARTI ───────────────────────────────────────────
  Widget _buildAndroidCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: İkon ve Rozet
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34A853), Color(0xFF1B7330)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Öğretmen Mobil Uygulaması',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$currentVersion • Android APK',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '~68 MB',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'Öğretmenlerin akıllı telefonlarından sınıflardaki tahtaları QR kod taratarak veya TOTP güvenlik kodu girerek açmasını sağlar.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textGrey,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Özellikler & Gereksinimler
          _buildInfoRow(Icons.check_circle_outline_rounded, 'Android 8.0 (Oreo) ve üzeri tüm cihazlar'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.qr_code_scanner_rounded, 'Dinamik QR kod ve 30 saniyelik TOTP ile kilit açma'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.info_outline_rounded, 'Google Play & App Store inceleme sürecindedir (APK anında kurulur)'),

          const SizedBox(height: 20),

          // Kurulum Rehberi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hızlı Kurulum Adımları:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStepRow('1', 'APK dosyasını telefona indirin.'),
                _buildStepRow('2', 'Dosyaya tıklayıp "Bilinmeyen kaynaklardan yükleme"ye izin verin.'),
                _buildStepRow('3', 'Yöneticinizin açtığı öğretmen e-posta ve şifresiyle giriş yapın.'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Android APK İndir (.apk)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B7330),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _downloadFile(context, androidApkUrl, 'Sinif360_TeacherMobile.apk'),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Doğrudan indirme bağlantısını kopyala',
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _copyToClipboard(context, androidApkUrl, 'Android APK'),
                  child: const Icon(Icons.link_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
