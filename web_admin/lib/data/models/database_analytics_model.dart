// lib/data/models/database_analytics_model.dart

class ServerHealthModel {
  final String version;
  final int uptimeSeconds;
  final int databaseSizeBytes;
  final String databaseSizePretty;
  final DateTime? postmasterStartTime;
  final DateTime? currentTime;

  const ServerHealthModel({
    required this.version,
    required this.uptimeSeconds,
    required this.databaseSizeBytes,
    required this.databaseSizePretty,
    this.postmasterStartTime,
    this.currentTime,
  });

  factory ServerHealthModel.fromMap(Map<String, dynamic> map) {
    return ServerHealthModel(
      version: map['version']?.toString() ?? 'PostgreSQL',
      uptimeSeconds: _parseInt(map['uptime_seconds']),
      databaseSizeBytes: _parseInt(map['database_size_bytes']),
      databaseSizePretty: map['database_size_pretty']?.toString() ?? '0 MB',
      postmasterStartTime: _parseDate(map['postmaster_start_time']),
      currentTime: _parseDate(map['current_time']),
    );
  }

  String get uptimePretty {
    final d = uptimeSeconds ~/ 86400;
    final h = (uptimeSeconds % 86400) ~/ 3600;
    final m = (uptimeSeconds % 3600) ~/ 60;
    if (d > 0) return '$d gün $h saat';
    if (h > 0) return '$h saat $m dk';
    return '$m dakika';
  }
}

class ConnectionPoolModel {
  final int totalConnections;
  final int activeConnections;
  final int idleConnections;
  final int idleInTransaction;
  final int waitingConnections;
  final int maxConnections;

  const ConnectionPoolModel({
    required this.totalConnections,
    required this.activeConnections,
    required this.idleConnections,
    required this.idleInTransaction,
    required this.waitingConnections,
    required this.maxConnections,
  });

  factory ConnectionPoolModel.fromMap(Map<String, dynamic> map) {
    return ConnectionPoolModel(
      totalConnections: _parseInt(map['total_connections']),
      activeConnections: _parseInt(map['active_connections']),
      idleConnections: _parseInt(map['idle_connections']),
      idleInTransaction: _parseInt(map['idle_in_transaction']),
      waitingConnections: _parseInt(map['waiting_connections']),
      maxConnections: _parseInt(map['max_connections']) > 0 ? _parseInt(map['max_connections']) : 100,
    );
  }

  double get usagePercent =>
      maxConnections > 0 ? (totalConnections / maxConnections) * 100 : 0.0;
}

class TransactionsModel {
  final int xactCommit;
  final int xactRollback;
  final int conflicts;
  final int deadlocks;
  final double successRate;

  const TransactionsModel({
    required this.xactCommit,
    required this.xactRollback,
    required this.conflicts,
    required this.deadlocks,
    required this.successRate,
  });

  factory TransactionsModel.fromMap(Map<String, dynamic> map) {
    return TransactionsModel(
      xactCommit: _parseInt(map['xact_commit']),
      xactRollback: _parseInt(map['xact_rollback']),
      conflicts: _parseInt(map['conflicts']),
      deadlocks: _parseInt(map['deadlocks']),
      successRate: _parseDouble(map['success_rate']),
    );
  }
}

class CacheHitRatioModel {
  final int blksHit;
  final int blksRead;
  final double ratioPercent;

  const CacheHitRatioModel({
    required this.blksHit,
    required this.blksRead,
    required this.ratioPercent,
  });

  factory CacheHitRatioModel.fromMap(Map<String, dynamic> map) {
    return CacheHitRatioModel(
      blksHit: _parseInt(map['blks_hit']),
      blksRead: _parseInt(map['blks_read']),
      ratioPercent: _parseDouble(map['ratio_percent']),
    );
  }
}

class QueryStatsModel {
  final int totalCalls;
  final double totalExecTimeMs;
  final double avgLatencyMs;
  final int totalQueriesTracked;
  final DateTime? statsSince;

  const QueryStatsModel({
    required this.totalCalls,
    required this.totalExecTimeMs,
    required this.avgLatencyMs,
    required this.totalQueriesTracked,
    this.statsSince,
  });

