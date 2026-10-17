import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tahta_kumandasi/presentation/screens/board_control_screen.dart';

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

  Widget createBoardControlScreen({
    String boardId = 'test-board-123',
    String boardName = '10-A Matematik Tahtası',
    String offlineSecret = 'TEST_SECRET_KEY_123',
    bool isSchoolLicensed = true,
  }) {
    return MaterialApp(
      home: BoardControlScreen(
        boardId: boardId,
        boardName: boardName,
        offlineSecret: offlineSecret,
        isSchoolLicensed: isSchoolLicensed,
      ),
    );
  }

  group('BoardControlScreen UI & Functionality Widget Tests', () {
    testWidgets('Renders board name, offline toggle button, and main action button', (tester) async {
      await tester.pumpWidget(createBoardControlScreen());
      await tester.pump();

      // 1. Başlıkta tahta adı
      expect(find.text('10-A Matematik Tahtası'), findsOneWidget);

      // 2. İnternet yoksa tıklayın butonu
      expect(find.text('İnternet Yoksa Buraya Tıklayın'), findsOneWidget);

      // 3. Varsayılan kilitli durumda ana aksiyon butonu
      expect(find.text('QR Okutarak Kilidi Aç'), findsOneWidget);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Expired license disables action button and shows expired banner', (tester) async {
      await tester.pumpWidget(createBoardControlScreen(isSchoolLicensed: false));
      await tester.pump();

      // Lisans doldu uyarısı
      expect(find.text('Lisans Süresi Dolmuştur'), findsOneWidget);
      expect(find.byIcon(Icons.gpp_bad_rounded), findsOneWidget);

      // Butona tıklandığında SnackBar uyarısı
      final actionBtn = find.widgetWithText(ElevatedButton, 'Lisans Süresi Dolmuştur');
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await tester.pump();

      expect(find.textContaining('Kurum lisansı sona ermiştir'), findsOneWidget);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('Expanding offline mode reveals 4-digit challenge input and keyboard hide button', (tester) async {
      await tester.pumpWidget(createBoardControlScreen(offlineSecret: 'OKUL_SECRET_4829'));
      await tester.pump();

      // Çevrimdışı butonuna dokunarak genişlet
      final offlineBtn = find.text('İnternet Yoksa Buraya Tıklayın');
      await tester.tap(offlineBtn);
      await tester.pumpAndSettle();

      // 4 Haneli Girdi Alanı
      final challengeInput = find.widgetWithText(TextField, 'Tahtadaki 4 Haneli Kodu Girin');
      expect(challengeInput, findsOneWidget);

      // Klavyeyi Kapat Butonu
      expect(find.widgetWithText(TextButton, 'Klavyeyi Kapat'), findsOneWidget);

      // 4 Hane girildiğinde 6 haneli yanıt PIN üretilmeli
      await tester.enterText(challengeInput, '4829');
      await tester.pumpAndSettle();

      // 6 Haneli PIN alanının hesaplandığını ve başlığının belirdiğini doğrula
      expect(find.text('GİRİLECEK ŞİFRE'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);

      // Zamanlayıcıları temizle
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
    });
  });
}
