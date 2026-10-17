import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tahta_kumandasi/presentation/screens/dashboard_screen.dart';
import 'package:tahta_kumandasi/presentation/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'dummyKeyForTestingDashboard1234567890',
      );
    } catch (_) {}
  });

  tearDown(() async {
    try {
      await Supabase.instance.client.removeAllChannels();
      Supabase.instance.client.realtime.disconnect();
    } catch (_) {}
  });

  Widget createDashboardScreen({String? schoolId, String? schoolName}) {
    return MaterialApp(
      home: DashboardScreen(
        initialSchoolId: schoolId,
        initialSchoolName: schoolName,
      ),
    );
  }

  group('DashboardScreen Comprehensive UI & Interaction Tests', () {
    testWidgets('Renders empty state when no school is assigned', (tester) async {
      await tester.pumpWidget(createDashboardScreen());
      await tester.pump();

      // Okul bilginiz bulunamadı uyarısı görünmeli
      expect(find.text('Okul bilginiz bulunamadı.'), findsOneWidget);

      // AppBar ikonları
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

      // Widget ağacını temizle
      await Supabase.instance.client.removeAllChannels();
      Supabase.instance.client.realtime.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Renders school header, greeting, Kademe chips, and favorites filter', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDashboardScreen(
        schoolId: 'test-school-1',
        schoolName: 'Atatürk Fen Lisesi',
      ));
      await tester.pump();

      // Okul adı ve karşılama
      expect(find.text('Atatürk Fen Lisesi'), findsOneWidget);
      expect(find.text('Merhaba Öğretmenim,'), findsOneWidget);
      expect(find.text('Derslikler'), findsOneWidget);
      expect(find.text('Favorilerim'), findsOneWidget);

      // Kademe Çipleri
      expect(find.text('Favoriler'), findsOneWidget);
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('İlkokul (1-4)'), findsOneWidget);
      expect(find.text('Ortaokul (5-8)'), findsOneWidget);
      expect(find.text('Lise (9-12)'), findsOneWidget);
      expect(find.text('Diğer'), findsOneWidget);

      // Widget ağacını temizle
      await Supabase.instance.client.removeAllChannels();
      Supabase.instance.client.realtime.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Tapping Kademe chip updates grade options and selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDashboardScreen(
        schoolId: 'test-school-1',
        schoolName: 'Atatürk Fen Lisesi',
      ));
      await tester.pump();

      // Lise kademesini seç
      final liseChip = find.text('Lise (9-12)');
      expect(liseChip, findsOneWidget);
      await tester.tap(liseChip);
      await tester.pump();

      // Sınıf seviyeleri görünmeli
      expect(find.text('9. Sınıf'), findsOneWidget);
      expect(find.text('10. Sınıf'), findsOneWidget);
      expect(find.text('11. Sınıf'), findsOneWidget);
      expect(find.text('12. Sınıf'), findsOneWidget);

      // Widget ağacını temizle
      await Supabase.instance.client.removeAllChannels();
      Supabase.instance.client.realtime.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Tapping Help and Settings icons opens tutorial guide and settings sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDashboardScreen(
        schoolId: 'test-school-1',
        schoolName: 'Atatürk Fen Lisesi',
      ));
      await tester.pump();

      // 1. İpuçları & Rehber butonuna tıkla
      final helpBtn = find.byIcon(Icons.help_outline_rounded);
      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      // Öğretmen rehberinin açıldığını doğrula
      expect(find.text('Öğretmen Kullanım Rehberi'), findsOneWidget);

      // Kapat butonuyla kapat
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 2. Ayarlar ve Profil butonuna tıkla
      final settingsBtn = find.byIcon(Icons.settings_rounded);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Ayarlar çekmecesindeki aksiyonların listelendiğini doğrula
      expect(find.text('Sorun / Arıza Bildir'), findsOneWidget);
      expect(find.text('Kullanım Rehberi & İpuçları'), findsOneWidget);
      expect(find.text('Hesap Güvenliği'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);

      // Hesap Güvenliği'ne basınca Hesap Silme bilgilendirme diyaloğu açılmalı
      await tester.tap(find.text('Hesap Güvenliği'));
      await tester.pumpAndSettle();

      expect(find.text('Hesap Silme'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Anladım'), findsOneWidget);

      // Anladım ile diyaloğu kapat
      await tester.tap(find.widgetWithText(TextButton, 'Anladım'));
      await tester.pumpAndSettle();

      // Ayarları tekrar açıp Çıkış Yap'a bas
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Çıkış Yap'));
      await tester.pumpAndSettle();

      // LoginScreen'e yönlendirildiğini doğrula
      expect(find.byType(LoginScreen), findsOneWidget);

      // Widget ağacını temizle
      await Supabase.instance.client.removeAllChannels();
      Supabase.instance.client.realtime.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
