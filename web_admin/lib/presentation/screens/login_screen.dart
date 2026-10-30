// lib/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Canlı Sistem & Veritabanı Sağlık Durumu Kontrolü
  bool _isCheckingHealth = true;
  bool _isServerHealthy = true;
  String _healthMessage = 'Bağlantı kontrol ediliyor...';

  @override
  void initState() {
    super.initState();
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    setState(() {
      _isCheckingHealth = true;
      _healthMessage = 'Sunucu bağlantısı denetleniyor...';
    });

    try {
      // Supabase PostgREST & Veritabanı erişimini doğrudan test et (4 saniye zaman aşımı)
      await Supabase.instance.client
          .from('schools')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() {
          _isCheckingHealth = false;
          _isServerHealthy = true;
          _healthMessage = 'Sistem Çevrimiçi (Veritabanı & API Aktif)';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingHealth = false;
          _isServerHealthy = false;
          _healthMessage = 'Sunucu bağlantısında aksaklık var';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _localizeError(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = _localizeError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizeError(String message) {
    // 1. Ham HTML veya Cloudflare Origin DNS/Proxy hatalarını yakala
    if (message.contains('<html') ||
        message.contains('<!doctype') ||
        message.contains('Cloudflare') ||
        message.contains('1016') ||
        message.contains('Origin DNS error') ||
        message.contains('530') ||
        message.contains('502') ||
        message.contains('504')) {
      return 'Sunucu veya ağ geçidi bağlantısında geçici bir aksaklık tespit edildi. Lütfen internet bağlantınızı kontrol edip birkaç saniye sonra tekrar deneyin.';
    }

    if (message.contains('ClientException') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('Network is unreachable')) {
      return 'Sunucuya ulaşılamıyor. Lütfen internet bağlantınızı kontrol edin.';
    }

    if (message.contains('Invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'E-posta adresi veya şifre hatalı.';
    }
    if (message.contains('Email not confirmed')) {
      return 'E-posta adresiniz henüz doğrulanmamış.';
    }
    if (message.contains('Too many requests')) {
      return 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Row(
        children: [
          // Sol panel — kurumsal illüstrasyon
          if (MediaQuery.of(context).size.width > 800)
            Expanded(
              flex: 5,
              child: Container(
                color: AppColors.bgSidebar,
                child: Stack(
                  children: [
                    // Arkaplan dekoratif elemanlar
                    Positioned(
                      top: -80,
                      right: -80,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -60,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.1),
                        ),
                      ),
                    ),

                    // İçerik
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            Text(
                              'Sınıf360',
                              style: GoogleFonts.inter(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Akıllı Tahta Yönetim Sistemi',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.sidebarText,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Özellik listesi
                            ...[
                              ('📡', 'Canlı tahta izleme ve toplu kontrol'),
                              ('🏫', 'Çoklu okul ve müdür yönetimi'),
                              ('👩‍🏫', 'Öğretmen kadro yönetimi'),
                              ('🔒', 'Güvenli rol tabanlı erişim'),
                            ].map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      Text(item.$1,
                                          style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 12),
                                      Text(
                                        item.$2,
                                        style: GoogleFonts.inter(
                                          color: AppColors.sidebarText,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Sağ panel — login formu
          Expanded(
            flex: 4,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mobil logo (küçük ekranda sol panel gizlendiğinde)
                      if (MediaQuery.of(context).size.width <= 800) ...[
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Başlık
                      Text(
                        'Yönetici Girişi',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sınıf360 Yönetim Paneline erişmek için giriş yapın.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // E-posta
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.inter(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'E-posta Adresi',
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: AppColors.textGrey),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'E-posta adresi gereklidir.';
                                }
                                if (!v.contains('@')) {
                                  return 'Geçerli bir e-posta adresi girin.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Şifre
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _signIn(),
                              style: GoogleFonts.inter(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline_rounded,
                                    color: AppColors.textGrey),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textGrey,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Şifre gereklidir.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Hata mesajı
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppColors.danger, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(
                                          color: AppColors.danger,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Giriş butonu
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor:
                                      AppColors.primary.withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Giriş Yap',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Canlı Sistem & Veritabanı Sağlık Durumu Rozeti
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isCheckingHealth
                                ? Colors.grey.shade100
                                : (_isServerHealthy
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : AppColors.danger.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCheckingHealth
                                  ? Colors.grey.shade300
                                  : (_isServerHealthy
                                      ? AppColors.success.withValues(alpha: 0.3)
                                      : AppColors.danger.withValues(alpha: 0.3)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isCheckingHealth
                                      ? Colors.amber
                                      : (_isServerHealthy
                                          ? AppColors.success
                                          : AppColors.danger),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _healthMessage,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _isCheckingHealth
                                      ? AppColors.textGrey
                                      : (_isServerHealthy
                                          ? AppColors.success
                                          : AppColors.danger),
                                ),
                              ),
                              if (!_isCheckingHealth && !_isServerHealthy) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _checkServerHealth,
                                  child: Text(
                                    'Yeniden Dene',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.danger,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Alt not
                      Text(
                        'Bu panel yalnızca Okul Yöneticileri ve Sistem Yöneticisi içindir.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
