// lib/presentation/screens/super_schools_screen.dart
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSchools();
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
                      'Okul Yönetimi',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Sistemdeki tüm okulları görüntüleyin ve yönetin.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni Okul Ekle'),
                onPressed: () =>
                    _showAddEditSchoolDialog(context, repo),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Arama
          SizedBox(
            width: 280,
            height: 44,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Okul adı veya şehir ara...',
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
                        s.city.toLowerCase().contains(q);
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
                          'Henüz okul eklenmemiş.',
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
                          DataColumn(label: Text('TAHTA SAYISI')),
                          DataColumn(label: Text('ÖĞRETMEN SAYISI')),
                          DataColumn(label: Text('OLUŞTURULMA TARİHİ')),
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
                                  Text(school.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DataCell(Text(school.city)),
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
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppColors.info, size: 18),
                                  tooltip: 'Düzenle',
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

  Future<void> _showAddEditSchoolDialog(
    BuildContext context,
    AdminRepository repo, {
    SchoolModel? school,
  }) async {
    final isEditing = school != null;
    final nameController =
        TextEditingController(text: school?.name ?? '');
    final cityController =
        TextEditingController(text: school?.city ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Okul Düzenle' : 'Yeni Okul Ekle',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'Okul Adı'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityController,
                    decoration:
                        const InputDecoration(labelText: 'Şehir'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    cityController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Tüm alanlar zorunludur.'),
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
                                    );
                                  } else {
                                    await repo.createSchool(
                                      name: nameController.text,
                                      city: cityController.text,
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _refresh();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Okul güncellendi.'
                                            : 'Yeni okul eklendi.'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
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
                            : Text(isEditing ? 'Güncelle' : 'Ekle'),
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
