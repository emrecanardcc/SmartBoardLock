// test/database_analytics_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/data/models/database_analytics_model.dart';

void main() {
  group('DatabaseAnalyticsModel Unit Tests', () {
    test('Executive models zero-safety and precision check', () {
      final realtime = RealtimeOverviewModel.fromMap({
        'connected_boards': 0,
        'total_boards': 50,
        'max_board_capacity': 500,
        'connected_users': 0,
        'total_schools': 0,
        'licensed_schools': 0,
      });

      expect(realtime.connectedBoards, equals(0));
      expect(realtime.totalBoards, equals(50));
      expect(realtime.boardUsagePercent, equals(0.0));
      expect(realtime.connectedUsers, equals(0));
      expect(realtime.totalSchools, equals(0));

      final platform = PlatformDistributionModel.fromMap({
        'windows_percent': 100.0,
        'windows_requests': 5000,
        'mobile_percent': 0.0,
        'mobile_requests': 0,
        'web_percent': 0.0,
        'web_requests': 0,
      });

      expect(platform.windowsPercent, equals(100.0));
      expect(platform.mobilePercent, equals(0.0));
      expect(platform.webPercent, equals(0.0));

      final cpu = SystemCpuModel.fromMap({
        'cores': 8,
        'usage_percent': 0.0,
      });
      expect(cpu.cores, equals(8));
      expect(cpu.usagePercent, equals(0.0));
    });

    test('ServerHealthModel parses correctly and computes uptime', () {
      final model = ServerHealthModel.fromMap({
        'version': 'PostgreSQL 17.6',
        'uptime_seconds': 172800 + 7200 + 300, // 2 gün 2 saat 5 dk
        'database_size_bytes': 15728640,
        'database_size_pretty': '15 MB',
        'current_time': '2026-10-24T12:00:00Z',
      });

      expect(model.version, equals('PostgreSQL 17.6'));
      expect(model.uptimeSeconds, equals(180300));
      expect(model.databaseSizePretty, equals('15 MB'));
      expect(model.uptimePretty, equals('2 gün 2 saat'));
      expect(model.currentTime, isNotNull);
    });

    test('ConnectionPoolModel usage percentage and zero division safety', () {
      final pool = ConnectionPoolModel.fromMap({
        'total_connections': 15,
        'active_connections': 3,
        'idle_connections': 12,
        'idle_in_transaction': 0,
        'waiting_connections': 0,
        'max_connections': 100,
      });

      expect(pool.totalConnections, equals(15));
      expect(pool.activeConnections, equals(3));
      expect(pool.usagePercent, closeTo(15.0, 0.01));

      // Edge case: max_connections 0
      final emptyPool = ConnectionPoolModel.fromMap({
        'total_connections': 0,
        'active_connections': 0,
        'idle_connections': 0,
        'idle_in_transaction': 0,
        'waiting_connections': 0,
        'max_connections': 0,
      });
      expect(emptyPool.maxConnections, equals(100)); // Default fallback
    });

    test('TransactionsModel and CacheHitRatioModel calculations', () {
      final tx = TransactionsModel.fromMap({
        'xact_commit': 1000,
        'xact_rollback': 20,
        'conflicts': 0,
        'deadlocks': 0,
        'success_rate': 98.04,
      });
      expect(tx.xactCommit, equals(1000));
      expect(tx.xactRollback, equals(20));
      expect(tx.successRate, closeTo(98.04, 0.01));

      final cache = CacheHitRatioModel.fromMap({
        'blks_hit': 999900,
        'blks_read': 100,
        'ratio_percent': 99.99,
      });
      expect(cache.blksHit, equals(999900));
      expect(cache.ratioPercent, closeTo(99.99, 0.01));
    });

    test('Full DatabaseAnalyticsModel parsing and list mappings', () {
      final samplePayload = {
        'server_health': {
          'version': 'PostgreSQL 17.6',
          'uptime_seconds': 3600,
          'database_size_bytes': 10000000,
          'database_size_pretty': '10 MB',
        },
        'connection_pool': {
          'total_connections': 5,
          'active_connections': 1,
          'idle_connections': 4,
          'idle_in_transaction': 0,
          'waiting_connections': 0,
          'max_connections': 100,
        },
        'transactions': {
          'xact_commit': 5000,
          'xact_rollback': 10,
          'conflicts': 0,
          'deadlocks': 0,
          'success_rate': 99.8,
        },
        'cache_hit_ratio': {
          'blks_hit': 500000,
          'blks_read': 10,
          'ratio_percent': 100.0,
        },
        'query_stats': {
          'total_calls': 20000,
          'total_exec_time_ms': 15000.5,
          'avg_latency_ms': 0.75,
          'total_queries_tracked': 120,
        },
        'slowest_queries': [
          {
            'queryid': 101,
            'query': 'SELECT * FROM boards',
            'calls': 50,
            'total_exec_time': 250.0,
            'mean_exec_time': 5.0,
            'max_exec_time': 12.0,
            'min_exec_time': 1.0,
            'rows': 5000,
          }
        ],
        'frequent_queries': [
          {
            'queryid': 102,
            'query': 'SELECT count(*) FROM schools',
            'calls': 1000,
            'total_exec_time': 500.0,
            'mean_exec_time': 0.5,
            'max_exec_time': 2.0,
            'min_exec_time': 0.1,
            'rows': 1000,
          }
        ],
        'table_stats': [
          {
            'table_name': 'boards',
            'row_count': 100,
            'dead_row_count': 5,
            'bloat_ratio': 4.76,
            'total_size_bytes': 65536,
            'total_size_pretty': '64 kB',
            'table_size_bytes': 32768,
            'index_size_bytes': 32768,
            'seq_scans': 10,
            'index_scans': 50,
          }
        ],
        'live_processes': [
          {
            'pid': 1234,
            'usename': 'postgres',
            'client_addr': '127.0.0.1',
            'state': 'active',
            'query': 'SELECT 1;',
            'duration_seconds': 0.05,
          }
        ],
        'daily_history': [
          {
            'metric_date': '2026-10-24',
            'total_queries': 120,
            'total_calls': 20000,
            'total_exec_time': 15000.5,
            'avg_latency_ms': 0.75,
            'active_connections': 1,
            'database_size_bytes': 10000000,
            'database_size_pretty': '10 MB',
            'cache_hit_ratio': 100.0,
            'transactions_committed': 5000,
            'transactions_rolled_back': 10,
          }
        ],
      };

      final analytics = DatabaseAnalyticsModel.fromMap(samplePayload);

      expect(analytics.serverHealth.version, equals('PostgreSQL 17.6'));
      expect(analytics.connectionPool.activeConnections, equals(1));
      expect(analytics.queryStats.totalCalls, equals(20000));
      expect(analytics.slowestQueries.length, equals(1));
      expect(analytics.slowestQueries.first.query, equals('SELECT * FROM boards'));
      expect(analytics.frequentQueries.length, equals(1));
      expect(analytics.tableStats.length, equals(1));
      expect(analytics.tableStats.first.tableName, equals('boards'));
      expect(analytics.liveProcesses.length, equals(1));
      expect(analytics.liveProcesses.first.pid, equals(1234));
      expect(analytics.dailyHistory.length, equals(1));
      expect(analytics.dailyHistory.first.metricDate, equals('2026-10-24'));
    });

    test('Gracefully handles empty or corrupted map without throwing', () {
      final empty = DatabaseAnalyticsModel.fromMap({});
      expect(empty.serverHealth.uptimeSeconds, equals(0));
      expect(empty.connectionPool.totalConnections, equals(0));
      expect(empty.slowestQueries, isEmpty);
      expect(empty.frequentQueries, isEmpty);
      expect(empty.tableStats, isEmpty);
      expect(empty.liveProcesses, isEmpty);
      expect(empty.dailyHistory, isEmpty);
      expect(empty.storage.totalGb, equals(45.0));
      expect(empty.storage.usedGb, equals(12.2));
      expect(empty.cpu.cores, equals(4));
      expect(empty.ram.totalGb, equals(24.0));
      expect(empty.realtime.maxBoardCapacity, equals(500));
      expect(empty.platformDistribution.windowsPercent, equals(58.0));
      expect(empty.executiveHealth.healthScore, equals(99.8));
    });

    test('Executive models parse accurately with custom backend payload', () {
      final model = DatabaseAnalyticsModel.fromMap({
        'storage': {
          'total_gb': 48.0,
          'used_gb': 12.0,
          'free_gb': 36.0,
          'used_percent': 25.0,
          'database_size_bytes': 15000000,
          'database_size_pretty': '15 MB',
          'storage_files_pretty': '1.5 GB',
          'system_files_pretty': '10.5 GB',
        },
        'cpu': {
          'cores': 4,
          'model': 'Ampere ARM A1',
          'usage_percent': 7.5,
          'status': 'Normal & Dengeli',
        },
        'ram': {
          'total_gb': 24.0,
          'used_gb': 2.0,
          'free_gb': 22.0,
          'used_percent': 8.3,
          'status': 'Geniş Kapasite',
        },
        'realtime': {
          'connected_boards': 30,
          'total_boards': 102,
          'max_board_capacity': 500,
          'board_usage_percent': 6.0,
          'connected_users': 195,
          'max_user_capacity': 1000,
          'total_schools': 5,
          'licensed_schools': 5,
        },
        'school_comparison': [
          {
            'id': 'sch-1',
            'name': 'Çukurambar Safa',
            'city': 'Ankara',
            'is_licensed': true,
            'total_boards': 28,
            'online_boards': 20,
            'total_users': 71,
            'requests': 50000,
            'percentage': 35.0,
          }
        ],
        'platform_distribution': {
          'windows_percent': 60.0,
          'windows_requests': 90000,
          'mobile_percent': 30.0,
          'mobile_requests': 45000,
          'web_percent': 10.0,
          'web_requests': 15000,
        },
        'peak_hours': [
          {
            'time_range': '08:30 - 09:30',
            'title': 'Ders Başlangıcı',
            'intensity': 'En Yüksek',
            'percentage': 95,
          }
        ],
        'executive_health': {
          'health_score': 99.9,
          'status': 'Kusursuz',
          'uptime_pretty': '10 gün',
          'all_services_healthy': true,
        },
      });

      expect(model.storage.totalGb, equals(48.0));
      expect(model.storage.freeGb, equals(36.0));
      expect(model.cpu.cores, equals(4));
      expect(model.cpu.usagePercent, equals(7.5));
      expect(model.ram.usedGb, equals(2.0));
      expect(model.realtime.connectedBoards, equals(30));
      expect(model.schoolComparison.length, equals(1));
      expect(model.schoolComparison.first.name, equals('Çukurambar Safa'));
      expect(model.platformDistribution.windowsPercent, equals(60.0));
      expect(model.peakHours.first.percentage, equals(95));
      expect(model.executiveHealth.healthScore, equals(99.9));
    });

    test('Live Oracle VM production telemetry payload parsed accurately', () {
      final livePayload = {
        'storage': {
          'total_gb': 44.96,
          'used_gb': 11.41,
          'free_gb': 33.54,
          'used_percent': 25.4,
          'database_size_bytes': 15191187,
          'database_size_pretty': '14 MB',
          'storage_files_pretty': '5318 kB',
          'system_files_pretty': '11.41 GB'
        },
        'cpu': {
          'cores': 4,
          'model': 'Neoverse-N1 (Ampere ARM 4 Çekirdek Cloud vCPU)',
          'status': 'Normal & Dengeli',
          'usage_percent': 11.8
        },
        'ram': {
          'total_gb': 23.43,
          'used_gb': 2.18,
          'free_gb': 21.25,
          'used_percent': 9.3,
          'status': 'Geniş Kapasite'
        },
        'realtime': {
          'total_boards': 105,
          'connected_boards': 27,
          'max_board_capacity': 200,
          'board_usage_percent': 25.7,
          'connected_users': 193,
          'max_user_capacity': 1000,
          'total_schools': 5,
          'licensed_schools': 5
        },
        'school_comparison': [
          {
            'id': '828a7757-475d-4bfa-9cb8-13017db74241',
            'name': 'Çukurambar Safa Okulları',
            'city': 'Ankara',
            'is_licensed': true,
            'total_boards': 31,
            'online_boards': 20,
            'total_users': 71,
            'total_pairings': 106,
            'requests': 37305,
            'percentage': 60.5
          },
          {
            'id': 'bff5ec60-5daa-4181-9322-a0f03cab0ec2',
            'name': 'Gölbaşı Safa Okulları',
            'city': 'Ankara',
            'is_licensed': true,
            'total_boards': 28,
            'online_boards': 3,
            'total_users': 61,
            'total_pairings': 109,
            'requests': 12060,
            'percentage': 19.6
          }
        ],
        'platform_distribution': {
          'windows_percent': 93.5,
          'windows_requests': 132480,
          'mobile_percent': 5.5,
          'mobile_requests': 7740,
          'web_percent': 1.0,
          'web_requests': 1400
        },
        'peak_hours': [
          {
            'time_range': '08:00 - 09:00',
            'title': 'Ders Başlangıcı & İlk Yoklama',
            'intensity': 'En Yüksek',
            'percentage': 100
          }
        ],
        'executive_health': {
          'health_score': 99.2,
          'status': 'Kusursuz & Kesintisiz',
          'uptime_pretty': '7 gün 4 saat',
          'all_services_healthy': true
        }
      };

      final model = DatabaseAnalyticsModel.fromMap(livePayload);

      expect(model.storage.totalGb, equals(44.96));
      expect(model.storage.usedGb, equals(11.41));
      expect(model.storage.freeGb, equals(33.54));
      expect(model.storage.usedPercent, equals(25.4));
      expect(model.storage.databaseSizePretty, equals('14 MB'));
      expect(model.storage.storageFilesPretty, equals('5318 kB'));

      expect(model.cpu.cores, equals(4));
      expect(model.cpu.usagePercent, equals(11.8));
      expect(model.cpu.model, contains('Neoverse-N1'));

      expect(model.ram.totalGb, equals(23.43));
      expect(model.ram.usedGb, equals(2.18));
      expect(model.ram.freeGb, equals(21.25));
      expect(model.ram.usedPercent, equals(9.3));

      expect(model.realtime.totalBoards, equals(105));
      expect(model.realtime.connectedBoards, equals(27));
      expect(model.realtime.connectedUsers, equals(193));
      expect(model.realtime.totalSchools, equals(5));

      expect(model.schoolComparison.length, equals(2));
      expect(model.schoolComparison.first.name, equals('Çukurambar Safa Okulları'));
      expect(model.schoolComparison.first.requests, equals(37305));

      expect(model.platformDistribution.windowsPercent, equals(93.5));
      expect(model.platformDistribution.mobilePercent, equals(5.5));
      expect(model.platformDistribution.webPercent, equals(1.0));

      expect(model.executiveHealth.healthScore, equals(99.2));
      expect(model.executiveHealth.uptimePretty, equals('7 gün 4 saat'));
      expect(model.executiveHealth.allServicesHealthy, isTrue);
    });
  });
}
