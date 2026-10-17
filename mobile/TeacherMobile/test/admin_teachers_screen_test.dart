import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tahta_kumandasi/presentation/screens/admin_teachers_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: 'SUPABASE_URL=http://127.0.0.1:54321\nSUPABASE_ANON_KEY=dummyKey\n');
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
      Supabase.instance.client.realtime.disconnect();
    } catch (_) {}
  });

  Widget createAdminTeachersScreen() {
    return const MaterialApp(
      home: AdminTeachersScreen(),
    );
  }

  group('AdminTeachersScreen Comprehensive UI & Interaction Tests', () {
    testWidgets('Renders app bar title, stats, search bar, and FAB', (tester) async {
      await tester.pumpWidget(createAdminTeachersScreen());
      await tester.pump();

      // 1. Başlık
      expect(find.text('Öğretmen Yetkilendirme'), findsOneWidget);

      // 2. İstatistik Kartları
      expect(find.text('Yetkili Öğretmen'), findsOneWidget);
      expect(find.text('Aktif Kadro'), findsOneWidget);
      expect(find.text('Tam Yetkilendirildi'), findsOneWidget);

      // 3. Arama Çubuğu
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Öğretmen ara...'), findsOneWidget);

      // 4. Öğretmen Ekle FAB
      expect(find.widgetWithText(FloatingActionButton, 'Öğretmen Ekle'), findsOneWidget);

      // Widget ağacını temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Entering search text updates query and shows clear button', (tester) async {
      await tester.pumpWidget(createAdminTeachersScreen());
      await tester.pump();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Metin gir
      await tester.enterText(searchField, 'Ahmet');
      await tester.pump();

      // Temizleme butonu görünmeli
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Temizleme butonuna tıkla
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      // Metin temizlenmeli ve temizleme butonu kaybolmalı
      expect(find.text('Ahmet'), findsNothing);
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      // Widget ağacını temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Tapping FAB opens Add Teacher bottom sheet with all fields and actions', (tester) async {
      await tester.pumpWidget(createAdminTeachersScreen());
      await tester.pump();

      // FAB'a tıkla
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Öğretmen Ekle'));
      await tester.pumpAndSettle();

      // Alt Çekmece Başlığı ve Alanları
      expect(find.text('Yeni Öğretmen Yetkilendir'), findsOneWidget);
      expect(find.text('Giriş bilgileriyle akıllı tahtaları açabilir'), findsOneWidget);
      expect(find.text('Ad Soyad'), findsOneWidget);
      expect(find.text('E-Posta Adresi'), findsOneWidget);
      expect(find.text('Geçici Giriş Şifresi'), findsOneWidget);

      // Şifre gizleme/gösterme ikonu
      final visibilityIcon = find.byIcon(Icons.visibility_off_rounded);
      expect(visibilityIcon, findsOneWidget);
      await tester.tap(visibilityIcon);
      await tester.pump();
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

      // Kaydet butonu
      final saveBtn = find.widgetWithText(ElevatedButton, 'Öğretmeni Kaydet ve Yetkilendir');
      expect(saveBtn, findsOneWidget);

      // Boş alanlarla kaydete basıldığında validasyon uyarısı çıkmalı
      await tester.tap(saveBtn);
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Lütfen tüm alanları geçerli şekilde doldurun (şifre en az 6 hane).'), findsOneWidget);

      // Kapat butonuna basarak çekmeceyi kapat
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Öğretmen Yetkilendir'), findsNothing);

      // Widget ağacını temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
