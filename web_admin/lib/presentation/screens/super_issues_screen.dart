// lib/presentation/screens/super_issues_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/support_ticket_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../widgets/kpi_card.dart';
import '../widgets/app_dialog.dart';

class SuperIssuesScreen extends StatefulWidget {
  const SuperIssuesScreen({super.key});

  @override
  State<SuperIssuesScreen> createState() => _SuperIssuesScreenState();
}

class _SuperIssuesScreenState extends State<SuperIssuesScreen> {
  List<SupportTicketModel> _allTickets = [];
  Map<String, String> _schoolMap = {};
  bool _isLoading = true;
  String _statusFilter = 'Tümü';
  String _categoryFilter = 'Tümü';
  String _searchQuery = '';
  StreamSubscription<List<SupportTicketModel>>? _sub;

  final List<String> _categoryOptions = [
    'Tümü',
    'QR / Kilit Açılmıyor',
    'Tahta Çevrimdışı',
    'Afiş & Yayın Sorunu',
    'Donanım / Ses / Görüntü',
    'Uygulama Hatası',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = context.read<AdminRepository>();

    try {
      final schools = await repo.getSchools();
      _schoolMap = {for (final s in schools) s.id: s.name};
    } catch (_) {}

    try {
      final initial = await repo.getSupportTickets();
      if (mounted) {
        setState(() {
          _allTickets = initial;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('getSupportTickets initial error: $e');
      if (mounted) setState(() => _isLoading = false);
    }

    // Realtime stream
    await _sub?.cancel();
    _sub = repo.streamSupportTickets().listen(
      (live) {
        if (mounted) {
          setState(() {
            _allTickets = live;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        debugPrint('streamSupportTickets error: $e');
      },
    );
  }

  List<SupportTicketModel> get _filteredTickets {
    var list = _allTickets;

    if (_statusFilter != 'Tümü') {
      final mappedStatus = switch (_statusFilter) {
        'Yeni / Beklemede' => 'pending',
        'İnceleniyor' => 'in_progress',
        'Çözüldü' => 'resolved',
        'Reddedildi' => 'rejected',
        _ => _statusFilter,
      };
      list = list.where((t) => t.status == mappedStatus).toList();
    }

    if (_categoryFilter != 'Tümü') {
      list = list.where((t) => t.category == _categoryFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final schoolName = (_schoolMap[t.schoolId] ?? t.schoolName ?? '').toLowerCase();
        return t.description.toLowerCase().contains(q) ||
            t.reporterName.toLowerCase().contains(q) ||
            (t.boardName?.toLowerCase().contains(q) ?? false) ||
            schoolName.contains(q);
      }).toList();
    }

    return list;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return AppColors.info;
      case 'resolved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  void _openTicketDetailModal(SupportTicketModel ticket) {
    String currentStatus = ticket.status;
    final notesController = TextEditingController(text: ticket.adminNotes ?? '');
    bool isSaving = false;
    final schoolName = _schoolMap[ticket.schoolId] ?? ticket.schoolName ?? 'Bilinmeyen Okul';
    final repo = context.read<AdminRepository>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sorun Bildirimi Detayı',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textDark)),
                    Text('$schoolName • ${DateFormat('dd.MM.yyyy HH:mm').format(ticket.createdAt)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textGrey)),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta bilgiler kartı
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.school_rounded, 'Okul', schoolName),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.person_rounded,
                          'Bildiren',
                          '${ticket.reporterName} (${ticket.roleLabel})',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.tv_rounded,
                          'İlgili Tahta',
                          ticket.boardName != null && ticket.boardName!.isNotEmpty
                              ? ticket.boardName!
                              : 'Genel Sorun (Tahta Seçilmemiş)',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.category_rounded, 'Kategori', ticket.category),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text('Kullanıcı Açıklaması',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      ticket.description,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.textDark),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Durum Güncelle',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStatusSelectChip('pending', 'Yeni / Beklemede', currentStatus, (s) => setModalState(() => currentStatus = s)),
                      _buildStatusSelectChip('in_progress', 'İnceleniyor', currentStatus, (s) => setModalState(() => currentStatus = s)),
                      _buildStatusSelectChip('resolved', 'Çözüldü', currentStatus, (s) => setModalState(() => currentStatus = s)),
                      _buildStatusSelectChip('rejected', 'Reddedildi', currentStatus, (s) => setModalState(() => currentStatus = s)),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text('Geliştirici & Teknik Destek Ekibi Çözüm Notu / Açıklaması',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Yapılan işlem veya bilgilendirme notu girin...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text('Kaydet ve Güncelle'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      try {
                        await repo.updateTicketStatus(
                          ticketId: ticket.id,
                          status: currentStatus,
                          adminNotes: notesController.text,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sorun durumu başarıyla güncellendi.'), backgroundColor: AppColors.success),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Güncelleme hatası: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textGrey),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGrey)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelectChip(String key, String label, String currentKey, ValueChanged<String> onSelect) {
    final isSelected = key == currentKey;
    final color = _getStatusColor(key);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(key),
      backgroundColor: Colors.white,
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textGrey,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? color : AppColors.border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTickets;
    final total = _allTickets.length;
    final pending = _allTickets.where((t) => t.status == 'pending').length;
    final inProgress = _allTickets.where((t) => t.status == 'in_progress').length;
    final resolved = _allTickets.where((t) => t.status == 'resolved').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık alanı
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sorun Bildirimleri & Destek Masası',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Öğretmenler ve müdürler tarafından bildirilen teknik arızalar',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
                tooltip: 'Yenile',
                onPressed: _loadData,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // KPI Kartları
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LayoutBuilder(builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 48) / 4;
            return Row(
              children: [
                SizedBox(
                  width: itemWidth,
                  child: KpiCard(
                    title: 'Toplam Bildirim',
                    value: total.toString(),
                    icon: Icons.support_agent_rounded,
                    color: AppColors.info,
                    subtitle: 'Gelen tüm talepler',
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: itemWidth,
                  child: KpiCard(
                    title: 'Yeni / Beklemede',
                    value: pending.toString(),
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                    subtitle: 'İnceleme bekliyor',
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: itemWidth,
                  child: KpiCard(
                    title: 'İnceleniyor',
                    value: inProgress.toString(),
                    icon: Icons.hourglass_top_rounded,
                    color: AppColors.primary,
                    subtitle: 'İşlemdeki kayıtlar',
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: itemWidth,
                  child: KpiCard(
                    title: 'Çözülen Talepler',
                    value: resolved.toString(),
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                    subtitle: 'Tamamlandı',
                  ),
                ),
              ],
            );
          }),
        ),

        const SizedBox(height: 20),

        // Filtre Barı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Arama
              SizedBox(
                width: 240,
                height: 42,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Açıklama, öğretmen veya okul ara...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    filled: true,
                    fillColor: AppColors.bgCard,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
              ),

              // Durum Çipleri
              for (final st in ['Tümü', 'Yeni / Beklemede', 'İnceleniyor', 'Çözüldü', 'Reddedildi'])
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _statusFilter = st),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusFilter == st ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _statusFilter == st ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      st,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _statusFilter == st ? FontWeight.w700 : FontWeight.w500,
                        color: _statusFilter == st ? AppColors.primary : AppColors.textGrey,
                      ),
                    ),
                  ),
                ),

              // Kategori Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categoryFilter,
                    icon: const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textGrey),
                    style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600),
                    items: _categoryOptions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c == 'Tümü' ? 'Tüm Kategoriler' : c)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryFilter = v ?? 'Tümü'),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Liste / Tablo
        Expanded(
          child: _isLoading && _allTickets.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 54, color: AppColors.textLight),
                          const SizedBox(height: 14),
                          Text(
                            _allTickets.isEmpty
                                ? 'Şu anda bekleyen veya çözülen sorun bildirimi bulunmuyor.'
                                : 'Arama kriterlerine uygun bildirim bulunamadı.',
                            style: GoogleFonts.inter(color: AppColors.textGrey, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ticket = filtered[index];
                        final schoolName = _schoolMap[ticket.schoolId] ?? ticket.schoolName ?? 'Bilinmeyen Okul';
                        final statusColor = _getStatusColor(ticket.status);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kategori İkonu
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  ticket.category.contains('Kilit') || ticket.category.contains('QR')
                                      ? Icons.qr_code_scanner_rounded
                                      : ticket.category.contains('Çevrimdışı')
                                          ? Icons.wifi_off_rounded
                                          : ticket.category.contains('Afiş')
                                              ? Icons.campaign_rounded
                                              : ticket.category.contains('Donanım')
                                                  ? Icons.speaker_group_rounded
                                                  : Icons.error_outline_rounded,
                                  color: statusColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Orta İçerik
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Okul Rozeti
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            schoolName,
                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Tahta Adı
                                        if (ticket.boardName != null && ticket.boardName!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.bgPage,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              ticket.boardName!,
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                            ),
                                          ),
                                        const Spacer(),

                                        // Durum Rozeti
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                ticket.statusLabel,
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Bildiren & Kategori
                                    Text(
                                      '${ticket.reporterName} (${ticket.roleLabel}) • ${ticket.category}',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                                    ),
                                    const SizedBox(height: 4),

                                    // Açıklama
                                    Text(
                                      ticket.description,
                                      style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: AppColors.textDark),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    if (ticket.adminNotes != null && ticket.adminNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgPage,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Çözüm Notu: ${ticket.adminNotes}',
                                                style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMedium),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Aksiyonlar
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.visibility_rounded, size: 14),
                                    label: const Text('İncele'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: () => _openTicketDetailModal(ticket),
                                  ),
                                  const SizedBox(height: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                    tooltip: 'Bildirimi Sil',
                                    onPressed: () async {
                                      final confirmed = await showConfirmDialog(
                                        context,
                                        title: 'Bildirimi Sil',
                                        content: 'Bu sorun bildirimi kaydı kalıcı olarak silinecektir. Onaylıyor musunuz?',
                                        confirmLabel: 'Sil',
                                        icon: Icons.delete_outline_rounded,
                                      );
                                      if (confirmed && context.mounted) {
                                        await context.read<AdminRepository>().deleteSupportTicket(ticket.id);
                                        _loadData();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
