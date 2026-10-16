// lib/presentation/screens/teachers_manage_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/school_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/school_selector_provider.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/app_dialog.dart';

class TeachersManageScreen extends StatefulWidget {
  const TeachersManageScreen({super.key});

  @override
  State<TeachersManageScreen> createState() => _TeachersManageScreenState();
}

class _TeachersManageScreenState extends State<TeachersManageScreen> {
  String _searchQuery = '';
  String _roleFilter = 'Tümü'; // Tümü, Müdür/Yönetici, Öğretmen
  String? _lastLoadedSchoolId;
  List<SchoolModel> _schools = [];
  List<UserProfileModel> _allUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasInitialLoaded = false;
  int _loadVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final repo = context.read<AdminRepository>();

    final currentSchoolId = authProvider.isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;

    if (authProvider.isSuperAdmin &&
        selectorProvider.allSchools.isEmpty &&
        !selectorProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          selectorProvider.loadSchools(repo);
        }
      });
    }

    if (selectorProvider.allSchools.isNotEmpty) {
      _schools = selectorProvider.allSchools;
    }

    if (!_hasInitialLoaded) {
      _hasInitialLoaded = true;
      _lastLoadedSchoolId = currentSchoolId;
      _loadUsers(currentSchoolId);
    } else if (_lastLoadedSchoolId != currentSchoolId) {
      _lastLoadedSchoolId = currentSchoolId;
      _loadUsers(currentSchoolId);
    }
  }

  Future<void> _loadUsers(String? schoolId) async {
    final currentVersion = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AdminRepository>();
      final users = await repo.getUsers(schoolId);
      if (!mounted || currentVersion != _loadVersion) return;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('TeachersManageScreen _loadUsers error: $e\n$st');
      if (!mounted || currentVersion != _loadVersion) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSchoolFilterChanged(String? newSchoolId) {
    context.read<SchoolSelectorProvider>().selectSchoolById(newSchoolId);
  }

  List<UserProfileModel> _getFilteredUsers() {
    var users = _allUsers;

    // Rol filtresi
    if (_roleFilter == 'Öğretmen') {
      users = users.where((u) => u.role == UserRole.teacher).toList();
    } else if (_roleFilter == 'Müdür/Yönetici') {
      users = users.where((u) => u.role == UserRole.admin).toList();
    }

    // Arama
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      users = users.where((u) {
        final nameMatch = u.fullName?.toLowerCase().contains(q) ?? false;
        final emailMatch = u.email?.toLowerCase().contains(q) ?? false;
        final schoolMatch = u.schoolName?.toLowerCase().contains(q) ?? false;
        return nameMatch || emailMatch || schoolMatch;
      }).toList();
    }

    return users;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final selectorProvider = context.watch<SchoolSelectorProvider>();
    final isSuperAdmin = authProvider.isSuperAdmin;
    final repo = context.read<AdminRepository>();

    final effectiveSchoolId = isSuperAdmin
        ? selectorProvider.activeSchoolId
        : authProvider.currentUser?.schoolId;
    final schools = selectorProvider.allSchools.isNotEmpty
        ? selectorProvider.allSchools
        : _schools;

    final users = _getFilteredUsers();
    final adminCount = _allUsers.where((u) => u.role == UserRole.admin).length;
    final teacherCount =
        _allUsers.where((u) => u.role == UserRole.teacher).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── ÜST BAŞLIK VE EYLEMLER ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Öğretmen & Kadro Yönetimi',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoading
                          ? 'Kullanıcılar yükleniyor...'
                          : '${_allUsers.length} Personel ($adminCount Müdür/Yönetici • $teacherCount Öğretmen)',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textGrey),
                tooltip: 'Yenile',
                onPressed: () {
                  _loadUsers(_lastLoadedSchoolId);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Yeni Kullanıcı Ekle'),
                onPressed: () async {
                  await _showAddUserDialog(
                    context,
                    repo,
                    schools: schools,
                    preselectedSchoolId: effectiveSchoolId,
                    isSuperAdmin: isSuperAdmin,
                  );
                  _loadUsers(_lastLoadedSchoolId);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── FİLTRELEME & ARAMA BARI ─────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Arama kutusu
              SizedBox(
                width: 260,
                height: 42,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'İsim, e-posta veya okul ara...',
                    prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textGrey, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 14),
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

              // Süper Admin için Okul Seçici Filtresi
              if (isSuperAdmin)
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: (effectiveSchoolId != null &&
                              schools.any((s) => s.id == effectiveSchoolId))
                          ? effectiveSchoolId
                          : null,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textGrey, size: 18),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      onChanged: _onSchoolFilterChanged,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Tüm Okullar (Global)'),
                            ],
                          ),
                        ),
                        ...schools.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_rounded,
                                    size: 16, color: AppColors.textGrey),
                                const SizedBox(width: 8),
                                Text(s.name),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Rol filtre butonları (Tümü, Müdür/Yönetici, Öğretmen)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final label in ['Tümü', 'Müdür/Yönetici', 'Öğretmen'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _RoleChip(
                        label: label,
                        isSelected: _roleFilter == label,
                        onTap: () => setState(() => _roleFilter = label),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── KULLANICI LİSTESİ ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _errorMessage != null
                    ? Center(
                        child: SelectableText(
                          'Hata oluştu:\n$_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      )
                    : users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline_rounded,
                                    size: 56, color: AppColors.textLight),
                                const SizedBox(height: 16),
                                Text(
                                  _allUsers.isEmpty
                                      ? (effectiveSchoolId == null
                                          ? 'Sistemde kayıtlı personel bulunamadı.'
                                          : 'Bu okulda henüz kayıtlı personel bulunmuyor.')
                                      : 'Filtreye uygun kullanıcı bulunamadı.',
                                  style: GoogleFonts.inter(
                                    color: AppColors.textGrey,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: const Border.fromBorderSide(
                                  BorderSide(color: AppColors.border)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.separated(
                                itemCount: users.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: AppColors.border),
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  final isManager =
                                      user.role == UserRole.admin;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isManager
                                          ? AppColors.primary
                                              .withValues(alpha: 0.03)
                                          : Colors.transparent,
                                      border: isManager
                                          ? const Border(
                                              left: BorderSide(
                                                color: AppColors.primary,
                                                width: 3.5,
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                      leading: CircleAvatar(
                                        radius: 22,
                                        backgroundColor: isManager
                                            ? AppColors.primary
                                                .withValues(alpha: 0.15)
                                            : AppColors.info
                                                .withValues(alpha: 0.12),
                                        child: isManager
                                            ? const Icon(
                                                Icons.shield_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              )
                                            : Text(
                                                user.initials,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                  color: AppColors.info,
                                                ),
                                              ),
                                      ),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.displayName,
                                              style: GoogleFonts.inter(
                                                fontWeight: isManager
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                fontSize: 14,
                                                color: AppColors.textDark,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Rol rozeti
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isManager
                                                  ? AppColors.primary
                                                      .withValues(alpha: 0.12)
                                                  : AppColors.badgeTeacher
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isManager
                                                    ? AppColors.primary
                                                        .withValues(alpha: 0.35)
                                                    : AppColors.badgeTeacher
                                                        .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isManager) ...[
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(
                                                  isManager
                                                      ? 'OKUL MÜDÜRÜ / YÖNETİCİ'
                                                      : 'ÖĞRETMEN',
                                                  style: TextStyle(
                                                    color: isManager
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .badgeTeacher,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.email_outlined,
                                                size: 14,
                                                color: AppColors.textGrey),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                user.email ??
                                                    'E-posta belirtilmemiş',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.textGrey,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (user.schoolName != null) ...[
                                              const SizedBox(width: 10),
                                              const Text('•',
                                                  style: TextStyle(
                                                      color:
                                                          AppColors.textLight)),
                                              const SizedBox(width: 10),
                                              const Icon(Icons.school_outlined,
                                                  size: 14,
                                                  color: AppColors.textGrey),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  user.schoolName!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.textGrey,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(
                                            Icons.more_vert_rounded,
                                            color: AppColors.textGrey,
                                            size: 20),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        color: AppColors.bgCard,
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _showEditUserDialog(
                                              context,
                                              repo,
                                              user,
                                              schools: schools,
                                              isSuperAdmin: isSuperAdmin,
                                            );
                                            _loadUsers(_lastLoadedSchoolId);
                                          } else if (value == 'password') {
                                            await _showChangePasswordDialog(
                                                context, repo, user);
                                          } else if (value == 'email') {
                                            await _showChangeEmailDialog(
                                                context, repo, user);
                                            _loadUsers(_lastLoadedSchoolId);
                                          } else if (value == 'delete') {
                                            await _deleteUser(
                                                context, repo, user);
                                            _loadUsers(_lastLoadedSchoolId);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [
                                              const Icon(Icons.edit_rounded,
                                                  color: AppColors.info,
                                                  size: 18),
                                              const SizedBox(width: 10),
                                              Text('Bilgileri Düzenle',
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textDark)),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'password',
                                            child: Row(children: [
                                              const Icon(Icons.key_rounded,
                                                  color: AppColors.warning,
                                                  size: 18),
                                              const SizedBox(width: 10),
                                              Text('Şifre Değiştir',
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textDark)),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'email',
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.alternate_email_rounded,
                                                  color: AppColors.primary,
                                                  size: 18),
                                              const SizedBox(width: 10),
                                              Text('E-posta Değiştir',
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textDark)),
                                            ]),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.person_remove_rounded,
                                                  color: AppColors.danger,
                                                  size: 18),
                                              const SizedBox(width: 10),
                                              Text('Sistemden Sil',
                                                  style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.danger)),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ─── DİYALOG: YENİ KULLANICI EKLE ───────────────────────────────────────────
  Future<void> _showAddUserDialog(
    BuildContext context,
    AdminRepository repo, {
    required List<SchoolModel> schools,
    required String? preselectedSchoolId,
    required bool isSuperAdmin,
  }) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'teacher';
    String? selectedSchoolId = preselectedSchoolId ??
        (schools.isNotEmpty ? schools.first.id : null);
    bool isSaving = false;
    bool obscurePassword = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Yeni Kullanıcı Ekle',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textGrey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textGrey,
                        ),
                        onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge_outlined,
                          color: AppColors.textGrey),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Öğretmen')),
                      DropdownMenuItem(
                          value: 'admin',
                          child: Text('Okul Müdürü / Yönetici')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedRole = v ?? 'teacher'),
                  ),
                  if (schools.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSchoolId,
                      decoration: const InputDecoration(
                        labelText: 'Bağlı Olduğu Okul',
                        prefixIcon: Icon(Icons.school_outlined,
                            color: AppColors.textGrey),
                      ),
                      items: schools.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSchoolId = v),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty ||
                                    emailController.text.trim().isEmpty ||
                                    passwordController.text.trim().isEmpty ||
                                    selectedSchoolId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Lütfen tüm alanları doldurun ve okul seçin.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                try {
                                  await repo.createUser(
                                    email: emailController.text,
                                    password: passwordController.text,
                                    fullName: nameController.text,
                                    schoolId: selectedSchoolId!,
                                    role: selectedRole,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${nameController.text} başarıyla eklendi.'),
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
                            : const Text('Kaydet'),
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

  // ─── DİYALOG: ŞİFRE DEĞİŞTİR ───────────────────────────────────────────────
  Future<void> _showChangePasswordDialog(
    BuildContext context,
    AdminRepository repo,
    UserProfileModel user,
  ) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.key_rounded,
                            color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Şifre Değiştir',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                )),
                            Text(user.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textGrey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textGrey,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Yeni Şifre (Tekrar)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textGrey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textGrey,
                        ),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final p1 = newPasswordController.text.trim();
                                final p2 =
                                    confirmPasswordController.text.trim();

                                if (p1.isEmpty || p2.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Lütfen şifre girin.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                if (p1.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Şifre en az 6 karakter olmalıdır.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                if (p1 != p2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Şifreler eşleşmiyor!'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isSaving = true);
                                try {
                                  await repo.updateUserPassword(
                                    userId: user.id,
                                    newPassword: p1,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${user.displayName} şifresi başarıyla güncellendi.'),
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
                            : const Text('Şifreyi Güncelle'),
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

  // ─── DİYALOG: E-POSTA DEĞİŞTİR ─────────────────────────────────────────────
  Future<void> _showChangeEmailDialog(
    BuildContext context,
    AdminRepository repo,
    UserProfileModel user,
  ) async {
    final emailController =
        TextEditingController(text: user.email ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.alternate_email_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E-posta Değiştir',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                )),
                            Text(user.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Yeni E-posta Adresi',
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newEmail = emailController.text.trim();
                                if (newEmail.isEmpty || !newEmail.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Geçerli bir e-posta girin.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isSaving = true);
                                try {
                                  await repo.updateUserEmail(
                                    userId: user.id,
                                    newEmail: newEmail,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${user.displayName} e-postası güncellendi.'),
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
                            : const Text('E-postayı Güncelle'),
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

  // ─── DİYALOG: KULLANICI BİLGİLERİNİ DÜZENLE ──────────────────────────────────
  Future<void> _showEditUserDialog(
    BuildContext context,
    AdminRepository repo,
    UserProfileModel user, {
    required List<SchoolModel> schools,
    required bool isSuperAdmin,
  }) async {
    final nameController =
        TextEditingController(text: user.fullName ?? '');
    String selectedRole = user.roleKey;
    String? selectedSchoolId = user.schoolId;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.info, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Kullanıcıyı Düzenle',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: AppColors.textGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.badge_outlined,
                          color: AppColors.textGrey),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Öğretmen')),
                      DropdownMenuItem(
                          value: 'admin',
                          child: Text('Okul Müdürü / Yönetici')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedRole = v ?? 'teacher'),
                  ),
                  if (isSuperAdmin && schools.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSchoolId,
                      decoration: const InputDecoration(
                        labelText: 'Bağlı Olduğu Okul',
                        prefixIcon: Icon(Icons.school_outlined,
                            color: AppColors.textGrey),
                      ),
                      items: schools.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSchoolId = v),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isSaving ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setDialogState(() => isSaving = true);
                                try {
                                  await repo.updateUserProfile(
                                    userId: user.id,
                                    fullName: nameController.text,
                                    role: selectedRole,
                                    schoolId: selectedSchoolId,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Kullanıcı bilgileri güncellendi.'),
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
                            : const Text('Güncelle'),
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

  // ─── KULLANICIYI SİL ────────────────────────────────────────────────────────
  Future<void> _deleteUser(
    BuildContext context,
    AdminRepository repo,
    UserProfileModel user,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Kullanıcıyı Sil',
      content:
          '"${user.displayName}" (${user.email ?? ''}) adlı kullanıcının hesabı kalıcı olarak silinecektir. Bu işlem geri alınamaz!',
      confirmLabel: 'Sil',
      icon: Icons.person_remove_rounded,
    );

    if (confirmed && context.mounted) {
      try {
        await repo.deleteUser(user.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} sistemden silindi.'),
              backgroundColor: AppColors.textDark,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textGrey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
