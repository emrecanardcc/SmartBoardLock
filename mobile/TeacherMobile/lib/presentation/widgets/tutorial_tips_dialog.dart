import 'package:flutter/material.dart';

class TutorialTipsDialog extends StatelessWidget {
  final String userRole; // 'teacher' or 'school_admin'

  const TutorialTipsDialog({super.key, required this.userRole});

  static Future<void> show(BuildContext context, {required String userRole}) {
    return showDialog(
      context: context,
      builder: (ctx) => TutorialTipsDialog(userRole: userRole),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = userRole == 'teacher';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF60A5FA), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTeacher ? 'Öğretmen Kullanım Rehberi' : 'Okul Müdürü Yönetim Rehberi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sınıf360 Akıllı Tahta Kilit Sistemi İpuçları',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Tips List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: isTeacher ? _buildTeacherTips() : _buildAdminTips(),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'İpuçlarına dilediğiniz an Ayarlar menüsünden ulaşabilirsiniz.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTeacherTips() {
    return [
      _buildTipItem(
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: '1. Favoriler İlk Ekranınızda Açılır',
        description:
            'Girdiğiniz dersliklerin yanındaki yıldız ikonuna tıklayarak favorilere ekleyin. Uygulamayı açtığınızda yalnızca ders verdiğiniz sınıfları görürsünüz.',
      ),
      _buildTipItem(
        icon: Icons.qr_code_scanner_rounded,
        iconColor: const Color(0xFF10B981),
        title: '2. QR Kod ile Hızlı Kilit Açma',
        description:
            'Akıllı tahtanın kilit ekranında gösterilen dinamik karekodu telefonunuzla okutarak şifresiz ve anında ders oturumu başlatabilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.lock_clock_rounded,
        iconColor: const Color(0xFF3B82F6),
        title: '3. İnternetsiz Çevrimdışı TOTP Şifresi',
        description:
            'Okul veya mobil internetiniz çekmediğinde TOTP Çevrimdışı menüsünden 30 saniyelik güvenli şifre alarak tahtaya elle girebilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.filter_alt_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: '4. Kademe & 1-12 Sınıf Filtreleri',
        description:
            'İlkokul (1-4), Ortaokul (5-8), Lise (9-12) veya 1\'den 12\'ye kadar doğrudan sınıf seçerek okulunuzdaki onlarca tahta arasından dersliğinizi hemen bulun.',
      ),
      _buildTipItem(
        icon: Icons.bug_report_rounded,
        iconColor: const Color(0xFFF43F5E),
        title: '5. Sorun & Arıza Bildirimi',
        description:
            'Tahtada dokunmatik arızası, kilit takılması veya ağ sorunu yaşarsanız Ayarlar menüsündeki "Sorun Bildir" formunu kullanarak doğrudan teknik ekibe iletebilirsiniz.',
      ),
    ];
  }

  List<Widget> _buildAdminTips() {
    return [
      _buildTipItem(
        icon: Icons.security_rounded,
        iconColor: const Color(0xFFF43F5E),
        title: '1. Acil Durumda Tümünü Kilitle',
        description:
            'Teneffüs zili çaldığında veya okul tatil olduğunda sağ üstteki kırmızı kilit butonuyla okuldaki tüm açık tahtaları tek hamlede kilitleyebilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.auto_awesome_motion_rounded,
        iconColor: const Color(0xFF3B82F6),
        title: '2. 1-12 Sınıf ve Kademe Yönetimi',
        description:
            'Okulunuz ilkokul, ortaokul veya lise olsa dahi İlkokul (1-4), Ortaokul (5-8), Lise (9-12) ve Diğer filtreleriyle tüm derslikleri kolayca gruplayabilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.person_add_alt_1_rounded,
        iconColor: const Color(0xFF10B981),
        title: '3. Öğretmen Yetkilendirme',
        description:
            '"Öğretmenler" menüsünden okula yeni başlayan öğretmenleri onaylayabilir veya okuldan ayrılanların kilit açma yetkisini pasife alabilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.add_to_queue_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: '4. Yeni Tahta Eşleştirme',
        description:
            'Yeni kurulan bir akıllı tahtayı sisteme eklemek için tahta ekranındaki 6 haneli kodu mobil uygulamadan girerek saniyeler içinde bağlayabilirsiniz.',
      ),
      _buildTipItem(
        icon: Icons.support_agent_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: '5. Doğrudan Destek Talebi',
        description:
            'Teknik destek gereken durumlarda Ayarlar menüsünden "Sorun Bildir" ekranı ile Geliştirici & Teknik Destek Ekibine arıza kaydı bırakabilirsiniz.',
      ),
    ];
  }

  Widget _buildTipItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
