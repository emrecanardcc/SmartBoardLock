import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportIssueDialog extends StatefulWidget {
  final String schoolId;
  final String? initialBoardId;
  final String? initialBoardName;
  final List<Map<String, dynamic>> availableBoards;
  final String userRole; // 'teacher' or 'school_admin'
  final String userName;

  const ReportIssueDialog({
    super.key,
    required this.schoolId,
    this.initialBoardId,
    this.initialBoardName,
    this.availableBoards = const [],
    required this.userRole,
    required this.userName,
  });

  static Future<void> show(
    BuildContext context, {
    required String schoolId,
    String? initialBoardId,
    String? initialBoardName,
    List<Map<String, dynamic>> availableBoards = const [],
    required String userRole,
    required String userName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ReportIssueDialog(
          schoolId: schoolId,
          initialBoardId: initialBoardId,
          initialBoardName: initialBoardName,
          availableBoards: availableBoards,
          userRole: userRole,
          userName: userName,
        ),
      ),
    );
  }

  @override
  State<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<ReportIssueDialog> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedCategory = 'board_app';
  String? _selectedBoardId;
  bool _isSubmitting = false;

  final Map<String, Map<String, dynamic>> _categories = {
    'board_app': {
      'label': 'Tahta Kilit / Kiosk Uygulaması',
      'icon': Icons.desktop_windows_rounded,
      'color': Color(0xFF3B82F6),
    },
    'hardware': {
      'label': 'Donanım / Dokunmatik / Ekran',
      'icon': Icons.touch_app_rounded,
      'color': Color(0xFFF59E0B),
    },
    'network': {
      'label': 'İnternet / Ağ Bağlantısı',
      'icon': Icons.wifi_off_rounded,
      'color': Color(0xFF8B5CF6),
    },
    'qr_totp': {
      'label': 'QR Kod / TOTP ile Kilit Açma',
      'icon': Icons.qr_code_scanner_rounded,
      'color': Color(0xFF10B981),
    },
    'broadcast': {
      'label': 'Afiş / Duyuru / Yayın Ekranı',
      'icon': Icons.campaign_rounded,
      'color': Color(0xFFEC4899),
    },
    'other': {
      'label': 'Diğer / Sistem Önerisi',
      'icon': Icons.help_outline_rounded,
      'color': Color(0xFF64748B),
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedBoardId = widget.initialBoardId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum açmış kullanıcı bulunamadı.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ticketData = <String, dynamic>{
        'school_id': widget.schoolId,
        'board_id': _selectedBoardId,
        'user_id': user.id,
        'user_name': widget.userName,
        'user_role': widget.userRole,
        'category': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'status': 'pending',
      };

      await _client.from('support_tickets').insert(ticketData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sorun bildirimi Süper Admin ekibine iletildi. En kısa sürede incelenecektir.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Bildirim gönderilemedi: $e', style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bug_report_rounded, color: Color(0xFFF43F5E), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sorun / Arıza Bildir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Süper Admin teknik destek paneline doğrudan iletilir',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori Seçimi
                    const Text(
                      'Sorun Kategorisi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: _categories.entries.map((e) {
                            final cat = e.value;
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Row(
                                children: [
                                  Icon(cat['icon'] as IconData, size: 18, color: cat['color'] as Color),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      cat['label'] as String,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tahta Seçimi (Opsiyonel veya Genel)
                    const Text(
                      'İlgili Akıllı Tahta (İsteğe Bağlı)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedBoardId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.school_rounded, size: 18, color: Color(0xFF64748B)),
                                  SizedBox(width: 10),
                                  Text('Genel Okul / Sistem Sorunu', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            ...widget.availableBoards.map((b) {
                              final name = b['name'] ?? 'Tahta';
                              final grade = b['grade'] != null && b['grade'].toString().isNotEmpty ? "${b['grade']}. Sınıf " : "";
                              final branch = b['branch'] ?? "";
                              return DropdownMenuItem<String?>(
                                value: b['id'] as String,
                                child: Row(
                                  children: [
                                    const Icon(Icons.tv_rounded, size: 18, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '$name ($grade$branch)'.trim(),
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedBoardId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Başlık
                    const Text(
                      'Sorun Başlığı',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: 'Örn: 9-A tahtası kilit açılmıyor veya QR okumuyor',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Lütfen bir başlık girin';
                        if (val.trim().length < 5) return 'En az 5 karakter yazın';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Detaylı Açıklama
                    const Text(
                      'Açıklama ve Detaylar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Sorunun tam olarak ne zaman başladığını, ekranda beliren uyarıyı veya detayları açıklayın...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Lütfen açıklama girin';
                        if (val.trim().length < 10) return 'Lütfen en az 10 karakter ile açıklayın';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          _isSubmitting ? 'Gönderiliyor...' : 'Sorun Bildirimini Gönder',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSubmitting ? null : _submitTicket,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
