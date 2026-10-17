import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/presentation/widgets/tutorial_tips_dialog.dart';

void main() {
  Widget createDialog({required String userRole}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => TutorialTipsDialog.show(context, userRole: userRole),
            child: const Text('Rehberi Aç'),
          ),
        ),
      ),
    );
  }

  group('TutorialTipsDialog Comprehensive Tests', () {
    testWidgets('Renders Teacher Guide with all 5 teacher tips and header', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDialog(userRole: 'teacher'));
      await tester.pump();

      // Rehberi Aç butonuna tıkla
      await tester.tap(find.text('Rehberi Aç'));
      await tester.pumpAndSettle();

      // Başlık ve alt başlık
      expect(find.text('Öğretmen Kullanım Rehberi'), findsOneWidget);
      expect(find.text('Sınıf360 Akıllı Tahta Kilit Sistemi İpuçları'), findsOneWidget);

      // Öğretmen İpuçları
      expect(find.text('1. Favoriler İlk Ekranınızda Açılır'), findsOneWidget);
      expect(find.text('2. QR Kod ile Hızlı Kilit Açma'), findsOneWidget);
      expect(find.text('3. İnternetsiz Çevrimdışı TOTP Şifresi'), findsOneWidget);
      expect(find.text('4. Kademe & 1-12 Sınıf Filtreleri'), findsOneWidget);
      expect(find.text('5. Sorun & Arıza Bildirimi'), findsOneWidget);

      // Anladım butonu ve kapatma
      final dismissBtn = find.widgetWithText(ElevatedButton, 'Anladım');
      expect(dismissBtn, findsOneWidget);
      await tester.tap(dismissBtn);
      await tester.pumpAndSettle();

      // Diyalog kapanmış olmalı
      expect(find.text('Öğretmen Kullanım Rehberi'), findsNothing);
    });

    testWidgets('Renders School Admin Guide with all 5 admin tips and closes via close icon', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createDialog(userRole: 'school_admin'));
      await tester.pump();

      // Rehberi Aç butonuna tıkla
      await tester.tap(find.text('Rehberi Aç'));
      await tester.pumpAndSettle();

      // Müdür Rehberi Başlığı
      expect(find.text('Okul Müdürü Yönetim Rehberi'), findsOneWidget);

      // Müdür İpuçları
      expect(find.text('1. Acil Durumda Tümünü Kilitle'), findsOneWidget);
      expect(find.text('2. 1-12 Sınıf ve Kademe Yönetimi'), findsOneWidget);
      expect(find.text('3. Öğretmen Yetkilendirme'), findsOneWidget);
      expect(find.text('4. Yeni Tahta Eşleştirme'), findsOneWidget);
      expect(find.text('5. Doğrudan Destek Talebi'), findsOneWidget);

      // Kapat butonu ile kapatma
      final closeIcon = find.byIcon(Icons.close_rounded);
      expect(closeIcon, findsOneWidget);
      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Okul Müdürü Yönetim Rehberi'), findsNothing);
    });
  });
}
