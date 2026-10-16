// lib/presentation/screens/super_schools_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/school_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/app_dialog.dart';

class SuperSchoolsScreen extends StatefulWidget {
  const SuperSchoolsScreen({super.key});

  @override
  State<SuperSchoolsScreen> createState() => _SuperSchoolsScreenState();
}

class _SuperSchoolsScreenState extends State<SuperSchoolsScreen> {
  late Future<List<SchoolModel>> _schoolsFuture;
  StreamSubscription? _realtimeSubscription;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSchools();
    _initRealtimeSubscription();
  }

  void _initRealtimeSubscription() {
    final repo = context.read<AdminRepository>();
    _realtimeSubscription = repo.streamSchools().listen((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _loadSchools() {
    final repo = context.read<AdminRepository>();
    _schoolsFuture = repo.getSchools();
  }

  void _refresh() {
    setState(() => _loadSchools());
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AdminRepository>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + Ekle Butonu
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Okul ve Lisans Yönetimi',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Sistemdeki tüm kayıtlı kurumları, tahtalarını ve lisans sürelerini yönetin.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Okul & Lisans Tanımla'),
                onPressed: () =>
                    _showAddEditSchoolDialog(context, repo),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Arama
          SizedBox(
            width: 320,
            height: 44,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Okul adı, şehir veya lisans ara...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textGrey, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: 16),
                filled: true,
                fillColor: AppColors.bgCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Okul listesi
          Expanded(
            child: FutureBuilder<List<SchoolModel>>(
              future: _schoolsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Hata: ${snapshot.error}',
                        style:
                            const TextStyle(color: AppColors.danger)),
                  );
                }

                var schools = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  schools = schools.where((s) {
                    return s.name.toLowerCase().contains(q) ||
                        s.city.toLowerCase().contains(q) ||
                        (s.licenseNotes?.toLowerCase().contains(q) ?? false);
                  }).toList();
                }

                if (schools.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_outlined,
                            size: 56, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          'Kayıtlı okul bulunamadı.',
                          style: GoogleFonts.inter(
                              color: AppColors.textGrey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.border)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.bgPage),
                        headingTextStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                          letterSpacing: 0.5,
                        ),
                        dataTextStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                        columnSpacing: 24,
                        horizontalMargin: 20,
                        columns: const [
                          DataColumn(label: Text('OKUL ADI')),
                          DataColumn(label: Text('ŞEHİR')),
                          DataColumn(label: Text('LİSANS DURUMU')),
                          DataColumn(label: Text('LİSANS BİTİŞ')),
                          DataColumn(label: Text('TAHTA')),
                          DataColumn(label: Text('KULLANICILAR')),
                          DataColumn(label: Text('KAYIT')),
                          DataColumn(label: Text('İŞLEMLER')),
                        ],
                        rows: schools.map((school) {
                          return DataRow(cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.school_rounded,
                                        color: AppColors.primary,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(school.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      if (school.licenseNotes != null && school.licenseNotes!.isNotEmpty)
                                        Text(
                                          school.licenseNotes!,
                                          style: const TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(school.city)),
                            DataCell(_buildLicenseBadge(school)),
                            DataCell(
                              school.licenseExpiresAt != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          DateFormat('dd.MM.yyyy').format(school.licenseExpiresAt!.toLocal()),
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          school.isLicenseActive
                                              ? '${school.remainingLicenseDays} gün kaldı'
                                              : 'Süre sona erdi',
                                          style: TextStyle(
                                            color: school.isLicenseActive
                                                ? (school.isExpiringSoon ? AppColors.warning : AppColors.textGrey)
                                                : AppColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Süresiz', style: TextStyle(color: AppColors.textGrey)),
                            ),
                            DataCell(_CountBadge(
                                value: school.boardCount,
                                color: AppColors.info)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.success
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${school.teacherCount} Öğretmen',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (school.adminCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${school.adminCount} Müdür',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(Text(
                              DateFormat('dd.MM.yyyy').format(
                                  school.createdAt.toLocal()),
                              style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar_rounded,
                                      color: AppColors.primary, size: 20),
                                  tooltip: 'Lisans & Okul Düzenle',
                                  onPressed: () =>
                                      _showAddEditSchoolDialog(
                                          context, repo,
                                          school: school),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded,
                                      color: AppColors.danger, size: 18),
                                  tooltip: 'Sil',
                                  onPressed: () async {
                                    final confirmed =
                                        await showConfirmDialog(
                                      context,
                                      title: 'Okulu Sil',
                                      content:
                                          '"${school.name}" okulunu sistemden silmek istediğinize emin misiniz? Bu işlem geri alınamaz!',
                                      confirmLabel: 'Sil',
                                      icon: Icons.delete_forever_rounded,
                                    );
                                    if (confirmed && context.mounted) {
                                      try {
                                        await repo
                                            .deleteSchool(school.id);
                                        if (context.mounted) {
                                          _refresh();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '"${school.name}" silindi.'),
                                              backgroundColor:
                                                  AppColors.textDark,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Hata: $e'),
                                              backgroundColor:
                                                  AppColors.danger,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseBadge(SchoolModel school) {
    if (!school.isLicensed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 14, color: AppColors.danger),
            SizedBox(width: 4),
            Text(
              'Lisanssız / Pasif',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (!school.isLicenseActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_rounded, size: 14, color: AppColors.danger),
            SizedBox(width: 4),
            Text(
              'Süresi Doldu',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (school.isExpiringSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              'Kritik: ${school.remainingLicenseDays} Gün',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Aktif Lisans',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditSchoolDialog(
    BuildContext context,
    AdminRepository repo, {
    SchoolModel? school,
  }) async {
    final isEditing = school != null;
    final nameController = TextEditingController(text: school?.name ?? '');
    final cityController = TextEditingController(text: school?.city ?? '');
    final notesController = TextEditingController(text: school?.licenseNotes ?? '');

    bool isLicensed = school?.isLicensed ?? true;
    DateTime licenseExpiry = school?.licenseExpiresAt ?? DateTime.now().add(const Duration(days: 365));
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_calendar_rounded : Icons.add_business_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Okul & Lisans Düzenle' : 'Yeni Okul ve Lisans Tanımla',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Kurum bilgilerini ve akıllı tahta lisans geçerlilik süresini belirleyin.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Okul / Kurum Adı',
                            hintText: 'Örn. Atatürk Anadolu Lisesi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'Şehir',
                            hintText: 'Örn. İstanbul',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Lisans Yönetim Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isLicensed ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                                  color: isLicensed ? AppColors.success : AppColors.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sınıf360 Lisans Durumu',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                            Switch(
                              value: isLicensed,
                              activeThumbColor: AppColors.success,
                              onChanged: (val) {
                                setDialogState(() => isLicensed = val);
                              },
                            ),
                          ],
                        ),
                        Text(
                          isLicensed
                              ? 'Lisans aktif: Tahtalar normal şekilde kilitlenir ve korunur.'
                              : 'Lisans kapalı: Tahtalar hiç kilitlenmez, arka planda kilit uygulaması çalışmaz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLicensed ? AppColors.textGrey : AppColors.danger,
                          ),
                        ),
                        const Divider(height: 24),

                        Text(
                          'Lisans Bitiş Tarihi',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),

                        // Hızlı Paket Butonları
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDurationChip(
                              label: '+1 Ay',
                              onTap: () {
                                setDialogState(() {
                                  licenseExpiry = DateTime.now().add(const Duration(days: 30));
                                });
                              },
                            ),
                            _buildDurationChip(
                              label: '+6 Ay',
                              onTap: () {
                                setDialogState(() {
                                  licenseExpiry = DateTime.now().add(const Duration(days: 180));
                                });
                              },
                            ),
                            _buildDurationChip(
                              label: '+1 Yıl (Standart)',
                              isSelected: true,
                              onTap: () {
                                setDialogState(() {
                                  licenseExpiry = DateTime.now().add(const Duration(days: 365));
                                });
                              },
                            ),
                            _buildDurationChip(
                              label: '+3 Yıl (Uzun Dönem)',
                              onTap: () {
                                setDialogState(() {
                                  licenseExpiry = DateTime.now().add(const Duration(days: 1095));
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Tarih Seçici Satırı
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: licenseExpiry.isAfter(DateTime.now())
                                  ? licenseExpiry
                                  : DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primary,
                                      onPrimary: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                licenseExpiry = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Bitiş: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(licenseExpiry)} '
                                    '(${licenseExpiry.difference(DateTime.now()).inDays} gün kaldı)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                const Text(
                                  'Tarihi Değiştir',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: notesController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Lisans Notu / Sözleşme Kodu (İsteğe Bağlı)',
                            hintText: 'Örn. 2026-2027 İl MEM Protokolü',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    cityController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Okul adı ve şehir alanları zorunludur.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                try {
                                  if (isEditing) {
                                    await repo.updateSchool(
                                      schoolId: school.id,
                                      name: nameController.text,
                                      city: cityController.text,
                                      isLicensed: isLicensed,
                                      licenseExpiresAt: licenseExpiry,
                                      licenseNotes: notesController.text,
                                    );
                                  } else {
                                    await repo.createSchool(
                                      name: nameController.text,
                                      city: cityController.text,
                                      isLicensed: isLicensed,
                                      licenseExpiresAt: licenseExpiry,
                                      licenseNotes: notesController.text,
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _refresh();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Okul ve lisans bilgileri güncellendi.'
                                            : 'Yeni okul ve lisans kaydı oluşturuldu.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Hata: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'Kaydet & Güncelle' : 'Okulu Oluştur'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip({
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  final Color color;
  const _CountBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
