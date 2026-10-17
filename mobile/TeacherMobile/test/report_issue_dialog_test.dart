import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tahta_kumandasi/presentation/widgets/report_issue_dialog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'dummyKeyForTestingOnly1234567890',
      );
    } catch (_) {}
  });

  Widget createReportIssueDialog({String? initialBoardName}) {
    return MaterialApp(
      home: Scaffold(
        body: ReportIssueDialog(
          schoolId: 'test-school-id',
          initialBoardName: initialBoardName,
          userRole: 'teacher',
          userName: 'Ahmet Yılmaz',
        ),
      ),
    );
  }

  group('ReportIssueDialog Comprehensive Tests', () {
    testWidgets('Renders dialog header, category dropdown, inputs, and submit button', (tester) async {
      await tester.pumpWidget(createReportIssueDialog(initialBoardName: '10-A Sınıfı'));
      await tester.pump();

      // Başlık ve açıklama
      expect(find.text('Sorun / Arıza Bildir'), findsOneWidget);
      expect(find.text('Geliştirici & Teknik Destek Ekibine doğrudan iletilir'), findsOneWidget);

      // Alan etiketleri
      expect(find.text('Sorun Kategorisi'), findsOneWidget);
      expect(find.text('İlgili Akıllı Tahta / Derslik'), findsOneWidget);
      expect(find.text('Sorun Başlığı'), findsOneWidget);
      expect(find.text('Açıklama ve Detaylar'), findsOneWidget);

      // Tahta adı ön doldurulmuş olmalı
      expect(find.text('10-A Sınıfı'), findsOneWidget);

      // Gönder butonu
      expect(find.widgetWithText(ElevatedButton, 'Sorun Bildirimini Gönder'), findsOneWidget);

      // Kapat ikonu
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Validates empty title and description on submit', (tester) async {
      await tester.pumpWidget(createReportIssueDialog());
      await tester.pump();

      // Submit butonunu görünür yap ve tıkla
      final submitBtn = find.widgetWithText(ElevatedButton, 'Sorun Bildirimini Gönder');
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump();

      // Hata mesajları görünmeli
      expect(find.text('Lütfen bir başlık girin'), findsOneWidget);
      expect(find.text('Lütfen açıklama girin'), findsOneWidget);
    });

    testWidgets('Validates min length requirements for title (<5) and description (<10)', (tester) async {
      await tester.pumpWidget(createReportIssueDialog());
      await tester.pump();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(1), 'Kısa');
      await tester.enterText(textFields.at(2), 'Kısa Açık');
      await tester.pump();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Sorun Bildirimini Gönder');
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('En az 5 karakter yazın'), findsOneWidget);
      expect(find.text('Lütfen en az 10 karakter ile açıklayın'), findsOneWidget);
    });

    testWidgets('Dropdown category change updates selected value', (tester) async {
      await tester.pumpWidget(createReportIssueDialog());
      await tester.pump();

      // Varsayılan kategori görünür
      expect(find.text('Tahta Kilit / Kiosk Uygulaması'), findsOneWidget);

      // Dropdown'ı aç
      await tester.tap(find.text('Tahta Kilit / Kiosk Uygulaması'));
      await tester.pumpAndSettle();

      // Donanım kategorisini seç
      final hardwareOption = find.text('Donanım / Dokunmatik / Ekran').last;
      await tester.tap(hardwareOption);
      await tester.pumpAndSettle();

      // Seçilen değer ekranda görünmeli
      expect(find.text('Donanım / Dokunmatik / Ekran'), findsOneWidget);
    });
  });
}
