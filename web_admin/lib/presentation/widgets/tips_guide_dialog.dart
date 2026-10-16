// lib/presentation/widgets/tips_guide_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

void showTipsGuideDialog(BuildContext context, {required bool isSuperAdmin}) {
  showDialog(
    context: context,
    builder: (context) => _TipsGuideDialog(isSuperAdmin: isSuperAdmin),
  );
}

class _TipsGuideDialog extends StatefulWidget {
  final bool isSuperAdmin;
  const _TipsGuideDialog({required this.isSuperAdmin});

  @override
  State<_TipsGuideDialog> createState() => _TipsGuideDialogState();
}

class _TipsGuideDialogState extends State<_TipsGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isSuperAdmin ? 3 : 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sınıf360 Sistem Rehberi & Kullanım İpuçları',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Akıllı tahta yönetim panelindeki tüm yetenekler ve kısayollar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Sekmeler
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textGrey,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.school_rounded, size: 18),
                    text: 'Okul Müdürü Rehberi',
                  ),
                  if (widget.isSuperAdmin)
                    const Tab(
                      icon: Icon(Icons.admin_panel_settings_rounded, size: 18),
                      text: 'Süper Admin Rehberi',
                    ),
                  const Tab(
                    icon: Icon(Icons.tips_and_updates_rounded, size: 18),
                    text: 'İpuçları & Kısayollar',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // İçerik
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSchoolAdminGuide(),
                    if (widget.isSuperAdmin) _buildSuperAdminGuide(),
                    _buildTipsAndShortcuts(),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anladım, Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolAdminGuide() {
    return ListView(
      children: [
        _buildGuideCard(
          icon: Icons.tv_rounded,
          iconColor: AppColors.primary,
          title: '1. Canlı Tahta İzleme & Güç Durumları',
          description:
              'Okulunuzdaki tahtaların durumunu canlı renklerle takip edin:\n'
              '• Yeşil Kilit Rozeti: Tahta açık, öğretmen ders işliyor.\n'
              '• Kırmızı Kilit Rozeti: Tahta kilitli güvenli bekleme modunda.\n'
              '• Cihaz Açık (Mavi/Yeşil): Tahtanın Windows bilgisayarı o an çalışıyor.\n'
              '• Cihaz Kapalı (Gri): Tahta bilgisayarı kapalı veya elektriği kesik.',
        ),
        _buildGuideCard(
          icon: Icons.power_settings_new_rounded,
          iconColor: AppColors.danger,
          title: '2. Uzaktan Bilgisayar Kapatma (Tekil & Toplu)',
          description:
              'Müdür olarak tahtaları uzaktan kapatabilirsiniz:\n'
              '• Kart Üzerinden Tekil Kapatma: Kartın sağ altındaki kırmızı güç butonuna veya menüden "Bilgisayarı Kapat"a basarak tek bir tahtayı kapatabilirsiniz.\n'
              '• Çoklu Seçim Modu: Üstteki "Çoklu Seçim" butonuna basıp istediğiniz tahtaları seçerek "Seçilenleri Kapat" yapabilirsiniz.\n'
              '• Tüm Açık Bilgisayarları Kapat: Üstteki "Bilgisayarları Kapat" butonu ile okuldaki o an açık olan TÜM tahtaları tek tıkla güvenle kapatabilirsiniz.',
        ),
        _buildGuideCard(
          icon: Icons.campaign_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: '3. Afiş & Duyuru Yayını Yönetimi',
          description:
              'Kilit ekranında görüntülenecek görselleri yönetin:\n'
              '• Okul etkinlikleri, sınav takvimi veya duyuruları yükleyip yayınlayın.\n'
              '• Yayın süresi bittiğinde tahtalar otomatik olarak varsayılan Atatürk ve Bayrak afişlerine döner.\n'
              '• "Varsayılana Sıfırla" butonu ile yayını anında durdurabilirsiniz.',
        ),
        _buildGuideCard(
          icon: Icons.people_alt_rounded,
          iconColor: AppColors.success,
          title: '4. Öğretmen Kayıt ve Yetkilendirme',
          description:
              'Mobil uygulamayı indiren öğretmenler okulunuza kayıt olduğunda Öğretmenler sekmesinde "Onay Bekliyor" olarak görünür. Tek tıkla onaylayabilir, gerektiğinde şifre sıfırlama bağlantısı gönderebilirsiniz.',
        ),
        _buildGuideCard(
          icon: Icons.filter_alt_rounded,
          iconColor: AppColors.warning,
          title: '5. Sınıf ve Şube Filtreleme (1-12 & Diğer)',
          description:
              'Filtre çubuğundan 1. sınıftan 12. sınıfa kadar istediğiniz sınıfı süzebilir, laboratuvar ve özel salonlar için "Diğer" seçeneğini kullanabilirsiniz.',
        ),
      ],
    );
  }

  Widget _buildSuperAdminGuide() {
    return ListView(
      children: [
        _buildGuideCard(
          icon: Icons.school_rounded,
          iconColor: AppColors.primary,
          title: '1. Okul Yönetimi & Lisanslama',
          description:
              'Yeni okul oluşturun, kurum kodunu ve il/ilçe bilgisini belirleyin. Üst bardaki Okul Değiştirici ile herhangi bir okulun tahtalarını anlık izleyebilirsiniz.',
        ),
        _buildGuideCard(
          icon: Icons.system_update_rounded,
          iconColor: const Color(0xFF10B981),
          title: '2. Sürüm Dağıtımı & TahtaRepair Kurtarma',
          description:
              'Sürüm & Güncelleme sekmesinden yeni Windows güncelleme ZIP paketini yükleyin. Tahtalarda hasar veya çökme yaşandığında tahta kartından veya toplu menüden "Bütünlüğü Onar (TahtaRepair)" göndererek tahtayı okula gitmeden kurtarın.',
        ),
        _buildGuideCard(
          icon: Icons.support_agent_rounded,
          iconColor: AppColors.warning,
          title: '3. Sorun Bildirimleri & Destek Masası (/issues)',
          description:
              'Öğretmen ve müdürlerin mobil uygulamadan ilettiği QR kilit, donanım veya yazılım arızalarını inceleyin. "İncele" butonu ile durumunu "İnceleniyor", "Çözüldü" veya "Reddedildi" olarak güncelleyip çözüm notu bırakabilirsiniz.',
        ),
      ],
    );
  }

  Widget _buildTipsAndShortcuts() {
    return ListView(
      children: [
        _buildGuideCard(
          icon: Icons.speed_rounded,
          iconColor: AppColors.success,
          title: '💡 Hızlı Kilit & Açma',
          description:
              'Kart üzerindeki büyük butona tıklayarak tahtanın kilit durumunu 0.5 saniye içinde anlık değiştirebilirsiniz. Bu işlem Windows üzerinde donanım seviyesinde kilitlenir.',
        ),
        _buildGuideCard(
          icon: Icons.checklist_rtl_rounded,
          iconColor: AppColors.primary,
          title: '💡 Çoklu Seçim ile Toplu İşlemler',
          description:
              '"Çoklu Seçim" butonuna basarak seçim kutucuklarını aktif edin. 10. sınıfları filtreleyip "Tümünü Seç" kutusuna basarak sadece 10. sınıfların tahtalarını tek seferde kilitleyebilir veya kapatabilirsiniz.',
        ),
        _buildGuideCard(
          icon: Icons.sync_rounded,
          iconColor: const Color(0xFF0EA5E9),
          title: '💡 Otomatik Gerçek Zamanlı (Realtime) Senkron',
          description:
              'Sayfayı yenilemenize (F5) gerek yoktur. Bir öğretmen tahtanın kilidini açtığında veya kapattığında kartın rengi ve durumu ekranda canlı olarak anında güncellenir.',
        ),
        _buildGuideCard(
          icon: Icons.security_rounded,
          iconColor: AppColors.danger,
          title: '💡 İnternet Kesintisi Güvencesi (TOTP)',
          description:
              'Okul interneti kopsa dahi öğretmenler mobil uygulamalarındaki 6 haneli çevrimdışı TOTP koduyla tahta kilidini güvenle açabilirler.',
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textMedium,
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
