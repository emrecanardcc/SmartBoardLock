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
  });

  factory DatabaseAnalyticsModel.fromMap(Map<String, dynamic> map) {
    return DatabaseAnalyticsModel(
      serverHealth: ServerHealthModel.fromMap(
        map['server_health'] is Map<String, dynamic>
            ? map['server_health'] as Map<String, dynamic>
            : {},
      ),
      connectionPool: ConnectionPoolModel.fromMap(
        map['connection_pool'] is Map<String, dynamic>
            ? map['connection_pool'] as Map<String, dynamic>
            : {},
      ),
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
    );
  }
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
