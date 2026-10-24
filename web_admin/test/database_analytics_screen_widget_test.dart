// test/database_analytics_screen_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:web_admin/data/models/database_analytics_model.dart';
import 'package:web_admin/data/repositories/admin_repository.dart';
import 'package:web_admin/presentation/screens/database_analytics_screen.dart';

class FakeAdminRepository extends Fake implements AdminRepository {
  final DatabaseAnalyticsModel analyticsData;
  FakeAdminRepository(this.analyticsData);

  @override
  Future<DatabaseAnalyticsModel> getDatabaseAnalytics() async {
    return analyticsData;
  }

  @override
  Future<bool> cancelBackendProcess(int targetPid) async => true;

  @override
  Future<bool> resetDatabaseStats() async => true;

  @override
  Future<bool> triggerTableAnalyze(String tableName) async => true;
}

DatabaseAnalyticsModel createTestAnalytics() {
  return DatabaseAnalyticsModel.fromMap({
    'server_health': {
      'version': 'PostgreSQL 17.6',
      'uptime_seconds': 86400,
      'database_size_bytes': 20971520,
      'database_size_pretty': '20 MB',
    },
    'connection_pool': {
      'total_connections': 12,
      'active_connections': 4,
      'idle_connections': 8,
      'idle_in_transaction': 0,
      'waiting_connections': 0,
      'max_connections': 100,
    },
    'transactions': {
      'xact_commit': 125000,
      'xact_rollback': 350,
      'conflicts': 0,
      'deadlocks': 0,
      'success_rate': 99.72,
    },
    'cache_hit_ratio': {
      'blks_hit': 995000,
      'blks_read': 5000,
      'ratio_percent': 99.50,
    },
    'query_stats': {
      'total_calls': 3500000,
      'total_exec_time_ms': 120000.5,
      'avg_latency_ms': 0.034,
      'total_queries_tracked': 45,
    },
    'slowest_queries': [
      {
        'queryid': 101,
        'query': 'SELECT * FROM boards WHERE school_id = \$1',
        'calls': 500,
        'total_exec_time': 1250.0,
        'mean_exec_time': 2.5,
        'max_exec_time': 15.0,
        'min_exec_time': 0.8,
        'rows': 50,
      }
    ],
    'frequent_queries': [
      {
        'queryid': 202,
        'query': 'SELECT id, is_active FROM boards',
        'calls': 150000,
        'total_exec_time': 3000.0,
        'mean_exec_time': 0.02,
        'max_exec_time': 1.2,
        'min_exec_time': 0.01,
        'rows': 150,
      }
    ],
    'table_stats': [
      {
        'table_name': 'boards',
        'row_count': 120,
        'dead_row_count': 5,
        'bloat_ratio': 4.0,
        'total_size_bytes': 524288,
        'total_size_pretty': '512 kB',
        'table_size_bytes': 262144,
        'index_size_bytes': 262144,
        'seq_scans': 250,
        'index_scans': 15000,
      }
    ],
    'live_processes': [
      {
        'pid': 4567,
        'usename': 'postgres',
        'client_addr': '130.61.78.192',
        'state': 'active',
        'query': 'SELECT count(*) FROM boards',
        'duration_seconds': 0.12,
        'wait_event': null,
      }
    ],
    'daily_history': [
      {
        'metric_date': '2026-10-24',
        'total_queries': 45,
        'total_calls': 3500000,
        'total_exec_time': 120000.5,
        'avg_latency_ms': 0.034,
        'active_connections': 4,
        'database_size_bytes': 20971520,
        'database_size_pretty': '20 MB',
        'cache_hit_ratio': 99.50,
        'transactions_committed': 125000,
        'transactions_rolled_back': 350,
      }
    ],
  });
}

Widget createTestWidget(Size size, {double textScale = 1.0}) {
  final fakeRepo = FakeAdminRepository(createTestAnalytics());
  return Provider<AdminRepository>.value(
    value: fakeRepo,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: const SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: DatabaseAnalyticsScreen(),
        ),
      ),
    ),
  );
}

void main() {
  group('DatabaseAnalyticsScreen Responsive & Overflow Tests', () {
    testWidgets('Renders without overflow on Ultra-Wide screens (1920x1080)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1920, 1080)));
      await tester.pumpAndSettle();

      expect(find.text('Veritabanı & Telemetri Analitiği'), findsOneWidget);
      expect(find.text('⚡ Veritabanı Studio'), findsWidgets);
      expect(find.text('Toplam İstek & QPS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on Medium Desktop / 125% DPI Laptop (1200x800)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(960, 640), textScale: 1.25));
      await tester.pumpAndSettle();

      expect(find.text('Veritabanı & Telemetri Analitiği'), findsOneWidget);
      expect(find.text('Bağlantı Havuzu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on Compact / Tablet screens (800x600)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(800, 600)));
      await tester.pumpAndSettle();

      expect(find.text('Veritabanı & Telemetri Analitiği'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Switches tabs cleanly between Tables, Queries, and Connection Info', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Default tab: Tablolar & Depolama
      expect(find.text('boards'), findsOneWidget);

      // Switch to Sorgu Analitiği
      await tester.ensureVisible(find.text('Sorgu Analitiği'));
      await tester.tap(find.text('Sorgu Analitiği'));
      await tester.pumpAndSettle();
      expect(find.text('En Çok Zaman Alan Sorgular (En Yavaş)'), findsOneWidget);

      // Switch to Bağlantı & Konsol Bilgisi
      await tester.ensureVisible(find.text('Bağlantı & Konsol Bilgisi'));
      await tester.tap(find.text('Bağlantı & Konsol Bilgisi'));
      await tester.pumpAndSettle();
      expect(find.text('Doğrudan PostgreSQL (Port 5432)'), findsOneWidget);
      expect(find.text('Supavisor Pooler (Port 6543)'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