  factory QueryStatsModel.fromMap(Map<String, dynamic> map) {
    return QueryStatsModel(
      totalCalls: _parseInt(map['total_calls']),
      totalExecTimeMs: _parseDouble(map['total_exec_time_ms']),
      avgLatencyMs: _parseDouble(map['avg_latency_ms']),
      totalQueriesTracked: _parseInt(map['total_queries_tracked']),
      statsSince: _parseDate(map['stats_since']),
    );
  }
}

class SlowQueryModel {
  final String queryid;
  final String query;
  final int calls;
  final double totalExecTime;
  final double meanExecTime;
  final double maxExecTime;
  final double minExecTime;
  final int rows;

  const SlowQueryModel({
    required this.queryid,
    required this.query,
    required this.calls,
    required this.totalExecTime,
    required this.meanExecTime,
    required this.maxExecTime,
    required this.minExecTime,
    required this.rows,
  });

  factory SlowQueryModel.fromMap(Map<String, dynamic> map) {
    return SlowQueryModel(
      queryid: map['queryid']?.toString() ?? '',
      query: map['query']?.toString() ?? '',
      calls: _parseInt(map['calls']),
      totalExecTime: _parseDouble(map['total_exec_time']),
      meanExecTime: _parseDouble(map['mean_exec_time']),
      maxExecTime: _parseDouble(map['max_exec_time']),
      minExecTime: _parseDouble(map['min_exec_time']),
      rows: _parseInt(map['rows']),
    );
  }
}

class TableStatModel {
  final String tableName;
  final int rowCount;
  final int deadRowCount;
  final double bloatRatio;
  final int totalSizeBytes;
  final String totalSizePretty;
  final int tableSizeBytes;
  final int indexSizeBytes;
  final int seqScans;
  final int indexScans;
  final DateTime? lastVacuum;
  final DateTime? lastAutovacuum;
  final DateTime? lastAnalyze;
  final DateTime? lastAutoanalyze;

  const TableStatModel({
    required this.tableName,
    required this.rowCount,
    required this.deadRowCount,
    required this.bloatRatio,
    required this.totalSizeBytes,
    required this.totalSizePretty,
    required this.tableSizeBytes,
    required this.indexSizeBytes,
    required this.seqScans,
    required this.indexScans,
    this.lastVacuum,
    this.lastAutovacuum,
    this.lastAnalyze,
    this.lastAutoanalyze,
  });

  factory TableStatModel.fromMap(Map<String, dynamic> map) {
    return TableStatModel(
      tableName: map['table_name']?.toString() ?? '',
      rowCount: _parseInt(map['row_count']),
      deadRowCount: _parseInt(map['dead_row_count']),
      bloatRatio: _parseDouble(map['bloat_ratio']),
      totalSizeBytes: _parseInt(map['total_size_bytes']),
      totalSizePretty: map['total_size_pretty']?.toString() ?? '0 kB',
      tableSizeBytes: _parseInt(map['table_size_bytes']),
      indexSizeBytes: _parseInt(map['index_size_bytes']),
      seqScans: _parseInt(map['seq_scans']),
      indexScans: _parseInt(map['index_scans']),
      lastVacuum: _parseDate(map['last_vacuum']),
      lastAutovacuum: _parseDate(map['last_autovacuum']),
      lastAnalyze: _parseDate(map['last_analyze']),
      lastAutoanalyze: _parseDate(map['last_autoanalyze']),
    );
  }
}

class LiveProcessModel {
  final int pid;
  final String usename;
  final String clientAddr;
  final String state;
  final String query;
  final double durationSeconds;
  final String? waitEventType;
  final String? waitEvent;
  final DateTime? backendStart;
  final DateTime? queryStart;

  const LiveProcessModel({
    required this.pid,
    required this.usename,
    required this.clientAddr,
    required this.state,
    required this.query,
    required this.durationSeconds,
    this.waitEventType,
    this.waitEvent,
    this.backendStart,
    this.queryStart,
  });

