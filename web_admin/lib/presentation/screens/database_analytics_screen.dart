// lib/presentation/screens/database_analytics_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/database_analytics_model.dart';
import '../../data/repositories/admin_repository.dart';

class DatabaseAnalyticsScreen extends StatefulWidget {
  const DatabaseAnalyticsScreen({super.key});

  @override
  State<DatabaseAnalyticsScreen> createState() => _DatabaseAnalyticsScreenState();
}

class _QpsPoint {
  final DateTime time;
  final double qps;
  final int activeConnections;
  const _QpsPoint(this.time, this.qps, this.activeConnections);
}

class _DatabaseAnalyticsScreenState extends State<DatabaseAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AdminRepository _repository;
  late final TabController _tabController;

  DatabaseAnalyticsModel? _analytics;
  bool _isLoading = true;
  bool _isAutoRefresh = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  DateTime? _lastFetchTime;
  int? _prevTotalCalls;
  double _currentQps = 0.0;

  final List<_QpsPoint> _qpsHistory = [];
  static const int _maxQpsHistoryLength = 30;

  String _tableSearchQuery = '';
  bool _showSlowestQueries = true;
  final Set<String> _analyzingTables = {};

  @override
  void initState() {
    super.initState();
    _repository = context.read<AdminRepository>();
    _tabController = TabController(length: 5, vsync: this);
    _fetchAnalytics(initial: true);
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isAutoRefresh && mounted) {
        _fetchAnalytics(initial: false);
      }
    });
  }

  Future<void> _fetchAnalytics({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final now = DateTime.now();
      final data = await _repository.getDatabaseAnalytics();

      if (!mounted) return;

      // QPS hesaplama (delta calls / elapsed seconds)
      double calculatedQps = 0.0;
      if (_lastFetchTime != null && _prevTotalCalls != null) {
        final elapsedSec =
            now.difference(_lastFetchTime!).inMilliseconds / 1000.0;
        final deltaCalls = data.queryStats.totalCalls - _prevTotalCalls!;
        if (elapsedSec > 0 && deltaCalls >= 0) {
          calculatedQps = deltaCalls / elapsedSec;
        }
      }
      _lastFetchTime = now;
      _prevTotalCalls = data.queryStats.totalCalls;
      _currentQps = calculatedQps;

      // History listesini güncelle
      _qpsHistory.add(_QpsPoint(
        now,
        _currentQps,
        data.connectionPool.activeConnections,
      ));
      if (_qpsHistory.length > _maxQpsHistoryLength) {
        _qpsHistory.removeAt(0);
      }

      setState(() {
        _analytics = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Veritabanı analitiği alınamadı: $e';
        });
      }
    }
  }

  Future<void> _triggerAnalyze(String tableName) async {
    setState(() => _analyzingTables.add(tableName));
    try {
      final success = await _repository.triggerTableAnalyze(tableName);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $tableName tablosu başarıyla optimize edildi (ANALYZE tamamlandı)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAnalytics(initial: false);
      } else {
        throw Exception('İşlem tamamlanamadı');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Optimize hatası: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _analyzingTables.remove(tableName));
      }
    }
  }

  Future<void> _killProcess(int pid, String query) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('İşlemi Sonlandır (Kill PID)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PID: $pid numaralı aktif oturumu zorla sonlandırmak istediğinize emin misiniz?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                query.isNotEmpty ? query : '<idle>',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE2E8F0),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oturumu Sonlandır'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _repository.cancelBackendProcess(pid);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PID $pid oturumu başarıyla sonlandırıldı.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAnalytics(initial: false);
      } else {
        throw Exception('PID sonlandırılamadı veya oturum zaten kapandı.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.restart_alt_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Sayaçları Sıfırla'),
          ],
        ),
        content: const Text(
          'PostgreSQL sorgu istatistikleri ve pg_stat_statements sayaçları sıfırlanacaktır. Bu işlem birikmiş metrikleri temizler ve sayaçları bugünden itibaren yeniden başlatır. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sayaçları Sıfırla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _repository.resetDatabaseStats();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PostgreSQL istatistik sayaçları sıfırlandı.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAnalytics(initial: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sayaç sıfırlama hatası: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 $label panoya kopyalandı'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Veritabanı telemetri verileri yükleniyor...',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _analytics == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _fetchAnalytics(initial: true),
              ),
            ],
          ),
        ),
      );
    }

    final data = _analytics!;
    final numFormat = NumberFormat('#,##0', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Başlık & Aksiyon Çubuğu
            _buildHeader(data),
            const SizedBox(height: 20),

            // 6 Hero KPI Kartı
            _buildHeroCards(data, numFormat),
            const SizedBox(height: 24),

            // Realtime QPS Streaming Grafiği (Heartbeat Chart)
            _buildRealtimeChartCard(),
            const SizedBox(height: 24),

            // 5 Detaylı Sekme
            _buildTabSection(data, numFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DatabaseAnalyticsModel data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Veritabanı & Telemetri Analitiği',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isAutoRefresh
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.textGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isAutoRefresh ? AppColors.success : AppColors.textGrey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isAutoRefresh ? 'CANLI AKIŞ (3 sn)' : 'DURAKLATILDI',
                            style: TextStyle(
                              color: _isAutoRefresh ? AppColors.success : AppColors.textGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'PostgreSQL 17.6 (Oracle Always Free) • Uptime: ${data.serverHealth.uptimePretty} • Son Güncelleme: ${DateFormat('HH:mm:ss').format(_lastFetchTime ?? DateTime.now())}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Aksiyon Butonları
          Wrap(
            spacing: 10,
            children: [
              // Otomatik Yenileme Switch
              Tooltip(
                message: _isAutoRefresh
                    ? 'Canlı Akışı Duraklat'
                    : 'Canlı Akışı Başlat (Her 3 saniyede otomatik yeniler)',
                child: OutlinedButton.icon(
                  icon: Icon(
                    _isAutoRefresh ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(_isAutoRefresh ? 'Duraklat' : 'Devam Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isAutoRefresh ? AppColors.textMedium : AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() => _isAutoRefresh = !_isAutoRefresh);
                  },
                ),
              ),
              // Sayaçları Sıfırla
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.warning),
                label: const Text('Sayaçları Sıfırla'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMedium,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _resetStats,
              ),
              // Manuel Yenile
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMedium,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _fetchAnalytics(initial: false),
              ),
              // ⚡ Studio Panelini Aç Butonu
              ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFACC15)),
                label: const Text(
                  '⚡ Veritabanı Studio',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () async {
                  final uri = Uri.parse(AppConstants.studioLaunchUrl);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCards(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
                ? 3
                : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            // 1. Toplam İstek & QPS
            _buildKpiCard(
              title: 'Toplam İstek & QPS',
              value: numFormat.format(data.queryStats.totalCalls),
              subValue: '⚡ Canlı: ~${_currentQps.toStringAsFixed(1)} req/s',
              footer: '${data.queryStats.totalQueriesTracked} tekil sorgu',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFF59E0B),
            ),
            // 2. Bağlantı Havuzu
            _buildKpiCard(
              title: 'Bağlantı Havuzu',
              value: '${data.connectionPool.activeConnections} Aktif',
              subValue: '${data.connectionPool.totalConnections} / ${data.connectionPool.maxConnections} Toplam',
              footer: 'Boşta: ${data.connectionPool.idleConnections} • Bekleyen: ${data.connectionPool.waitingConnections}',
              icon: Icons.hub_rounded,
              color: const Color(0xFF3B82F6),
              progress: data.connectionPool.usagePercent / 100.0,
            ),
            // 3. Önbellek İsabet Oranı
            _buildKpiCard(
              title: 'Önbellek İsabet (Cache)',
              value: '%${data.cacheHitRatio.ratioPercent.toStringAsFixed(2)}',
              subValue: 'RAM: ${numFormat.format(data.cacheHitRatio.blksHit)}',
              footer: 'Disk Okuma: ${numFormat.format(data.cacheHitRatio.blksRead)}',
              icon: Icons.memory_rounded,
              color: const Color(0xFF10B981),
            ),
            // 4. Ortalama Gecikme
            _buildKpiCard(
              title: 'Ortalama Gecikme',
              value: '${data.queryStats.avgLatencyMs.toStringAsFixed(3)} ms',
              subValue: 'Hızlı Alt-Milisecond',
              footer: 'Toplam: ${(data.queryStats.totalExecTimeMs / 1000).toStringAsFixed(1)} sn CPU',
              icon: Icons.speed_rounded,
              color: const Color(0xFF0D9488),
            ),
            // 5. Veritabanı Boyutu
            _buildKpiCard(
              title: 'Depolama Boyutu',
              value: data.serverHealth.databaseSizePretty,
              subValue: 'PostgreSQL 17.6',
              footer: 'Oracle Block Storage',
              icon: Icons.folder_special_rounded,
              color: const Color(0xFF8B5CF6),
            ),
            // 6. İşlem Başarısı (TPS)
            _buildKpiCard(
              title: 'İşlem Başarısı (TPS)',
              value: '%${data.transactions.successRate.toStringAsFixed(2)}',
              subValue: 'Commit: ${numFormat.format(data.transactions.xactCommit)}',
              footer: 'Rollback: ${numFormat.format(data.transactions.xactRollback)}',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF6366F1),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subValue,
    required String footer,
    required IconData icon,
    required Color color,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  subValue,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            footer,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeChartCard() {
    final maxQps = _qpsHistory.isEmpty
        ? 10.0
        : math.max(10.0, _qpsHistory.map((p) => p.qps).reduce(math.max) * 1.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate for heart-beat terminal chart
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Canlı İstek & TPS Dalga Monitörü (Realtime Telemetri)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: Color(0xFFFACC15)),
                    const SizedBox(width: 6),
                    Text(
                      'Anlık: ${_currentQps.toStringAsFixed(1)} req/s',
                      style: const TextStyle(
                        color: Color(0xFFFACC15),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: _qpsHistory.length < 2
                ? const Center(
                    child: Text(
                      'Canlı telemetri akışı bekleniyor...',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                : CustomPaint(
                    painter: _StreamingChartPainter(
                      points: _qpsHistory,
                      maxVal: maxQps,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '← 90 saniye önce',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
              Text(
                'Pencereler: 3 sn örnekleme • Maks: ${maxQps.toStringAsFixed(1)} req/s',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
              const Text(
                'Şimdi (Canlı) →',
                style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textGrey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.table_chart_rounded, size: 18), text: 'Tablolar & Depolama'),
              Tab(icon: Icon(Icons.code_rounded, size: 18), text: 'Sorgu Analitiği'),
              Tab(icon: Icon(Icons.dns_rounded, size: 18), text: 'Canlı İşlemler & Kilit Monitörü'),
              Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: '14 Günlük İstek Geçmişi'),
              Tab(icon: Icon(Icons.terminal_rounded, size: 18), text: 'Bağlantı & Konsol Bilgisi'),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableStatsTab(data, numFormat),
                _buildQueryStatsTab(data, numFormat),
                _buildLiveProcessesTab(data),
                _buildDailyHistoryTab(data, numFormat),
                _buildConnectionInfoTab(data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Tablo & Depolama Analizi
  Widget _buildTableStatsTab(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final filteredTables = data.tableStats.where((t) {
      if (_tableSearchQuery.isEmpty) return true;
      return t.tableName.toLowerCase().contains(_tableSearchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tablo ara (örn: boards, schools, user_profiles)...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textGrey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (val) => setState(() => _tableSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Toplam ${data.tableStats.length} tablo',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Tablo Adı', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Satır Sayısı', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Ölü Satır', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Şişkinlik (Bloat)', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Toplam Boyut', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Tablo Boyutu', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('İndeks Boyutu', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Sıralı / İndeks Tarama', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: filteredTables.map((t) {
                    final isAnalyzing = _analyzingTables.contains(t.tableName);

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                t.tableName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(numFormat.format(t.rowCount))),
                        DataCell(Text(
                          numFormat.format(t.deadRowCount),
                          style: TextStyle(
                            color: t.deadRowCount > 100 ? AppColors.warning : AppColors.textDark,
                            fontWeight: t.deadRowCount > 100 ? FontWeight.w700 : FontWeight.w400,
                          ),
                        )),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.bloatRatio > 25
                                  ? AppColors.warning.withValues(alpha: 0.15)
                                  : AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '%${t.bloatRatio.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: t.bloatRatio > 25 ? AppColors.warning : AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(t.totalSizePretty, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${(t.tableSizeBytes / 1024).toStringAsFixed(0)} kB')),
                        DataCell(Text('${(t.indexSizeBytes / 1024).toStringAsFixed(0)} kB')),
                        DataCell(Text(
                          'Seq: ${numFormat.format(t.seqScans)} / Idx: ${numFormat.format(t.indexScans)}',
                          style: const TextStyle(fontSize: 11),
                        )),
                        DataCell(
                          isAnalyzing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : OutlinedButton.icon(
                                  icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                                  label: const Text('Optimize (Analyze)'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () => _triggerAnalyze(t.tableName),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Sorgu Analitiği
  Widget _buildQueryStatsTab(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final queries = _showSlowestQueries ? data.slowestQueries : data.frequentQueries;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('En Çok Zaman Alan Sorgular (En Yavaş)'),
                    icon: Icon(Icons.timer_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('En Sık Çalıştırılan Sorgular (Trafik)'),
                    icon: Icon(Icons.repeat_rounded, size: 16),
                  ),
                ],
                selected: {_showSlowestQueries},
                onSelectionChanged: (val) {
                  setState(() => _showSlowestQueries = val.first);
                },
              ),
              const Spacer(),
              Text(
                'pg_stat_statements izlemesi • ${queries.length} sorgu listelendi',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: queries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final q = queries[index];

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _showSlowestQueries
                                  ? const Color(0xFFF43F5E).withValues(alpha: 0.2)
                                  : const Color(0xFF0D9488).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}  •  ${q.meanExecTime.toStringAsFixed(2)} ms / sorgu',
                              style: TextStyle(
                                color: _showSlowestQueries
                                    ? const Color(0xFFF43F5E)
                                    : const Color(0xFF14B8A6),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Çağrı: ${numFormat.format(q.calls)}  •  Toplam: ${q.totalExecTime.toStringAsFixed(1)} ms  •  Maks: ${q.maxExecTime.toStringAsFixed(1)} ms  •  Satır: ${numFormat.format(q.rows)}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8), size: 16),
                            tooltip: 'SQL Kodunu Kopyala',
                            onPressed: () => _copyToClipboard(q.query, 'SQL Sorgusu'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        q.query,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFE2E8F0),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3. Canlı İşlemler & Kilit Monitörü
  Widget _buildLiveProcessesTab(DatabaseAnalyticsModel data) {
    final processes = data.liveProcesses;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'pg_stat_activity Monitörü • ${processes.length} aktif oturum',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Text(
                'Kendi backend bağlantınız hariç tutulmuştur',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: processes.isEmpty
                ? const Center(
                    child: Text(
                      'Şu anda kuyrukta bekleyen veya uzun süren aktif kilitli işlem bulunmuyor.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('PID', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Kullanıcı', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('İstemci IP', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Durum', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Süre', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Bekleme Olayı', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Sorgu Snippet', style: TextStyle(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.w700))),
                        ],
                        rows: processes.map((p) {
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                p.pid.toString(),
                                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                              )),
                              DataCell(Text(p.usename)),
                              DataCell(Text(p.clientAddr)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: p.state == 'active'
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.textGrey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.state,
                                    style: TextStyle(
                                      color: p.state == 'active' ? AppColors.success : AppColors.textGrey,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text('${p.durationSeconds.toStringAsFixed(1)}s')),
                              DataCell(Text(p.waitEvent ?? 'Yok')),
                              DataCell(
                                SizedBox(
                                  width: 250,
                                  child: Text(
                                    p.query,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  label: const Text('Kill PID'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                                    foregroundColor: AppColors.danger,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () => _killProcess(p.pid, p.query),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 4. Günlük İstek Geçmişi (14 Gün)
  Widget _buildDailyHistoryTab(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final history = data.dailyHistory;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                '14 Günlük İstek & Telemetri Geçmişi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Spacer(),
              Text(
                'Her gece 23:59 UTC pg_cron ile otomatik kaydedilir',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Basit bar göstergesi
          if (history.isNotEmpty)
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: history.reversed.map((h) {
                  final maxCalls = history.map((e) => e.totalCalls).reduce(math.max);
                  final ratio = maxCalls > 0 ? (h.totalCalls / maxCalls).clamp(0.08, 1.0) : 0.1;

                  return Tooltip(
                    message: '${h.metricDate}\n${numFormat.format(h.totalCalls)} istek\nGecikme: ${h.avgLatencyMs} ms',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${(h.totalCalls / 1000000).toStringAsFixed(1)}M',
                          style: const TextStyle(fontSize: 9, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: 70 * ratio,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          h.metricDate.length >= 5 ? h.metricDate.substring(5) : h.metricDate,
                          style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Tarih', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Günlük İstek (Çağrı)', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Ortalama Gecikme', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Aktif Bağlantı', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Veritabanı Boyutu', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Önbellek İsabet %', style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Commit / Rollback', style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: history.map((h) {
                    return DataRow(
                      cells: [
                        DataCell(Text(h.metricDate, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(numFormat.format(h.totalCalls))),
                        DataCell(Text('${h.avgLatencyMs.toStringAsFixed(2)} ms')),
                        DataCell(Text(h.activeConnections.toString())),
                        DataCell(Text(h.databaseSizePretty)),
                        DataCell(Text('%${h.cacheHitRatio.toStringAsFixed(2)}')),
                        DataCell(Text('${numFormat.format(h.transactionsCommitted)} / ${numFormat.format(h.transactionsRolledBack)}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Bağlantı Bilgisi & Konsol Bilgisi
  Widget _buildConnectionInfoTab(DatabaseAnalyticsModel data) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const Text(
            'Harici Veritabanı İstemcileri (DBeaver, DataGrip, TablePlus, VS Code)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Doğrudan Oracle Cloud VM üzerindeki PostgreSQL veya Supavisor bağlantı havuzlayıcısına bağlanmak için aşağıdaki parametreleri kullanabilirsiniz.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kart 1: Doğrudan PostgreSQL
              Expanded(
                child: _buildConnectionCard(
                  title: 'Doğrudan PostgreSQL (Port 5432)',
                  badge: 'Direct Connect',
                  badgeColor: AppColors.primary,
                  items: [
                    _ConnField('Host', '130.61.78.192'),
                    _ConnField('Port', '5432'),
                    _ConnField('Database', 'postgres'),
                    _ConnField('User', 'postgres'),
                    _ConnField('Şifre', 'Supabase DB Parolası (Oracle Cloud)'),
                    _ConnField('SSL Mode', 'Prefer / Require'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Kart 2: Supavisor Pooler
              Expanded(
                child: _buildConnectionCard(
                  title: 'Supavisor Pooler (Port 6543)',
                  badge: 'Transaction Pool',
                  badgeColor: AppColors.accent,
                  items: [
                    _ConnField('Host', '130.61.78.192'),
                    _ConnField('Port', '6543'),
                    _ConnField('Database', 'postgres'),
                    _ConnField('User', 'postgres'),
                    _ConnField('Havuzlama Modu', 'Transaction (Yüksek Eşzamanlılık)'),
                    _ConnField('Maks Bağlantı', '1000+ Sanal İstemci'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Kart 3: 1-Click Studio Bilgisi
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFFFACC15), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supabase Studio Web Konsolu (1-Click Safe Auth)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Envoy API Gateway üzerinde çalışan Lua güvenli oturum filtresi sayesinde şifre girmeden tek tıkla doğrudan Studio oturumunuz açılır.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        AppConstants.studioLaunchUrl,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Studio’yu Aç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(AppConstants.studioLaunchUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required List<_ConnField> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          ...items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      it.label,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      it.value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textLight),
                    tooltip: 'Kopyala',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyToClipboard(it.value, it.label),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ConnField {
  final String label;
  final String value;
  const _ConnField(this.label, this.value);
}

/// Realtime CustomPainter for streaming QPS / TPS chart
class _StreamingChartPainter extends CustomPainter {
  final List<_QpsPoint> points;
  final double maxVal;

  _StreamingChartPainter({
    required this.points,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dx = size.width / (points.length - 1);

    final linePath = Path();
    final fillPath = Path();

    double getY(double val) {
      final normalized = (val / maxVal).clamp(0.0, 1.0);
      return size.height - (normalized * (size.height - 20)) - 10;
    }

    linePath.moveTo(0, getY(points.first.qps));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(points.first.qps));

    for (int i = 1; i < points.length; i++) {
      final prevX = (i - 1) * dx;
      final prevY = getY(points[i - 1].qps);
      final currX = i * dx;
      final currY = getY(points[i].qps);

      final c1x = prevX + (currX - prevX) / 2;
      final c1y = prevY;
      final c2x = prevX + (currX - prevX) / 2;
      final c2y = currY;

      linePath.cubicTo(c1x, c1y, c2x, c2y, currX, currY);
      fillPath.cubicTo(c1x, c1y, c2x, c2y, currX, currY);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill gradient
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x5500B4D8), // Cyan transparent
          Color(0x000F172A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth line
    final linePaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw latest dot with pulsating glow
    final lastX = size.width;
    final lastY = getY(points.last.qps);

    final glowPaint = Paint()
      ..color = const Color(0xFF00B4D8).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 8, glowPaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _StreamingChartPainter oldDelegate) {
    return true;
  }
}
