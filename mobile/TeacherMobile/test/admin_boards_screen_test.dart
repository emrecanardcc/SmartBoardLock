import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tahta_kumandasi/presentation/screens/admin_boards_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.dummyKeyForWidgetTestingOnly1234567890',
      );
    } catch (_) {}
  });

  tearDown(() async {
    try {
      await Supabase.instance.client.removeAllChannels();
    } catch (_) {}
  });

  Widget createAdminBoardsScreen() {
    return const MaterialApp(
      home: AdminBoardsScreen(),
    );
  }

  group('AdminBoardsScreen Comprehensive UI & Interaction Tests', () {
    testWidgets('Renders panel title, kademe chips, action buttons, and FAB', (tester) async {
      await tester.pumpWidget(createAdminBoardsScreen());
      await tester.pump();

      // 1. Başlıklar
      expect(find.text('Kurum Yönetim Paneli'), findsOneWidget);

      // 2. Kademe Seçici Çipleri
      expect(find.text('Tümü'), findsWidgets);
      expect(find.text('İlkokul (1-4)'), findsOneWidget);
      expect(find.text('Ortaokul (5-8)'), findsOneWidget);
      expect(find.text('Lise (9-12)'), findsOneWidget);

      // 3. Acil Durum Tümünü Kilitle Butonu
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);

      // 4. Yeni Tahta Eşle Butonu (FAB)
      expect(find.widgetWithText(FloatingActionButton, 'Yeni Tahta Eşle'), findsOneWidget);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Tapping emergency Tümünü Kilitle opens confirmation dialog with İptal and Hepsini Kilitle', (tester) async {
      await tester.pumpWidget(createAdminBoardsScreen());
      await tester.pump();

      final emergencyBtn = find.byIcon(Icons.shield_rounded);
      await tester.tap(emergencyBtn);
      await tester.pumpAndSettle();

      // Onay Diyaloğu Başlığı ve İçeriği
      expect(find.text('Tümünü Kilitle'), findsOneWidget); // Dialog title
      expect(find.text('Okuldaki tüm akıllı tahtaları kilitlemek istediğinize emin misiniz?'), findsOneWidget);

      // İptal ve Hepsini Kilitle Butonları
      expect(find.widgetWithText(TextButton, 'İptal'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Hepsini Kilitle'), findsOneWidget);

      // İptal'e basınca diyalog kapanmalı
      await tester.tap(find.widgetWithText(TextButton, 'İptal'));
      await tester.pumpAndSettle();

      expect(find.text('Okuldaki tüm akıllı tahtaları kilitlemek istediğinize emin misiniz?'), findsNothing);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Tapping Kademe chips updates selection state', (tester) async {
      await tester.pumpWidget(createAdminBoardsScreen());
      await tester.pump();

      final liseChip = find.text('Lise (9-12)');
      expect(liseChip, findsOneWidget);
      await tester.tap(liseChip);
      await tester.pump();

      // Seçim yapıldıktan sonra sınıf seçeneklerinin güncellendiğini doğrula
      expect(find.text('9. Sınıf'), findsOneWidget);
      expect(find.text('10. Sınıf'), findsOneWidget);
      expect(find.text('11. Sınıf'), findsOneWidget);
      expect(find.text('12. Sınıf'), findsOneWidget);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });
}