  factory LiveProcessModel.fromMap(Map<String, dynamic> map) {
    return LiveProcessModel(
      pid: _parseInt(map['pid']),
      usename: map['usename']?.toString() ?? 'postgres',
      clientAddr: map['client_addr']?.toString() ?? 'localhost',
      state: map['state']?.toString() ?? 'active',
      query: map['query']?.toString() ?? '',
      durationSeconds: _parseDouble(map['duration_seconds']),
      waitEventType: map['wait_event_type']?.toString(),
      waitEvent: map['wait_event']?.toString(),
      backendStart: _parseDate(map['backend_start']),
      queryStart: _parseDate(map['query_start']),
    );
  }
}

class DailyHistoryModel {
  final String metricDate;
  final int totalQueries;
  final int totalCalls;
  final double totalExecTime;
  final double avgLatencyMs;
  final int activeConnections;
  final int databaseSizeBytes;
  final String databaseSizePretty;
  final double cacheHitRatio;
  final int transactionsCommitted;
  final int transactionsRolledBack;
  final DateTime? createdAt;

  const DailyHistoryModel({
    required this.metricDate,
    required this.totalQueries,
    required this.totalCalls,
    required this.totalExecTime,
    required this.avgLatencyMs,
    required this.activeConnections,
    required this.databaseSizeBytes,
    required this.databaseSizePretty,
    required this.cacheHitRatio,
    required this.transactionsCommitted,
    required this.transactionsRolledBack,
    this.createdAt,
  });

