// lib/presentation/widgets/board_password_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/admin_repository.dart';

/// Okul müdürünün akıllı tahtalar için program kurma/silme güvenlik şifresini belirlemesini sağlayan diyalog
Future<String?> showBoardSecurityPasswordDialog(
  BuildContext context, {
  required String schoolId,
  String? currentPassword,
}) async {
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BoardPasswordDialogContent(
      schoolId: schoolId,
      initialPassword: currentPassword,
    ),
  );

  return result;
}

class _BoardPasswordDialogContent extends StatefulWidget {
  final String schoolId;
  final String? initialPassword;

  const _BoardPasswordDialogContent({
    required this.schoolId,
    this.initialPassword,
  });

  @override
  State<_BoardPasswordDialogContent> createState() => _BoardPasswordDialogContentState();
}

class _BoardPasswordDialogContentState extends State<_BoardPasswordDialogContent> {
  late final TextEditingController _controller;
  bool _obscureText = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _isLoadingCurrent = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPassword ?? '');
    if (widget.initialPassword == null) {
      _loadCurrentPassword();
    }
  }

  Future<void> _loadCurrentPassword() async {
    setState(() => _isLoadingCurrent = true);
    try {
      final repo = context.read<AdminRepository>();
      final school = await repo.getSchoolById(widget.schoolId);
      if (school != null && mounted) {
        setState(() {
          _controller.text = school.boardAdminPassword ?? '';
          _isLoadingCurrent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCurrent = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Şifre alanı boş bırakılamaz.');
      return;
    }

    if (password.length < 4) {
      setState(() => _errorMessage = 'Güvenlik şifresi en az 4 karakter olmalıdır.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AdminRepository>();
      await repo.updateSchoolBoardAdminPassword(
        schoolId: widget.schoolId,
        password: password,
      );

      if (mounted) {
        Navigator.pop(context, password);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahta kurulum/silme güvenlik şifresi başarıyla kaydedildi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Şifre kaydedilemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Müdür Tahta Güvenlik Şifresi',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Program Kurma ve Kaldırma Koruması',
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
                    onPressed: _isSaving ? null : () => Navigator.pop(context, null),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Bilgi Kutusu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu şifre, öğrencilerin ve yetkisiz kişilerin akıllı tahtaya oyun veya program kurmasını '
                        '(setup.exe, install.exe, msiexec) ve sistemdeki programları kaldırmasını önler. '
                        'Tahtada kurulum başlatıldığında ekranda bu şifre istenecektir.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Şifre Giriş Alanı
              Text(
                'Müdür Güvenlik PIN / Şifresi',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                enabled: !_isSaving && !_isLoadingCurrent,
                decoration: InputDecoration(
                  hintText: 'Örn: 2468 veya GizliSifre360',
                  filled: true,
                  fillColor: AppColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, null),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_isSaving ? 'Kaydediliyor...' : 'Şifreyi Kaydet'),
                    onPressed: _isSaving || _isLoadingCurrent ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
