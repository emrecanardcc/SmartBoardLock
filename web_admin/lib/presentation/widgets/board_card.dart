// lib/presentation/widgets/board_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/board_model.dart';

class BoardCard extends StatefulWidget {
  final BoardModel board;
  final String? latestVersion;
  final String actorName;
  final Future<void> Function(bool newState) onToggleLock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onRemoteShutdown;
  final bool isSuperAdmin;
  final Future<void> Function()? onRepairIntegrity;

  const BoardCard({
    super.key,
    required this.board,
    this.latestVersion,
    required this.actorName,
    required this.onToggleLock,
    required this.onEdit,
    required this.onDelete,
    required this.onRemoteShutdown,
    this.isSuperAdmin = false,
    this.onRepairIntegrity,
  });

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> {
  bool _isToggling = false;
  bool _isShuttingDown = false;

  Color get _statusColor {
    switch (widget.board.status) {
      case BoardStatus.unlocked:
        return AppColors.success;
      case BoardStatus.locked:
        return AppColors.danger;
      case BoardStatus.inactive:
        return AppColors.offline;
    }
  }

  String get _statusLabel {
    switch (widget.board.status) {
      case BoardStatus.unlocked:
        return 'KULLANIMA AÇIK';
      case BoardStatus.locked:
        return 'KİLİTLİ';
      case BoardStatus.inactive:
        return 'PASİF';
    }
  }

  IconData get _statusIcon {
    switch (widget.board.status) {
      case BoardStatus.unlocked:
        return Icons.lock_open_rounded;
      case BoardStatus.locked:
        return Icons.lock_rounded;
      case BoardStatus.inactive:
        return Icons.block_rounded;
    }
  }

  String get _pingTimeAgo {
    if (widget.board.lastPingAt == null) return 'Henüz bağlanmadı';
    final diff = DateTime.now().toUtc().difference(widget.board.lastPingAt!.toUtc());
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return DateFormat('dd.MM.yy HH:mm').format(widget.board.lastPingAt!.toLocal());
  }

  bool get _isOutdated {
    if (widget.latestVersion == null || widget.board.appVersion == null) return false;
    final current = widget.board.appVersion!.trim().replaceAll('v', '');
    final latest = widget.latestVersion!.trim().replaceAll('v', '');
    return current != latest;
  }

  Future<void> _confirmShutdown() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.power_settings_new_rounded,
                  color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Bilgisayarı Kapat',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          '"${widget.board.name}" akıllı tahtası doğrudan kapatılacak.\n\nÖğretmenin açık dosyaları varsa kaydedilmemiş olabilir. Devam etmek istiyor musunuz?',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.power_settings_new_rounded, size: 16),
            label: const Text('Bilgisayarı Kapat'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isShuttingDown = true);
      try {
        await widget.onRemoteShutdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${widget.board.name}" için kapatma komutu gönderildi.'),
              backgroundColor: AppColors.textDark,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isShuttingDown = false);
      }
    }
  }

  Future<void> _confirmRepairIntegrity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build_circle_rounded,
                  color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Uygulama Bütünlüğünü Onar',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          '"${widget.board.name}" akıllı tahtasındaki tüm uygulama dosyaları (kilit ekranı, bekçi servisi, güncelleyici) sıfırdan indirilerek temizlenip yeniden kurulacaktır.\n\nEşleştirme ve okul ayarları kesinlikle silinmez.\n\nUzaktan onarımı başlatmak istiyor musunuz?',
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.build_circle_rounded, size: 16),
            label: const Text('Bütünlüğü Onar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && widget.onRepairIntegrity != null) {
      try {
        await widget.onRepairIntegrity!();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${widget.board.name}" için onarım komutu başarıyla gönderildi.'),
              backgroundColor: AppColors.textDark,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final canToggle = board.isActive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Kısım: Durum İkonu, İsim, Sınıf ve Popup Menü
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Durum ikonu
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 12),

                // İsim ve Sınıf
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        board.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        board.gradeBranchLabel.isNotEmpty
                            ? board.gradeBranchLabel
                            : 'Sınıf/Şube Belirtilmemiş',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Popup Menü
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textGrey, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  color: AppColors.bgCard,
                  elevation: 8,
                  onSelected: (value) {
                    if (value == 'edit') widget.onEdit();
                    if (value == 'repair') _confirmRepairIntegrity();
                    if (value == 'shutdown') _confirmShutdown();
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_rounded,
                            color: AppColors.info, size: 18),
                        const SizedBox(width: 10),
                        Text('Düzenle',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ]),
                    ),
                    if (widget.isSuperAdmin && board.isOnline && widget.onRepairIntegrity != null)
                      PopupMenuItem(
                        value: 'repair',
                        child: Row(children: [
                          const Icon(Icons.build_circle_rounded,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 10),
                          Text('Bütünlüğü Onar (Sıfırdan)',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning)),
                        ]),
                      ),
                    if (board.isOnline)
                      PopupMenuItem(
                        value: 'shutdown',
                        child: Row(children: [
                          const Icon(Icons.power_settings_new_rounded,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 10),
                          Text('Bilgisayarı Kapat',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.danger)),
                        ]),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.link_off_rounded,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Text('Eşleşmeyi Kaldır',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Rozetler: Kilit Durumu, Bilgisayar Güç Durumu ve Sürüm Rozeti
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Kilit rozeti
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Bilgisayar Güç Durumu Rozeti
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: board.isOnline
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.offline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: board.isOnline
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.offline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: board.isOnline ? AppColors.success : AppColors.offline,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        board.isOnline ? 'CİHAZ AÇIK' : 'CİHAZ KAPALI',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: board.isOnline ? AppColors.success : AppColors.offline,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sürüm Rozeti (varsa)
                if (board.appVersion != null && board.appVersion!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isOutdated
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isOutdated
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _isOutdated
                          ? 'v${board.appVersion} ⚠️ Güncelle'
                          : 'v${board.appVersion} ✓',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isOutdated ? AppColors.warning : AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Bilgi Satırları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: board.isOnline ? Icons.power_rounded : Icons.power_off_rounded,
                  label: 'Cihaz Durumu',
                  value: board.isOnline
                      ? 'Çalışıyor ($_pingTimeAgo)'
                      : 'Kapalı ($_pingTimeAgo)',
                  color: board.isOnline ? AppColors.success : AppColors.offline,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: board.isUnlocked
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  label: board.isUnlocked ? 'Kullanımda' : 'Son Kitleyen',
                  value: board.isUnlocked
                      ? (board.lastUnlockedBy ?? 'Öğretmen')
                      : (board.lastLockedBy ?? 'Yönetici'),
                  color: board.isUnlocked ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Oto Kilit',
                  value: '${board.autoLockMinutes} dakika',
                  color: AppColors.textGrey,
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.system_update_rounded,
                  label: 'Uygulama Sürümü',
                  value: board.appVersion != null && board.appVersion!.isNotEmpty
                      ? (_isOutdated
                          ? 'v${board.appVersion} (Güncel: v${widget.latestVersion ?? '?'})'
                          : 'v${board.appVersion} (Güncel)')
                      : 'Bilinmiyor / Eski Sürüm',
                  color: _isOutdated ? AppColors.warning : AppColors.textMedium,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Alt Aksiyon: Kilitle / Kilidi Aç Butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !canToggle
                            ? AppColors.bgCardHover
                            : board.isUnlocked
                                ? AppColors.textDark
                                : AppColors.success,
                        foregroundColor: !canToggle
                            ? AppColors.textGrey
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isToggling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              !canToggle
                                  ? Icons.block_rounded
                                  : board.isUnlocked
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                              size: 18,
                            ),
                      label: Text(
                        !canToggle
                            ? 'Pasif'
                            : (board.isUnlocked ? 'Kilitle' : 'Kilidi Aç'),
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      onPressed: canToggle && !_isToggling
                          ? () async {
                              setState(() => _isToggling = true);
                              try {
                                await widget.onToggleLock(!board.isUnlocked);
                              } finally {
                                if (mounted) setState(() => _isToggling = false);
                              }
                            }
                          : null,
                    ),
                  ),
                ),
                if (board.isOnline) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    width: 44,
                    child: Tooltip(
                      message: 'Bilgisayarı Kapat',
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                          foregroundColor: AppColors.danger,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        onPressed: _isShuttingDown ? null : _confirmShutdown,
                        child: _isShuttingDown
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: AppColors.danger,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.power_settings_new_rounded, size: 20),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
