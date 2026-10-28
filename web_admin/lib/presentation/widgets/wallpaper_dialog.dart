// lib/presentation/widgets/wallpaper_dialog.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/board_model.dart';
import '../../data/repositories/admin_repository.dart';

/// Akıllı tahtalara uzaktan masaüstü duvar kâğıdı yükleyip gönderme diyaloğu
Future<bool> showWallpaperDialog(
  BuildContext context, {
  required List<BoardModel> targetBoards,
}) async {
  if (targetBoards.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Duvar kâğıdı gönderilecek tahta bulunamadı.'),
        backgroundColor: AppColors.warning,
      ),
    );
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _WallpaperDialogContent(targetBoards: targetBoards),
  );

  return result ?? false;
}

class _WallpaperDialogContent extends StatefulWidget {
  final List<BoardModel> targetBoards;

  const _WallpaperDialogContent({required this.targetBoards});

  @override
  State<_WallpaperDialogContent> createState() => _WallpaperDialogContentState();
}

class _WallpaperDialogContentState extends State<_WallpaperDialogContent> {
  Uint8List? _imageBytes;
  String? _fileName;
  String _selectedStyle = 'fill';
  bool _isUploading = false;
  String? _errorMessage;

  final List<Map<String, String>> _styleOptions = [
    {'value': 'fill', 'label': 'Tam Ekran Kapla (Aspect-Fill, Önerilen)'},
    {'value': 'fit', 'label': 'Ekrana Sığdır (Fit)'},
    {'value': 'stretch', 'label': 'Ekrana Yay (Stretch)'},
  ];

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          setState(() {
            _imageBytes = file.bytes;
            _fileName = file.name;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Görsel seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (_imageBytes == null || _fileName == null) {
      setState(() {
        _errorMessage = 'Lütfen bir duvar kâğıdı görseli seçiniz.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AdminRepository>();
      final boardIds = widget.targetBoards.map((b) => b.id).toList();

      await repo.sendBulkWallpaperCommand(
        boardIds: boardIds,
        imageBytes: _imageBytes!,
        fileName: _fileName!,
        style: _selectedStyle,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.targetBoards.length} akıllı tahtaya yeni duvar kâğıdı komutu iletildi.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Duvar kâğıdı gönderilemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                    child: const Icon(Icons.wallpaper_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masaüstü Duvar Kâğıdı Ayarla',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${widget.targetBoards.length} adet akıllı tahtaya uzaktan uygulanacaktır',
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
                    onPressed: _isUploading ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const Divider(height: 28),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
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

              // Görsel Seçim Alanı
              if (_imageBytes == null) ...[
                InkWell(
                  onTap: _isUploading ? null : _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded, size: 40, color: AppColors.primary),
                        const SizedBox(height: 10),
                        Text(
                          'Görsel Seçmek İçin Tıklayın',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PNG, JPG, JPEG (Önerilen Çözünürlük: 1920x1080 Full HD)',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Önizleme Alanı
                Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          _imageBytes!,
                          fit: _selectedStyle == 'fill'
                              ? BoxFit.cover
                              : (_selectedStyle == 'fit' ? BoxFit.contain : BoxFit.fill),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                            tooltip: 'Farklı Görsel Seç',
                            onPressed: _isUploading ? null : _pickImage,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: Colors.black.withValues(alpha: 0.65),
                          child: Text(
                            _fileName ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Yerleşim Stili Seçici
              Text(
                'Duvar Kâğıdı Yerleşim Stili',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStyle,
                    isExpanded: true,
                    items: _styleOptions
                        .map((opt) => DropdownMenuItem<String>(
                              value: opt['value'],
                              child: Text(opt['label']!, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: _isUploading
                        ? null
                        : (val) {
                            if (val != null) setState(() => _selectedStyle = val);
                          },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUploading ? null : () => Navigator.pop(context, false),
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
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isUploading ? 'Gönderiliyor...' : 'Duvar Kâğıdını Uygula',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _isUploading || _imageBytes == null ? null : _submit,
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
