// lib/presentation/widgets/app_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Genel onay diyaloğu
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Onayla',
  Color confirmColor = AppColors.danger,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: confirmColor, size: 24),
            const SizedBox(width: 10),
          ],
          Text(title),
        ],
      ),
      content: Text(content, style: const TextStyle(color: AppColors.textGrey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tahta düzenleme / eşleştirme diyaloğu
Future<void> showBoardDialog(
  BuildContext context, {
  Map<String, dynamic>? board, // null = yeni eşleştirme
  required String schoolId,
  required Future<void> Function({
    required String pairingCode,
    required String name,
    String? grade,
    String? branch,
    required int autoLockMinutes,
  }) onPair,
  required Future<void> Function({
    required String boardId,
    required String name,
    String? grade,
    String? branch,
    required int autoLockMinutes,
    required bool isActive,
  }) onUpdate,
}) async {
  final isEditing = board != null;
  final nameController = TextEditingController(text: board?['name'] ?? '');
  final gradeController = TextEditingController(text: board?['grade'] ?? '');
  final branchController = TextEditingController(text: board?['branch'] ?? '');
  int autoLockMinutes = board?['auto_lock_minutes'] as int? ?? 15;
  bool isActive = board?['is_active'] as bool? ?? true;
  String pairingCode = '';
  bool isSaving = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_link_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Tahtayı Düzenle' : 'Yeni Tahta Eşleştir',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tahta adı
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tahta Adı (Örn: Sınıf 9A)'),
                  ),
                  const SizedBox(height: 12),

                  // Sınıf ve Şube
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: gradeController,
                          decoration: const InputDecoration(labelText: 'Sınıf (Örn: 9)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: branchController,
                          decoration: const InputDecoration(labelText: 'Şube (Örn: A)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Otomatik kilit süresi
                  DropdownButtonFormField<int>(
                    initialValue: autoLockMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Otomatik Kilit Süresi',
                      prefixIcon: Icon(Icons.timer_rounded, color: AppColors.textGrey),
                    ),
                    items: AppConstants.autoLockOptions.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text('$v dakika'),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => autoLockMinutes = v ?? 15),
                  ),
                  const SizedBox(height: 12),

                  // Aktiflik (sadece düzenleme modunda)
                  if (isEditing)
                    Container(
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: SwitchListTile(
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        title: Text(
                          'Durum: ${isActive ? 'Aktif' : 'Pasif'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.danger,
                          ),
                        ),
                        activeThumbColor: AppColors.success,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ),

                  // Eşleştirme kodu (sadece yeni)
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    Text(
                      '6 Haneli Eşleştirme Kodu',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Akıllı tahtanın ekranında görünen kodu girin.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OtpInput(
                      onCodeChanged: (code) => pairingCode = code,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Butonlar
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
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Tahta adı zorunludur.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }
                                if (!isEditing && pairingCode.length != 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('6 haneli eşleştirme kodunu girin.'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isSaving = true);
                                try {
                                  if (isEditing) {
                                    await onUpdate(
                                      boardId: board['id'] as String,
                                      name: nameController.text,
                                      grade: gradeController.text,
                                      branch: branchController.text,
                                      autoLockMinutes: autoLockMinutes,
                                      isActive: isActive,
                                    );
                                  } else {
                                    await onPair(
                                      pairingCode: pairingCode,
                                      name: nameController.text,
                                      grade: gradeController.text,
                                      branch: branchController.text,
                                      autoLockMinutes: autoLockMinutes,
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
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
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isEditing ? 'Güncelle' : 'Eşleştir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 6 haneli OTP giriş widget'ı
class _OtpInput extends StatefulWidget {
  final Function(String) onCodeChanged;
  const _OtpInput({required this.onCodeChanged});

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (final n in _focusNodes) {
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    final fullCode = _controllers.map((e) => e.text).join();
    widget.onCodeChanged(fullCode);
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 6; i++) ...[
          if (i == 3) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('—',
                style: GoogleFonts.inter(
                    fontSize: 24, color: AppColors.textGrey, fontWeight: FontWeight.w300)),
          ),
          SizedBox(
            width: 44,
            height: 56,
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (v) => _onChanged(v, i),
            ),
          ),
        ],
      ],
    );
  }
}
