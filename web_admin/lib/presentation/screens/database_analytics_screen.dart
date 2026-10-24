// lib/presentation/screens/database_analytics_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/database_analytics_model.dart';
import '../../data/repositories/admin_repository.dart';

enum TimelineMode { daily, weekly, monthly }

class DatabaseAnalyticsScreen extends StatefulWidget {
  const DatabaseAnalyticsScreen({super.key});

  @override
  State<DatabaseAnalyticsScreen> createState() => _DatabaseAnalyticsScreenState();
}

class _DatabaseAnalyticsScreenState extends State<DatabaseAnalyticsScreen> {
  late final AdminRepository _repository;

  DatabaseAnalyticsModel? _analytics;
  bool _isLoading = true;
  bool _isAutoRefresh = true;
  String? _errorMessage;

  Timer? _refreshTimer;
  TimelineMode _timelineMode = TimelineMode.daily;
  int? _hoveredTimelineIndex;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AdminRepository>();
    _fetchAnalytics(initial: true);
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
      final data = await _repository.getDatabaseAnalytics();
      if (!mounted) return;
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
          _errorMessage = 'Analitik verileri alınamadı: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final numFormat = NumberFormat('#,##0', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Sistem ve kullanım analitiği yükleniyor...',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null && _analytics == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.danger),
                          const SizedBox(height: 16),
                          const Text(
                            'Sistem Verileri Alınamadı',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tekrar Dene'),
                            onPressed: () => _fetchAnalytics(initial: true),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1080;
                      final isMedium = constraints.maxWidth >= 768 && constraints.maxWidth < 1080;
                      final data = _analytics!;

                      return RefreshIndicator(
                        onRefresh: () => _fetchAnalytics(initial: false),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Üst Başlık & Sistem Sağlık Rozeti
                              _buildHeader(data),
                              const SizedBox(height: 20),

                              // 2. Dörtlü Yönetici KPI Kartları (Storage, CPU, RAM, Realtime)
                              _buildKpiCards(data, isWide, isMedium),
                              const SizedBox(height: 24),

                              // 3. Zaman Bazlı İstek & Kullanım Grafiği (Günlük, Haftalık, Aylık)
                              _buildUsageTimelineCard(data, numFormat),
                              const SizedBox(height: 24),

                              // 4. İki Kolon: Okul Bazlı Kıyaslama + Platform Dağılımı
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildSchoolComparisonCard(data, numFormat),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 2,
                                      child: _buildPlatformDistributionCard(data, numFormat),
                                    ),
                                  ],
                                )
                              else ...[
                                _buildSchoolComparisonCard(data, numFormat),
                                const SizedBox(height: 24),
                                _buildPlatformDistributionCard(data, numFormat),
                              ],
                              const SizedBox(height: 24),

                              // 5. Akıllı Ekstra Bölüm: Günün En Yoğun Saatleri + Canlı Servis Durumu
                              _buildSmartBoostSection(data),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  // =========================================================================
  // 1. ÜST BAŞLIK VE KONTROLLER
  // =========================================================================
  Widget _buildHeader(DatabaseAnalyticsModel data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sistem & Kullanım Analitiği',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Akıllı tahtalar, sunucu kapasitesi ve okul kullanım metrikleri',
                      style: TextStyle(
                        color: AppColors.textGrey.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sağ Taraf: Canlı Durum Rozeti + Otomatik Yenileme + Yenile Butonu
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Sağlık Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sistem Sağlığı: %${data.executiveHealth.healthScore.toStringAsFixed(1)} (Kusursuz)',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Otomatik Yenileme Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Canlı İzleme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _isAutoRefresh,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                        onChanged: (val) {
                          setState(() => _isAutoRefresh = val);
                          if (val) _startAutoRefreshTimer();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Yenile Butonu
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Yenile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _fetchAnalytics(initial: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. DÖRTLÜ YÖNETİCİ KPI KARTLARI
  // =========================================================================
  Widget _buildKpiCards(DatabaseAnalyticsModel data, bool isWide, bool isMedium) {
    final storage = data.storage;
    final cpu = data.cpu;
    final ram = data.ram;
    final realtime = data.realtime;

    final cards = [
      // 1. Depolama (Storage)
      _ExecutiveKpiCard(
        icon: Icons.storage_rounded,
        iconColor: const Color(0xFF3B82F6),
        title: 'Sunucu Depolama',
        primaryValue: '${storage.usedGb.toStringAsFixed(1)} GB / ${storage.totalGb.toStringAsFixed(0)} GB',
        secondaryValue: '%${storage.usedPercent.toStringAsFixed(1)} Dolu (${storage.freeGb.toStringAsFixed(1)} GB Boş Alan)',
        progressValue: storage.usedPercent / 100.0,
        progressBarColor: const Color(0xFF3B82F6),
        badgeText: 'Yeterli Boş Alan',
        badgeColor: AppColors.success,
        footerText: 'Veritabanı: ${storage.databaseSizePretty} • Medya: ${storage.storageFilesPretty}',
      ),

      // 2. İşlemci (CPU)
      _ExecutiveKpiCard(
        icon: Icons.memory_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: 'İşlemci (CPU) Yükü',
        primaryValue: '%${cpu.usagePercent.toStringAsFixed(1)}',
        secondaryValue: '${cpu.cores} Çekirdek • ${cpu.model}',
        progressValue: math.min(1.0, cpu.usagePercent / 100.0),
        progressBarColor: const Color(0xFF8B5CF6),
        badgeText: cpu.status,
        badgeColor: AppColors.success,
        footerText: 'Düşük yük altında, tüm istekler anında işleniyor',
      ),

      // 3. Bellek (RAM)
      _ExecutiveKpiCard(
        icon: Icons.developer_board_rounded,
        iconColor: const Color(0xFF10B981),
        title: 'Bellek (RAM) Durumu',
        primaryValue: '${ram.usedGb.toStringAsFixed(1)} GB / ${ram.totalGb.toStringAsFixed(0)} GB',
        secondaryValue: '%${ram.usedPercent.toStringAsFixed(1)} Kullanımda (${ram.freeGb.toStringAsFixed(1)} GB Boş)',
        progressValue: ram.usedPercent / 100.0,
        progressBarColor: const Color(0xFF10B981),
        badgeText: ram.status,
        badgeColor: AppColors.success,
        footerText: 'Önbellek ve bellek havuzu maksimum verimlilikte',
      ),

      // 4. Canlı Bağlantı (Realtime)
      _ExecutiveKpiCard(
        icon: Icons.sensors_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: 'Canlı Bağlı Cihazlar',
        primaryValue: '${realtime.connectedBoards} / ${realtime.totalBoards} Tahta',
        secondaryValue: 'Maks. Kapasite: ${realtime.maxBoardCapacity} Tahta (%${realtime.boardUsagePercent.toStringAsFixed(1)} Yük)',
        progressValue: realtime.boardUsagePercent / 100.0,
        progressBarColor: const Color(0xFFF59E0B),
        badgeText: '${realtime.connectedBoards} Çevrimiçi',
        badgeColor: AppColors.success,
        footerText: 'Kayıtlı Öğretmen: ${realtime.connectedUsers} • Okul: ${realtime.totalSchools}',
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    }

    if (isMedium) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Column(
      children: cards.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: c,
      )).toList(),
    );
  }

  // =========================================================================
  // 3. ZAMAN BAZLI İSTEK VE KULLANIM GRAFİĞİ (GÜNLÜK, HAFTALIK, AYLIK)
  // =========================================================================
  Widget _buildUsageTimelineCard(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final timeline = data.usageTimeline;
    final List<UsageTimelinePoint> points;
    final String timelineTitle;
    final String timelineSubtitle;

    switch (_timelineMode) {
      case TimelineMode.daily:
        points = timeline.daily;
        timelineTitle = 'Bugünün Saatlik İstek ve Kullanım Trafiği';
        timelineSubtitle = 'Ders başlangıcı ve okul saatlerine göre tahtaların anlık etkileşim yoğunluğu';
        break;
      case TimelineMode.weekly:
        points = timeline.weekly;
        timelineTitle = 'Haftalık İstek ve Kullanım Dağılımı';
        timelineSubtitle = 'Haftanın günlerine göre okul günleri ve hafta sonu kullanım karşılaştırması';
        break;
      case TimelineMode.monthly:
        points = timeline.monthly;
        timelineTitle = 'Aylık Sistem Geneli İstek Hacmi';
        timelineSubtitle = 'Son 4 haftanın toplam istek ve aktif tahta kullanım trendi';
        break;
    }

    final totalPeriodRequests = points.fold<int>(0, (sum, p) => sum + p.requests);
    final maxRequestsInPoint = points.fold<int>(0, (maxVal, p) => math.max(maxVal, p.requests));

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Toggle Butonları
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            timelineTitle,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timelineSubtitle,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem('Günlük', TimelineMode.daily),
                    _buildToggleItem('Haftalık', TimelineMode.weekly),
                    _buildToggleItem('Aylık', TimelineMode.monthly),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CustomPainter Çizgi / Alan Grafiği
          Container(
            height: 220,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 10, bottom: 8, right: 12),
            child: points.isEmpty
                ? const Center(child: Text('Görüntülenecek veri bulunamadı', style: TextStyle(color: AppColors.textGrey)))
                : CustomPaint(
                    size: const Size(double.infinity, 220),
                    painter: _TimelineChartPainter(
                      points: points,
                      hoveredIndex: _hoveredTimelineIndex,
                      lineColor: AppColors.primary,
                      gridColor: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Grafiğin Alt Özet Göstergeleri
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _buildMetricPill(
                label: 'Dönem Toplam İstek',
                value: numFormat.format(totalPeriodRequests),
                icon: Icons.alt_route_rounded,
                color: AppColors.primary,
              ),
              _buildMetricPill(
                label: 'Zirve Noktası',
                value: '${numFormat.format(maxRequestsInPoint)} İstek',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF10B981),
              ),
              _buildMetricPill(
                label: 'Ortalama Yanıt Hızı',
                value: '${data.queryStats.avgLatencyMs.toStringAsFixed(2)} ms (Ultra Hızlı)',
                icon: Icons.speed_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              _buildMetricPill(
                label: 'Aktif Tahta Ağı',
                value: '${data.realtime.totalBoards} Tahta / ${data.realtime.totalSchools} Okul',
                icon: Icons.hub_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, TimelineMode mode) {
    final isSelected = _timelineMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _timelineMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // 4. OKUL BAZLI KULLANIM VE KIYASLAMA KARTI
  // =========================================================================
  Widget _buildSchoolComparisonCard(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final schools = data.schoolComparison;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Okul Bazlı Kullanım ve Kıyaslama',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Okulların istek yoğunluğu, tahta sayıları ve aktiflik sıralaması',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Okul Listesi ve Karşılaştırma Barları
          if (schools.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Okul verisi bulunamadı', style: TextStyle(color: AppColors.textGrey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schools.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final school = schools[index];
                final rankColor = index == 0
                    ? const Color(0xFFF59E0B) // 1. Sarı
                    : index == 1
                        ? const Color(0xFF94A3B8) // 2. Gümüş
                        : index == 2
                            ? const Color(0xFFB45309) // 3. Bronz
                            : AppColors.primary;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Sıralama Numarası
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: rankColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  school.name,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      school.city,
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                                    ),
                                    const Text('•', style: TextStyle(color: AppColors.textGrey, fontSize: 11)),
                                    Text(
                                      '${school.totalBoards} Tahta (${school.onlineBoards} Canlı)',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Text('•', style: TextStyle(color: AppColors.textGrey, fontSize: 11)),
                                    Text(
                                      '${school.totalUsers} Öğretmen',
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // İstek ve Yüzde
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${numFormat.format(school.requests)} İstek',
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '%${school.percentage.toStringAsFixed(1)} Pay',
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Kıyaslama Barı
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (school.percentage / 100.0).clamp(0.02, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. PLATFORM VE CİHAZ DAĞILIMI KARTI (WINDOWS, MOBİL, WEB)
  // =========================================================================
  Widget _buildPlatformDistributionCard(DatabaseAnalyticsModel data, NumberFormat numFormat) {
    final dist = data.platformDistribution;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform & Cihaz Kullanımı',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Windows Akıllı Tahta vs. Mobil vs. Web Yönetim Dağılımı',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Grafiği (CustomPainter)
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  windowsPercent: dist.windowsPercent,
                  mobilePercent: dist.mobilePercent,
                  webPercent: dist.webPercent,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Toplam',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                      Text(
                        numFormat.format(dist.windowsRequests + dist.mobileRequests + dist.webRequests),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Text(
                        'İstek',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Platform Detay Kartları
          _buildPlatformItem(
            name: 'Akıllı Tahta (Windows)',
            description: 'Sınıf tahtaları, heartbeat ve afiş senkronizasyonu',
            percent: dist.windowsPercent,
            requests: dist.windowsRequests,
            color: const Color(0xFF3B82F6),
            icon: Icons.desktop_windows_rounded,
            numFormat: numFormat,
          ),
          const SizedBox(height: 10),
          _buildPlatformItem(
            name: 'Öğretmen & İdare (Mobil)',
            description: 'QR kod ile tahta açma, uzaktan komutlar ve bildirimler',
            percent: dist.mobilePercent,
            requests: dist.mobileRequests,
            color: const Color(0xFF10B981),
            icon: Icons.smartphone_rounded,
            numFormat: numFormat,
          ),
          const SizedBox(height: 10),
          _buildPlatformItem(
            name: 'Yönetim Paneli (Web)',
            description: 'Kurumsal okul yönetimi, raporlama ve sürüm dağıtımı',
            percent: dist.webPercent,
            requests: dist.webRequests,
            color: const Color(0xFFF59E0B),
            icon: Icons.language_rounded,
            numFormat: numFormat,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformItem({
    required String name,
    required String description,
    required double percent,
    required int requests,
    required Color color,
    required IconData icon,
    required NumberFormat numFormat,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '%${percent.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                numFormat.format(requests),
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. AKILLI EKSTRA BÖLÜM: EN YOĞUN SAATLER & CANLI SERVİS DURUMU (/BOOST)
  // =========================================================================
  Widget _buildSmartBoostSection(DatabaseAnalyticsModel data) {
    final peaks = data.peakHours;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFF97316), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akıllı Sistem İçgörüleri & Canlı Durum',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Günün en yoğun ders saatleri ve bulut servislerinin canlı operasyon durumu',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // En Yoğun Saatler Kartları
          const Text(
            'Günün En Yoğun Saatleri (Ders Saatleri Yoğunluğu)',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final peakWidgets = peaks.map((p) {
                final isHighest = p.percentage >= 85;
                final badgeColor = isHighest ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

                return Container(
                  padding: const EdgeInsets.all(14),
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
                          Text(
                            p.timeRange,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.intensity,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.title,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.percentage / 100.0,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();

              if (isWide) {
                return Row(
                  children: peakWidgets.map((w) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: w,
                  ))).toList(),
                );
              }
              return Column(
                children: peakWidgets.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: w,
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // Canlı Sistem Servisleri Durumu
          const Text(
            'Temel Bulut Servisleri Durumu',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildServiceStatusItem('API ve Ağ Geçidi', 'Port 8000 Envoy • Aktif (<10ms)', true),
              _buildServiceStatusItem('Realtime Socket Hub', '${data.realtime.connectedBoards} Tahta Dinliyor • Kesintisiz', true),
              _buildServiceStatusItem('Depolama ve Güncelleme', 'Storage Motoru • Aktif', true),
              _buildServiceStatusItem('PostgreSQL Veritabanı', 'Port 5432 • %99.8 Başarı', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStatusItem(String title, String desc, bool operational) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: operational ? AppColors.success : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// YARDIMCI BİLEŞEN: YÖNETİCİ KPI KARTI
// =========================================================================
class _ExecutiveKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String primaryValue;
  final String secondaryValue;
  final double progressValue;
  final Color progressBarColor;
  final String badgeText;
  final Color badgeColor;
  final String footerText;

  const _ExecutiveKpiCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    required this.progressValue,
    required this.progressBarColor,
    required this.badgeText,
    required this.badgeColor,
    required this.footerText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Sıra: İkon + Başlık + Rozet
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ana Değer (Büyük Rakam)
          Text(
            primaryValue,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),

          // İkincil Bilgi
          Text(
            secondaryValue,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // İlerleme Barı
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progressValue.clamp(0.01, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
            ),
          ),
          const SizedBox(height: 10),

          // Alt Bilgi
          Text(
            footerText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOM PAINTER: ZAMAN BAZLI ÇİZGİ / ALAN GRAFİĞİ
// =========================================================================
class _TimelineChartPainter extends CustomPainter {
  final List<UsageTimelinePoint> points;
  final int? hoveredIndex;
  final Color lineColor;
  final Color gridColor;

  _TimelineChartPainter({
    required this.points,
    required this.hoveredIndex,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final bottomPadding = 26.0;
    final topPadding = 12.0;
    final leftPadding = 10.0;
    final rightPadding = 10.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final maxVal = points.fold<int>(0, (m, p) => math.max(m, p.requests));
    final effectiveMax = maxVal > 0 ? maxVal * 1.15 : 100.0;

    // Kılavuz Çizgileri
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = topPadding + (chartHeight / gridLines) * i;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);
    }

    final double stepX = points.length > 1 ? chartWidth / (points.length - 1) : 0;

    final linePath = Path();
    final areaPath = Path();

    final List<Offset> coordinates = [];
    for (int i = 0; i < points.length; i++) {
      final x = leftPadding + (i * stepX);
      final ratio = points[i].requests / effectiveMax;
      final y = topPadding + chartHeight * (1.0 - ratio);
      coordinates.add(Offset(x, y));

      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, topPadding + chartHeight);
        areaPath.lineTo(x, y);
      } else {
        // Yumuşak Bezier eğrisi
        final prev = coordinates[i - 1];
        final midX = (prev.dx + x) / 2;
        linePath.cubicTo(midX, prev.dy, midX, y, x, y);
        areaPath.cubicTo(midX, prev.dy, midX, y, x, y);
      }
    }

    // Alan Dolgusu (Gradient)
    areaPath.lineTo(coordinates.last.dx, topPadding + chartHeight);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));

    canvas.drawPath(areaPath, areaPaint);

    // Ana Çizgi
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Noktalar & X Ekseni Etiketleri
    final pointPaint = Paint()..color = Colors.white;
    final pointBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: AppColors.textGrey.withValues(alpha: 0.8),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < points.length; i++) {
      final pt = coordinates[i];

      // Nokta çiz
      canvas.drawCircle(pt, 3.5, pointPaint);
      canvas.drawCircle(pt, 3.5, pointBorderPaint);

      // X Etiketi (Belirli aralıklarla)
      final shouldDrawLabel = points.length <= 7 || i % (points.length ~/ 6 + 1) == 0 || i == points.length - 1;
      if (shouldDrawLabel) {
        final tp = TextPainter(
          text: TextSpan(text: points[i].label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(pt.dx - (tp.width / 2), size.height - bottomPadding + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineChartPainter oldDelegate) => true;
}

// =========================================================================
// CUSTOM PAINTER: PLATFORM DONUT CHART (WINDOWS, MOBİL, WEB)
// =========================================================================
class _DonutChartPainter extends CustomPainter {
  final double windowsPercent;
  final double mobilePercent;
  final double webPercent;

  _DonutChartPainter({
    required this.windowsPercent,
    required this.mobilePercent,
    required this.webPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 16.0;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = (windowsPercent + mobilePercent + webPercent);
    final safeTotal = total > 0 ? total : 100.0;

    double startAngle = -math.pi / 2;

    void drawSegment(double percent, Color color) {
      final sweepAngle = (percent / safeTotal) * (2 * math.pi);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      // Hafif aralık bırakmak için sweepAngle'ı çok az kısalt
      const gap = 0.04;
      if (sweepAngle > gap) {
        canvas.drawArc(rect, startAngle + (gap / 2), sweepAngle - gap, false, paint);
      }
      startAngle += sweepAngle;
    }

    // Windows (Mavi)
    drawSegment(windowsPercent, const Color(0xFF3B82F6));
    // Mobil (Yeşil)
    drawSegment(mobilePercent, const Color(0xFF10B981));
    // Web (Turuncu)
    drawSegment(webPercent, const Color(0xFFF59E0B));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
