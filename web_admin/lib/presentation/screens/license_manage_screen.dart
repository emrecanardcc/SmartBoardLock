// lib/presentation/screens/license_manage_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/school_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/admin_repository.dart';

class LicenseManageScreen extends StatefulWidget {
  const LicenseManageScreen({super.key});

  @override
  State<LicenseManageScreen> createState() => _LicenseManageScreenState();
}

class _LicenseManageScreenState extends State<LicenseManageScreen> {
  String? _selectedSchoolId;
  DateTime? _editedExpiryDate;
  bool? _editedIsLicensed;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  // Gerçek Sayılarla Kurum Verileri & Realtime Dinleme
  List<SchoolModel> _schoolsList = [];
  SchoolModel? _schoolDetails;
  bool _isLoading = true;
  StreamSubscription? _realtimeSchoolsSub;
  StreamSubscription? _realtimeSchoolSub;
  StreamSubscription? _realtimeBoardsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  Future<void> _initData() async {
    final auth = context.read<AuthProvider>();
    final repo = context.read<AdminRepository>();

    if (auth.isSuperAdmin) {
      await _loadSuperAdminData(repo);
      _realtimeSchoolsSub = repo.streamSchools().listen((_) {
        _loadSuperAdminData(repo, silent: true);
      });
    } else {
      final schoolId = auth.currentUser?.schoolId;
      if (schoolId != null) {
        await _loadSchoolAdminData(repo, schoolId);
        _realtimeSchoolSub = repo.streamSchool(schoolId).listen((_) {
          _loadSchoolAdminData(repo, schoolId, silent: true);
        });
        _realtimeBoardsSub = repo.streamBoards(schoolId).listen((_) {
          _loadSchoolAdminData(repo, schoolId, silent: true);
        });
      }
    }
  }