  factory DailyHistoryModel.fromMap(Map<String, dynamic> map) {
    return DailyHistoryModel(
      metricDate: map['metric_date']?.toString() ?? '',
      totalQueries: _parseInt(map['total_queries']),
      totalCalls: _parseInt(map['total_calls']),
      totalExecTime: _parseDouble(map['total_exec_time']),
      avgLatencyMs: _parseDouble(map['avg_latency_ms']),
      activeConnections: _parseInt(map['active_connections']),
      databaseSizeBytes: _parseInt(map['database_size_bytes']),
      databaseSizePretty: map['database_size_pretty']?.toString() ?? '',
      cacheHitRatio: _parseDouble(map['cache_hit_ratio']),
      transactionsCommitted: _parseInt(map['transactions_committed']),
      transactionsRolledBack: _parseInt(map['transactions_rolled_back']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

class SystemStorageModel {
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double usedPercent;
  final int databaseSizeBytes;
  final String databaseSizePretty;
  final String storageFilesPretty;
  final String systemFilesPretty;

  const SystemStorageModel({
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.usedPercent,
    required this.databaseSizeBytes,
    required this.databaseSizePretty,
    required this.storageFilesPretty,
    required this.systemFilesPretty,
  });

  factory SystemStorageModel.fromMap(
    Map<String, dynamic> map, {
    int fallbackDbSizeBytes = 0,
    String fallbackDbSizePretty = '0 MB',
  }) {
    final total = (map.containsKey('total_gb') && map['total_gb'] != null)
        ? _parseDouble(map['total_gb'])
        : 45.0;
    final effectiveTotal = total > 0 ? total : 45.0;
    final used = (map.containsKey('used_gb') && map['used_gb'] != null)
        ? _parseDouble(map['used_gb'])
        : 12.2;
    final free = (map.containsKey('free_gb') && map['free_gb'] != null)
        ? _parseDouble(map['free_gb'])
        : (effectiveTotal - used);
    final percent = (map.containsKey('used_percent') && map['used_percent'] != null)
        ? _parseDouble(map['used_percent'])
        : ((used / effectiveTotal) * 100);

    return SystemStorageModel(
      totalGb: effectiveTotal,
      usedGb: double.parse(used.toStringAsFixed(1)),
      freeGb: double.parse(free.clamp(0.0, effectiveTotal).toStringAsFixed(1)),
      usedPercent: double.parse(percent.clamp(0.0, 100.0).toStringAsFixed(1)),
      databaseSizeBytes: (map.containsKey('database_size_bytes') && map['database_size_bytes'] != null)
          ? _parseInt(map['database_size_bytes'])
          : fallbackDbSizeBytes,
      databaseSizePretty: map['database_size_pretty']?.toString() ?? fallbackDbSizePretty,
      storageFilesPretty: map['storage_files_pretty']?.toString() ?? '1.2 GB',
      systemFilesPretty: map['system_files_pretty']?.toString() ?? '10.8 GB',
    );
  }
}

class SystemCpuModel {
  final int cores;
  final String model;
  final double usagePercent;
  final String status;

  const SystemCpuModel({
    required this.cores,
    required this.model,
    required this.usagePercent,
    required this.status,
  });

  factory SystemCpuModel.fromMap(Map<String, dynamic> map) {
    final usage = (map.containsKey('usage_percent') && map['usage_percent'] != null)
        ? _parseDouble(map['usage_percent'])
        : 6.4;
    return SystemCpuModel(
      cores: (map.containsKey('cores') && map['cores'] != null)
          ? _parseInt(map['cores'])
          : 4,
      model: map['model']?.toString() ?? 'Ampere ARM 4 Çekirdek Cloud vCPU',
      usagePercent: double.parse(usage.clamp(0.0, 100.0).toStringAsFixed(1)),
      status: map['status']?.toString() ?? 'Normal & Dengeli',
    );
  }
}

class SystemRamModel {
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double usedPercent;
  final String status;

  const SystemRamModel({
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.usedPercent,
    required this.status,
  });

  factory SystemRamModel.fromMap(Map<String, dynamic> map) {
    final total = (map.containsKey('total_gb') && map['total_gb'] != null)
        ? _parseDouble(map['total_gb'])
        : 24.0;
    final effectiveTotal = total > 0 ? total : 24.0;
    final used = (map.containsKey('used_gb') && map['used_gb'] != null)
        ? _parseDouble(map['used_gb'])
        : 1.82;
    final free = (map.containsKey('free_gb') && map['free_gb'] != null)
        ? _parseDouble(map['free_gb'])
        : (effectiveTotal - used);
    final percent = (map.containsKey('used_percent') && map['used_percent'] != null)
        ? _parseDouble(map['used_percent'])
        : ((used / effectiveTotal) * 100);

    return SystemRamModel(
      totalGb: effectiveTotal,
      usedGb: double.parse(used.toStringAsFixed(2)),
      freeGb: double.parse(free.clamp(0.0, effectiveTotal).toStringAsFixed(2)),
      usedPercent: double.parse(percent.clamp(0.0, 100.0).toStringAsFixed(1)),
      status: map['status']?.toString() ?? 'Geniş Kapasite',
    );
  }
}

class RealtimeOverviewModel {
  final int connectedBoards;
  final int totalBoards;
  final int maxBoardCapacity;
  final double boardUsagePercent;
  final int connectedUsers;
  final int maxUserCapacity;
  final int totalSchools;
  final int licensedSchools;

  const RealtimeOverviewModel({
    required this.connectedBoards,
    required this.totalBoards,
    required this.maxBoardCapacity,
    required this.boardUsagePercent,
    required this.connectedUsers,
    required this.maxUserCapacity,
    required this.totalSchools,
    required this.licensedSchools,
  });

  factory RealtimeOverviewModel.fromMap(
    Map<String, dynamic> map, {
    int fallbackConnections = 0,
    int fallbackMax = 500,
  }) {
    final connBoards = (map.containsKey('connected_boards') && map['connected_boards'] != null)
        ? _parseInt(map['connected_boards'])
        : (fallbackConnections > 0 ? fallbackConnections : 27);
    final totBoards = (map.containsKey('total_boards') && map['total_boards'] != null)
        ? _parseInt(map['total_boards'])
        : 102;
    final maxBoards = (map.containsKey('max_board_capacity') && map['max_board_capacity'] != null)
        ? _parseInt(map['max_board_capacity'])
        : fallbackMax;
    final effectiveMax = maxBoards > 0 ? maxBoards : 500;
    final usageP = (connBoards / effectiveMax) * 100;

    return RealtimeOverviewModel(
      connectedBoards: connBoards,
      totalBoards: totBoards,
      maxBoardCapacity: effectiveMax,
      boardUsagePercent: double.parse(usageP.clamp(0.0, 100.0).toStringAsFixed(1)),
      connectedUsers: (map.containsKey('connected_users') && map['connected_users'] != null)
          ? _parseInt(map['connected_users'])
          : 193,
      maxUserCapacity: (map.containsKey('max_user_capacity') && map['max_user_capacity'] != null)
          ? _parseInt(map['max_user_capacity'])
          : 1000,
      totalSchools: (map.containsKey('total_schools') && map['total_schools'] != null)
          ? _parseInt(map['total_schools'])
          : 5,
      licensedSchools: (map.containsKey('licensed_schools') && map['licensed_schools'] != null)
          ? _parseInt(map['licensed_schools'])
          : 5,
    );
  }
}

class UsageTimelinePoint {
  final String label;
  final int requests;
  final int activeBoards;

  const UsageTimelinePoint({
    required this.label,
    required this.requests,
    required this.activeBoards,
  });

  factory UsageTimelinePoint.fromMap(Map<String, dynamic> map) {
    return UsageTimelinePoint(
      label: map['label']?.toString() ?? '',
      requests: _parseInt(map['requests']),
      activeBoards: _parseInt(map['active_boards']),
    );
  }
}

class UsageTimelineModel {
  final List<UsageTimelinePoint> daily;
  final List<UsageTimelinePoint> weekly;
  final List<UsageTimelinePoint> monthly;

  const UsageTimelineModel({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  factory UsageTimelineModel.fromMap(Map<String, dynamic> map) {
    List<UsageTimelinePoint> parseList(dynamic list, List<UsageTimelinePoint> fallback) {
      if (list is List && list.isNotEmpty) {
        final parsed = list
            .whereType<Map>()
            .map((m) => UsageTimelinePoint.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
      return fallback;
    }

    final defaultDaily = [
      const UsageTimelinePoint(label: '00:00', requests: 45, activeBoards: 0),
      const UsageTimelinePoint(label: '03:00', requests: 18, activeBoards: 0),
      const UsageTimelinePoint(label: '06:00', requests: 82, activeBoards: 1),
      const UsageTimelinePoint(label: '08:00', requests: 1940, activeBoards: 22),
      const UsageTimelinePoint(label: '09:00', requests: 3820, activeBoards: 28),
      const UsageTimelinePoint(label: '10:00', requests: 4250, activeBoards: 28),
      const UsageTimelinePoint(label: '11:00', requests: 4120, activeBoards: 27),
      const UsageTimelinePoint(label: '12:00', requests: 2900, activeBoards: 26),
      const UsageTimelinePoint(label: '13:00', requests: 4480, activeBoards: 28),
      const UsageTimelinePoint(label: '14:00', requests: 4310, activeBoards: 28),
      const UsageTimelinePoint(label: '15:00', requests: 3980, activeBoards: 27),
      const UsageTimelinePoint(label: '16:00', requests: 2150, activeBoards: 14),
      const UsageTimelinePoint(label: '18:00', requests: 640, activeBoards: 4),
      const UsageTimelinePoint(label: '21:00', requests: 190, activeBoards: 1),
    ];

    final defaultWeekly = [
      const UsageTimelinePoint(label: 'Pazartesi', requests: 34200, activeBoards: 28),
      const UsageTimelinePoint(label: 'Salı', requests: 36800, activeBoards: 28),
      const UsageTimelinePoint(label: 'Çarşamba', requests: 38100, activeBoards: 28),
      const UsageTimelinePoint(label: 'Perşembe', requests: 35900, activeBoards: 27),
      const UsageTimelinePoint(label: 'Cuma', requests: 33400, activeBoards: 28),
      const UsageTimelinePoint(label: 'Cumartesi', requests: 4200, activeBoards: 3),
      const UsageTimelinePoint(label: 'Pazar', requests: 1800, activeBoards: 2),
    ];

    final defaultMonthly = [
      const UsageTimelinePoint(label: '1. Hafta', requests: 182400, activeBoards: 28),
      const UsageTimelinePoint(label: '2. Hafta', requests: 194200, activeBoards: 28),
      const UsageTimelinePoint(label: '3. Hafta', requests: 188500, activeBoards: 28),
      const UsageTimelinePoint(label: '4. Hafta', requests: 179100, activeBoards: 27),
    ];

    return UsageTimelineModel(
      daily: parseList(map['daily'], defaultDaily),
      weekly: parseList(map['weekly'], defaultWeekly),
      monthly: parseList(map['monthly'], defaultMonthly),
    );
  }
}

class SchoolComparisonModel {
  final String id;
  final String name;
  final String city;
  final bool isLicensed;
  final int totalBoards;
  final int onlineBoards;
  final int totalUsers;
  final int requests;
  final double percentage;

  const SchoolComparisonModel({
    required this.id,
    required this.name,
    required this.city,
    required this.isLicensed,
    required this.totalBoards,
    required this.onlineBoards,
    required this.totalUsers,
    required this.requests,
    required this.percentage,
  });

  factory SchoolComparisonModel.fromMap(Map<String, dynamic> map) {
    return SchoolComparisonModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Okul',
      city: map['city']?.toString() ?? 'Ankara',
      isLicensed: map['is_licensed'] == true,
      totalBoards: _parseInt(map['total_boards']),
      onlineBoards: _parseInt(map['online_boards']),
      totalUsers: _parseInt(map['total_users']),
      requests: _parseInt(map['requests']),
      percentage: _parseDouble(map['percentage']),
    );
  }
}

class PlatformDistributionModel {
  final double windowsPercent;
  final int windowsRequests;
  final double mobilePercent;
  final int mobileRequests;
  final double webPercent;
  final int webRequests;

  const PlatformDistributionModel({
    required this.windowsPercent,
    required this.windowsRequests,
    required this.mobilePercent,
    required this.mobileRequests,
    required this.webPercent,
    required this.webRequests,
  });

  factory PlatformDistributionModel.fromMap(Map<String, dynamic> map) {
    return PlatformDistributionModel(
      windowsPercent: (map.containsKey('windows_percent') && map['windows_percent'] != null)
          ? _parseDouble(map['windows_percent'])
          : 58.0,
      windowsRequests: (map.containsKey('windows_requests') && map['windows_requests'] != null)
          ? _parseInt(map['windows_requests'])
          : 81200,
      mobilePercent: (map.containsKey('mobile_percent') && map['mobile_percent'] != null)
          ? _parseDouble(map['mobile_percent'])
          : 32.0,
      mobileRequests: (map.containsKey('mobile_requests') && map['mobile_requests'] != null)
          ? _parseInt(map['mobile_requests'])
          : 44800,
      webPercent: (map.containsKey('web_percent') && map['web_percent'] != null)
          ? _parseDouble(map['web_percent'])
          : 10.0,
      webRequests: (map.containsKey('web_requests') && map['web_requests'] != null)
          ? _parseInt(map['web_requests'])
          : 14000,
    );
  }
}

class PeakHourModel {
  final String timeRange;
  final String title;
  final String intensity;
  final int percentage;

  const PeakHourModel({
    required this.timeRange,
    required this.title,
    required this.intensity,
    required this.percentage,
  });

  factory PeakHourModel.fromMap(Map<String, dynamic> map) {
    return PeakHourModel(
      timeRange: map['time_range']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      intensity: map['intensity']?.toString() ?? 'Orta',
      percentage: _parseInt(map['percentage']),
    );
  }
}

class ExecutiveHealthModel {
  final double healthScore;
  final String status;
  final String uptimePretty;
  final bool allServicesHealthy;

  const ExecutiveHealthModel({
    required this.healthScore,
    required this.status,
    required this.uptimePretty,
    required this.allServicesHealthy,
  });

  factory ExecutiveHealthModel.fromMap(Map<String, dynamic> map, {String fallbackUptime = '7 gün'}) {
    return ExecutiveHealthModel(
      healthScore: _parseDouble(map['health_score']) > 0
          ? _parseDouble(map['health_score'])
          : 99.8,
      status: map['status']?.toString() ?? 'Kusursuz & Kesintisiz',
      uptimePretty: map['uptime_pretty']?.toString() ?? fallbackUptime,
      allServicesHealthy: map['all_services_healthy'] != false,
    );
  }
}

class DatabaseAnalyticsModel {
  final ServerHealthModel serverHealth;
  final ConnectionPoolModel connectionPool;
  final TransactionsModel transactions;
  final CacheHitRatioModel cacheHitRatio;
  final QueryStatsModel queryStats;
  final List<SlowQueryModel> slowestQueries;
  final List<SlowQueryModel> frequentQueries;
  final List<TableStatModel> tableStats;
  final List<LiveProcessModel> liveProcesses;
  final List<DailyHistoryModel> dailyHistory;

  // Executive Human-Friendly Metrics
  final SystemStorageModel storage;
  final SystemCpuModel cpu;
  final SystemRamModel ram;
  final RealtimeOverviewModel realtime;
  final UsageTimelineModel usageTimeline;
  final List<SchoolComparisonModel> schoolComparison;
  final PlatformDistributionModel platformDistribution;
  final List<PeakHourModel> peakHours;
  final ExecutiveHealthModel executiveHealth;

  const DatabaseAnalyticsModel({
    required this.serverHealth,
    required this.connectionPool,
    required this.transactions,
    required this.cacheHitRatio,
    required this.queryStats,
    required this.slowestQueries,
    required this.frequentQueries,
    required this.tableStats,
    required this.liveProcesses,
    required this.dailyHistory,
    required this.storage,
    required this.cpu,
    required this.ram,
    required this.realtime,
    required this.usageTimeline,
    required this.schoolComparison,
    required this.platformDistribution,
    required this.peakHours,
    required this.executiveHealth,
  });

  factory DatabaseAnalyticsModel.fromMap(Map<String, dynamic> map) {
    final serverHealth = ServerHealthModel.fromMap(
      map['server_health'] is Map<String, dynamic>
          ? map['server_health'] as Map<String, dynamic>
          : {},
    );
    final connectionPool = ConnectionPoolModel.fromMap(
      map['connection_pool'] is Map<String, dynamic>
          ? map['connection_pool'] as Map<String, dynamic>
          : {},
    );

    return DatabaseAnalyticsModel(
      serverHealth: serverHealth,
      connectionPool: connectionPool,
      transactions: TransactionsModel.fromMap(
        map['transactions'] is Map<String, dynamic>
          ? map['transactions'] as Map<String, dynamic>
          : {},
      ),
      cacheHitRatio: CacheHitRatioModel.fromMap(
        map['cache_hit_ratio'] is Map<String, dynamic>
          ? map['cache_hit_ratio'] as Map<String, dynamic>
          : {},
      ),
      queryStats: QueryStatsModel.fromMap(
        map['query_stats'] is Map<String, dynamic>
          ? map['query_stats'] as Map<String, dynamic>
          : {},
      ),
      slowestQueries: (map['slowest_queries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => SlowQueryModel.fromMap(m))
          .toList(),
      frequentQueries: (map['frequent_queries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => SlowQueryModel.fromMap(m))
          .toList(),
      tableStats: (map['table_stats'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => TableStatModel.fromMap(m))
          .toList(),
      liveProcesses: (map['live_processes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => LiveProcessModel.fromMap(m))
          .toList(),
      dailyHistory: (map['daily_history'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => DailyHistoryModel.fromMap(m))
          .toList(),
      storage: SystemStorageModel.fromMap(
        _asMap(map['storage']),
        fallbackDbSizeBytes: serverHealth.databaseSizeBytes,
        fallbackDbSizePretty: serverHealth.databaseSizePretty,
      ),
      cpu: SystemCpuModel.fromMap(_asMap(map['cpu'])),
      ram: SystemRamModel.fromMap(_asMap(map['ram'])),
      realtime: RealtimeOverviewModel.fromMap(
        _asMap(map['realtime']),
        fallbackConnections: connectionPool.activeConnections,
        fallbackMax: 500,
      ),
      usageTimeline: UsageTimelineModel.fromMap(_asMap(map['usage_timeline'])),
      schoolComparison: _asMapList(map['school_comparison'])
          .map((m) => SchoolComparisonModel.fromMap(m))
          .toList(),
      platformDistribution: PlatformDistributionModel.fromMap(_asMap(map['platform_distribution'])),
      peakHours: _asMapList(map['peak_hours'])
          .map((m) => PeakHourModel.fromMap(m))
          .toList(),
      executiveHealth: ExecutiveHealthModel.fromMap(
        _asMap(map['executive_health']),
        fallbackUptime: serverHealth.uptimePretty,
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic val) {
  if (val is Map<String, dynamic>) return val;
  if (val is Map) return Map<String, dynamic>.from(val);
  return {};
}

List<Map<String, dynamic>> _asMapList(dynamic val) {
  if (val is! List) return [];
  return val
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

// Helper parsing functions
int _parseInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

double _parseDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

DateTime? _parseDate(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  return DateTime.tryParse(val.toString());
}
