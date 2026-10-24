// test/database_analytics_screen_widget_test.dart
import 'dart:ui';
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
    'storage': {
      'total_gb': 45.0,
      'used_gb': 12.2,
      'free_gb': 32.8,
      'used_percent': 27.1,
      'database_size_bytes': 20971520,
      'database_size_pretty': '20 MB',
      'storage_files_pretty': '1.2 GB',
      'system_files_pretty': '10.8 GB',
    },
    'cpu': {
      'cores': 4,
      'model': 'Ampere ARM 4 Çekirdek Cloud vCPU',
      'usage_percent': 5.4,
      'status': 'Normal & Dengeli',
    },
    'ram': {
      'total_gb': 24.0,
      'used_gb': 1.82,
      'free_gb': 22.18,
      'used_percent': 7.6,
      'status': 'Geniş Kapasite',
    },
    'realtime': {
      'connected_boards': 27,
      'total_boards': 102,
      'max_board_capacity': 500,
      'board_usage_percent': 5.4,
      'connected_users': 193,
      'max_user_capacity': 1000,
      'total_schools': 5,
      'licensed_schools': 5,
    },
    'usage_timeline': {
      'daily': [
        {'label': '08:00', 'requests': 1940, 'active_boards': 22},
        {'label': '10:00', 'requests': 4250, 'active_boards': 28},
        {'label': '12:00', 'requests': 2900, 'active_boards': 26},
        {'label': '14:00', 'requests': 4310, 'active_boards': 28},
      ],
      'weekly': [
        {'label': 'Pazartesi', 'requests': 34200, 'active_boards': 28},
        {'label': 'Salı', 'requests': 36800, 'active_boards': 28},
      ],
      'monthly': [
        {'label': '1. Hafta', 'requests': 182400, 'active_boards': 28},
        {'label': '2. Hafta', 'requests': 194200, 'active_boards': 28},
      ],
    },
    'school_comparison': [
      {
        'id': 'sch-1',
        'name': 'Çukurambar Safa Okulları',
        'city': 'Ankara',
        'is_licensed': true,
        'total_boards': 28,
        'online_boards': 20,
        'total_users': 71,
        'requests': 74850,
        'percentage': 35.8,
      },
      {
        'id': 'sch-2',
        'name': 'Gölbaşı Safa Okulları',
        'city': 'Ankara',
        'is_licensed': true,
        'total_boards': 28,
        'online_boards': 4,
        'total_users': 61,
        'requests': 60120,
        'percentage': 28.7,
      },
    ],
    'platform_distribution': {
      'windows_percent': 58.0,
      'windows_requests': 81200,
      'mobile_percent': 32.0,
      'mobile_requests': 44800,
      'web_percent': 10.0,
      'web_requests': 14000,
    },
    'peak_hours': [
      {
        'time_range': '08:30 - 09:30',
        'title': 'Ders Başlangıcı & İlk Yoklama',
        'intensity': 'En Yüksek',
        'percentage': 92,
      },
      {
        'time_range': '12:30 - 13:30',
        'title': 'Öğle Molası & Ders Geçişi',
        'intensity': 'Yüksek',
        'percentage': 70,
      },
    ],
    'executive_health': {
      'health_score': 99.8,
      'status': 'Kusursuz & Kesintisiz',
      'uptime_pretty': '7 gün 5 saat',
      'all_services_healthy': true,
    },
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
  group('DatabaseAnalyticsScreen Executive Dashboard Tests', () {
    testWidgets('Renders executive dashboard without overflow on Ultra-Wide (1920x1080)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1920, 1080)));
      await tester.pumpAndSettle();

      // Executive Header
      expect(find.text('Sistem & Kullanım Analitiği'), findsOneWidget);

      // Verify 1-click database studio button is completely REMOVED as requested
      expect(find.text('⚡ Veritabanı Studio'), findsNothing);

      // 4 Executive KPI Cards
      expect(find.text('Sunucu Depolama'), findsOneWidget);
      expect(find.text('İşlemci (CPU) Yükü'), findsOneWidget);
      expect(find.text('Bellek (RAM) Durumu'), findsOneWidget);
      expect(find.text('Canlı Bağlı Cihazlar'), findsOneWidget);

      // Charts and Comparisons
      expect(find.text('Okul Bazlı Kullanım ve Kıyaslama'), findsOneWidget);
      expect(find.text('Platform & Cihaz Kullanımı'), findsOneWidget);
      expect(find.text('Günün En Yoğun Saatleri (Ders Saatleri Yoğunluğu)'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on Medium Desktop / 125% DPI (1200x800)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(960, 640), textScale: 1.25));
      await tester.pumpAndSettle();

      expect(find.text('Sistem & Kullanım Analitiği'), findsOneWidget);
      expect(find.text('Sunucu Depolama'), findsOneWidget);
      expect(find.text('⚡ Veritabanı Studio'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders without overflow on Compact / Tablet screens (800x600)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(800, 600)));
      await tester.pumpAndSettle();

      expect(find.text('Sistem & Kullanım Analitiği'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Switches timeline mode between Günlük, Haftalık, and Aylık', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Default: Günlük
      expect(find.text('Bugünün Saatlik İstek ve Kullanım Trafiği'), findsOneWidget);

      // Switch to Haftalık
      await tester.tap(find.text('Haftalık'));
      await tester.pumpAndSettle();
      expect(find.text('Haftalık İstek ve Kullanım Dağılımı'), findsOneWidget);

      // Switch to Aylık
      await tester.tap(find.text('Aylık'));
      await tester.pumpAndSettle();
      expect(find.text('Aylık Sistem Geneli İstek Hacmi'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Displays school rankings and platform usage breakdown correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1400, 900)));
      await tester.pumpAndSettle();

      // School rankings
      expect(find.text('Çukurambar Safa Okulları'), findsOneWidget);
      expect(find.text('Gölbaşı Safa Okulları'), findsOneWidget);
      expect(find.text('%35.8 Pay'), findsOneWidget);
      expect(find.text('%28.7 Pay'), findsOneWidget);

      // Platform distribution
      expect(find.text('Akıllı Tahta (Windows)'), findsOneWidget);
      expect(find.text('Öğretmen & İdare (Mobil)'), findsOneWidget);
      expect(find.text('Yönetim Paneli (Web)'), findsOneWidget);
      expect(find.text('%58.0'), findsNWidgets(2));
      expect(find.text('%32.0'), findsNWidgets(2));
      expect(find.text('%10.0'), findsNWidgets(2));

      // Timeline platform badges
      expect(find.text('🪟 Windows Tahta'), findsOneWidget);
      expect(find.text('📱 Öğretmen Mobil'), findsOneWidget);
      expect(find.text('🌐 Web Yönetim Paneli'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Interactive chart hover and zero-data edge cases render cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Find CustomPaint of the chart and simulate mouse pointer hover
      final customPaints = find.byType(CustomPaint);
      expect(customPaints, findsWidgets);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(customPaints.at(1)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Gracefully handles empty data without NaN crash', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyAnalytics = DatabaseAnalyticsModel.fromMap({});
      final fakeRepo = FakeAdminRepository(emptyAnalytics);

      await tester.pumpWidget(
        Provider<AdminRepository>.value(
          value: fakeRepo,
          child: const MaterialApp(
            home: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: DatabaseAnalyticsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sistem & Kullanım Analitiği'), findsOneWidget);
      expect(find.text('Sunucu Depolama'), findsOneWidget);
      expect(find.text('⚡ Veritabanı Studio'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