  Future<void> _loadSuperAdminData(AdminRepository repo, {bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await repo.getSchools();
      if (!mounted) return;
      setState(() {
        _schoolsList = list;
        _isLoading = false;
        if (_selectedSchoolId == null && list.isNotEmpty) {
          _selectedSchoolId = list.first.id;
          _notesController.text = list.first.licenseNotes ?? '';
        } else if (_selectedSchoolId != null) {
          final sel = list.firstWhere(
            (s) => s.id == _selectedSchoolId,
            orElse: () => list.first,
          );
          if (_notesController.text.isEmpty && sel.licenseNotes != null) {
            _notesController.text = sel.licenseNotes!;
          }
        }
      });
    } catch (e) {
      debugPrint('_loadSuperAdminData error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSchoolAdminData(AdminRepository repo, String schoolId, {bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final details = await repo.getSchoolDetails(schoolId);
      if (!mounted) return;
      setState(() {
        _schoolDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('_loadSchoolAdminData error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _realtimeSchoolsSub?.cancel();
    _realtimeSchoolSub?.cancel();
    _realtimeBoardsSub?.cancel();
    super.dispose();
  }

  String _formatDateTr(DateTime date) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _copySupportEmail() {
    Clipboard.setData(const ClipboardData(text: 'emrecanardc.dev@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Destek e-posta adresi panoya kopyalandı.'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickCustomDate(BuildContext context, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editedExpiryDate ?? initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _editedExpiryDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _saveSuperAdminChanges(SchoolModel school) async {
    final repo = context.read<AdminRepository>();
    setState(() => _isSaving = true);
    try {
      final newExpiry = _editedExpiryDate ?? school.licenseExpiresAt ?? DateTime.now().add(const Duration(days: 365));
      final newIsLicensed = _editedIsLicensed ?? school.isLicensed;
      final newNotes = _notesController.text;

      await repo.updateSchoolLicense(
        schoolId: school.id,
        isLicensed: newIsLicensed,
        licenseExpiresAt: newExpiry,
        licenseNotes: newNotes,
      );

      await _loadSuperAdminData(repo, silent: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${school.name} lisans bilgileri başarıyla güncellendi.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      setState(() {
        _editedExpiryDate = null;
        _editedIsLicensed = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isSuper = authProvider.isSuperAdmin;
    final repo = context.read<AdminRepository>();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: isSuper ? _buildSuperAdminView(repo) : _buildSchoolAdminView(authProvider, repo),
      ),
    );
  }

  // ===================== KURUM YÖNETİCİSİ (MÜDÜR) GÖRÜNÜMÜ =====================

  Widget _buildSchoolAdminView(AuthProvider auth, AdminRepository repo) {
    final schoolId = auth.currentUser?.schoolId;
    if (schoolId == null) {
      return Center(
        child: Text(
          'Kurum yetkilendirme bilgisi bulunamadı.',
          style: GoogleFonts.inter(color: AppColors.textGrey, fontSize: 15),
        ),
      );
    }

    if (_isLoading && _schoolDetails == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final school = _schoolDetails;
    if (school == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kurum bilgisi yüklenemedi.', style: GoogleFonts.inter(color: AppColors.textGrey, fontSize: 15)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadSchoolAdminData(repo, schoolId),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    final expiry = school.licenseExpiresAt ?? DateTime.now();
    final remainingDays = school.remainingLicenseDays;
    final isActive = school.isLicenseActive;
    final isExpiringSoon = school.isExpiringSoon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(
          title: 'Kurumsal Lisans Durumu',
          subtitle: '${school.name} - ${school.city}',
          badgeText: isActive ? (isExpiringSoon ? 'YENİLEME YAKLAŞIYOR' : 'LİSANS AKTİF') : 'SÜRESİ DOLDU',
          badgeColor: isActive ? (isExpiringSoon ? AppColors.warning : AppColors.success) : AppColors.danger,
        ),
        const SizedBox(height: 24),

        // Hero Sayaç Kartı
        _buildHeroLicenseCard(
          schoolName: school.name,
          city: school.city,
          isActive: isActive,
          isExpiringSoon: isExpiringSoon,
          remainingDays: remainingDays,
          expiry: expiry,
          notes: school.licenseNotes,
        ),
        const SizedBox(height: 24),

        // Bilgi & İstatistik Kartları (Gerçek Tahta ve Öğretmen Sayılarıyla)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildKurumInfoCard(school, expiry),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: _buildSupportContactCard(),
            ),
          ],
        ),
      ],
    );
  }

  // ===================== SİSTEM YÖNETİCİSİ GÖRÜNÜMÜ =====================

  Widget _buildSuperAdminView(AdminRepository repo) {
    if (_isLoading && _schoolsList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final schools = _schoolsList;
    if (schools.isEmpty) {
      return Center(
        child: Text('Kayıtlı okul bulunmuyor.', style: GoogleFonts.inter(color: AppColors.textGrey)),
      );
    }

    final currentSchoolId = _selectedSchoolId ?? schools.first.id;
    final selectedSchool = schools.firstWhere(
      (s) => s.id == currentSchoolId,
      orElse: () => schools.first,
    );

    final activeExpiry = _editedExpiryDate ?? selectedSchool.licenseExpiresAt ?? DateTime.now();
    final activeIsLicensed = _editedIsLicensed ?? selectedSchool.isLicensed;
    final remainingDays = activeExpiry.difference(DateTime.now()).inDays;
    final isActive = activeIsLicensed && remainingDays > 0;
    final isExpiringSoon = isActive && remainingDays <= 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPageHeader(
              title: 'Kurumsal Lisans & Yetkilendirme Paneli',
              subtitle: 'Tüm okulların lisans sürelerini denetleyin, uzatın ve güncelleyin.',
              badgeText: 'SİSTEM YÖNETİCİSİ MODU',
              badgeColor: AppColors.primary,
            ),
            // Okul Seçici Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedSchool.id,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textDark),
                  items: schools.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: s.isLicenseActive ? AppColors.success : AppColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${s.name} (${s.city}) - [${s.boardCount} Tahta]',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSchoolId = val;
                        _editedExpiryDate = null;
                        _editedIsLicensed = null;
                        final next = schools.firstWhere((sc) => sc.id == val);
                        _notesController.text = next.licenseNotes ?? '';
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Hero Lisans Kartı
        _buildHeroLicenseCard(
          schoolName: selectedSchool.name,
          city: selectedSchool.city,
          isActive: isActive,
          isExpiringSoon: isExpiringSoon,
          remainingDays: remainingDays,
          expiry: activeExpiry,
          notes: selectedSchool.licenseNotes,
        ),
        const SizedBox(height: 24),

        // Süper Admin Lisans Düzenleme Formu
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lisans Süresini Uzat & Değiştir',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Aşağıdaki hızlı uzatma butonlarını veya takvim seçicisini kullanabilirsiniz.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Aktif / Pasif Switch
                  Row(
                    children: [
                      Text(
                        activeIsLicensed ? 'Lisans Yetkisi Açık' : 'Lisans Donduruldu',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: activeIsLicensed ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: activeIsLicensed,
                        activeThumbColor: AppColors.success,
                        onChanged: (val) => setState(() => _editedIsLicensed = val),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),

              // Hızlı Uzatma Çipleri
              Text(
                'Hızlı Süre Uzatma:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildQuickChip(
                    label: '+1 Ay Uzat',
                    onTap: () {
                      final base = activeExpiry.isAfter(DateTime.now()) ? activeExpiry : DateTime.now();
                      setState(() {
                        _editedExpiryDate = DateTime(base.year, base.month + 1, base.day, 23, 59, 59);
                        _editedIsLicensed = true;
                      });
                    },
                  ),
                  _buildQuickChip(
                    label: '+6 Ay Uzat',
                    onTap: () {
                      final base = activeExpiry.isAfter(DateTime.now()) ? activeExpiry : DateTime.now();
                      setState(() {
                        _editedExpiryDate = DateTime(base.year, base.month + 6, base.day, 23, 59, 59);
                        _editedIsLicensed = true;
                      });
                    },
                  ),
                  _buildQuickChip(
                    label: '+1 Yıl Uzat',
                    isHighlighted: true,
                    onTap: () {
                      final base = activeExpiry.isAfter(DateTime.now()) ? activeExpiry : DateTime.now();
                      setState(() {
                        _editedExpiryDate = DateTime(base.year + 1, base.month, base.day, 23, 59, 59);
                        _editedIsLicensed = true;
                      });
                    },
                  ),
                  _buildQuickChip(
                    label: '+3 Yıl Uzat',
                    onTap: () {
                      final base = activeExpiry.isAfter(DateTime.now()) ? activeExpiry : DateTime.now();
                      setState(() {
                        _editedExpiryDate = DateTime(base.year + 3, base.month, base.day, 23, 59, 59);
                        _editedIsLicensed = true;
                      });
                    },
                  ),
                  // Takvimden seç
                  InkWell(
                    onTap: () => _pickCustomDate(context, activeExpiry),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Takvimden Tarih Seç',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sözleşme Notu
              Text(
                'Lisans Sözleşme / Referans Notu:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Örn: MEB Protokolü 2026-2027 Eğitim Öğretim Yılı / Kurumsal Sözleşme No: 2026-TR-44',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.bgPage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveSuperAdminChanges(selectedSchool),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Kaydediliyor...' : 'Lisans Değişikliklerini Kaydet',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // İstatistik ve İletişim kartı (Seçili Okulun Gerçek Sayılarıyla)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildKurumInfoCard(selectedSchool, activeExpiry)),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: _buildSupportContactCard()),
          ],
        ),
      ],
    );
  }

  // ===================== YARDIMCI WIDGET'LAR =====================

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.inter(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey),
        ),
      ],
    );
  }

  Widget _buildHeroLicenseCard({
    required String schoolName,
    required String city,
    required bool isActive,
    required bool isExpiringSoon,
    required int remainingDays,
    required DateTime expiry,
    String? notes,
  }) {
    final statusColor = isActive ? (isExpiringSoon ? AppColors.warning : AppColors.success) : AppColors.danger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol Büyük Sayaç Dairesi / Rozeti
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? '$remainingDays' : '0',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  isActive ? 'GÜN KALDI' : 'SÜRE BİTTİ',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),

          // Orta Detaylar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isActive ? 'Kurumsal Lisansınız Aktif' : 'Lisans Süresi Sona Erdi',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? (isExpiringSoon ? 'Son 15 Gün' : 'Tam Yetkili') : 'Kilit Devre Dışı',
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isActive
                      ? 'Bu kurumdaki tüm akıllı tahtalar ve öğretmen mobil yetkilendirme servisleri tam kapasite çalışmaktadır.'
                      : 'Kurum lisans süresi dolduğu için akıllı tahtalar açılışta kilit ekranını pasife alır ve sistemi kilitlemez.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                ),
                const SizedBox(height: 14),

                // Bilgi Çubukları
                Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    _buildMetaItem(Icons.calendar_month_rounded, 'Son Geçerlilik Tarihi:', _formatDateTr(expiry)),
                    if (notes != null && notes.isNotEmpty)
                      _buildMetaItem(Icons.assignment_rounded, 'Sözleşme / Protokol:', notes),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textGrey),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ],
    );
  }

  Widget _buildKurumInfoCard(SchoolModel school, DateTime expiry) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Kurum Ekosistem İstatistikleri',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.tv_rounded,
                  iconColor: AppColors.primary,
                  label: 'Kayıtlı Akıllı Tahta',
                  value: '${school.boardCount}',
                  subText: 'Sınıflarda Kurulu',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.group_rounded,
                  iconColor: const Color(0xFF0D9488),
                  label: 'Yetkili Öğretmen',
                  value: '${school.teacherCount}',
                  subText: 'Aktif Kullanıcı',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.security_rounded,
                  iconColor: AppColors.success,
                  label: 'Sistem Koruması',
                  value: school.isLicenseActive ? 'Aktif' : 'Devre Dışı',
                  subText: 'Kiosk Güvenlik',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          Text(subText, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildSupportContactCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Lisans Yenileme & Destek',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Kurum lisansınızı uzatmak, yeni akıllı tahta paketi tanımlamak veya resmi fatura talepleriniz için teknik destek ekibimizle görüşebilirsiniz.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'emrecanardc.dev@gmail.com',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textGrey),
                  tooltip: 'E-postayı Kopyala',
                  onPressed: _copySupportEmail,
                  splashRadius: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? AppColors.primary : AppColors.bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isHighlighted ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isHighlighted ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
