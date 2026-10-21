import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/app_update_service.dart';
import 'auth_gate.dart';

const Color bgLight = Color(0xFFF1F5F9);
const Color primaryBlue = Color(0xFF3B82F6);
const Color textDark = Color(0xFF0F172A);
const Color textGrey = Color(0xFF64748B);

/// Sınıf360 Mobil Zorunlu Güncelleme Engelleyici Ekranı.
/// Eski sürüm kullanan öğretmenlerin tahta kilit işlemlerinde sürüm uyumsuzluğu
/// yaşamaması için uygulamayı güncellemeden geçiş yapmasını engeller.
class ForcedUpdateScreen extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const ForcedUpdateScreen({
    super.key,
    required this.updateInfo,
  });

  @override
  State<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends State<ForcedUpdateScreen> {
  bool _isChecking = false;

  Future<void> _openStore() async {
    final urlString = widget.updateInfo.storeUrl.trim();
    if (urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uygulama mağazası bağlantısı henüz tanımlanmamış. Lütfen App Store / Google Play üzerinden güncelleyin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mağaza açılamadı: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _recheckUpdate() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final latest = await AppUpdateService.checkForUpdate();
    if (!mounted) return;

    setState(() => _isChecking = false);

    if (latest == null || !latest.isForced) {
      // Güncelleme yapılmış veya kural esnetilmiş -> Girişe yönlendir
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uygulama henüz güncellenmemiş. Gereken en düşük sürüm: v${latest.minVersion}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Geri tuşuyla bu ekrandan çıkılamaz
      child: Scaffold(
        backgroundColor: bgLight,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // İkon Rozeti
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 46,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Başlık
                      Text(
                        widget.updateInfo.title.isNotEmpty
                            ? widget.updateInfo.title
                            : 'Zorunlu Güncelleme',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Sürüm Bilgisi Rozetleri
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mevcut: v${widget.updateInfo.currentVersion}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textGrey,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: primaryBlue),
                            ),
                            Text(
                              'Gerekli: v${widget.updateInfo.minVersion}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Açıklama Metni
                      Text(
                        widget.updateInfo.message,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: textGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Hemen Güncelle Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _openStore,
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Hemen Güncelle',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Yeniden Kontrol Et Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isChecking ? null : _recheckUpdate,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                                )
                              : const Text(
                                  'Yeniden Kontrol Et',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
