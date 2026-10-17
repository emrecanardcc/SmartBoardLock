import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/presentation/screens/login_screen.dart';

void main() {
  Widget createLoginScreen() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  group('LoginScreen Comprehensive UI & Interaction Tests', () {
    testWidgets('Renders all branding, inputs, and action buttons', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      // 1. Marka ve Başlıklar
      expect(find.text('Akıllı Tahta Sistemi'), findsOneWidget);
      expect(find.text('Kurum Yöneticisi & Öğretmen Girişi'), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);

      // 2. Form Girdi Alanları
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(TextField, 'E-Posta Adresi'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Şifre'), findsOneWidget);

      // 3. Giriş Butonu
      expect(find.widgetWithText(ElevatedButton, 'GİRİŞ YAP'), findsOneWidget);

      // 4. Gizlilik Politikası Linki
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
    });

    testWidgets('Tapping GİRİŞ YAP with empty fields shows warning SnackBar', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      // Butona boşken tıkla
      final loginBtn = find.widgetWithText(ElevatedButton, 'GİRİŞ YAP');
      await tester.tap(loginBtn);
      await tester.pump(); // SnackBar animasyonunu başlat

      // Uyarı mesajının belirdiğini doğrula
      expect(find.text('Lütfen e-posta ve şifrenizi eksiksiz girin.'), findsOneWidget);
    });

    testWidgets('Typing into email and password inputs updates text controllers', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextField, 'E-Posta Adresi');
      final passwordField = find.widgetWithText(TextField, 'Şifre');

      await tester.enterText(emailField, 'ogretmen@okul.com');
      await tester.enterText(passwordField, 'GizliSifre123');
      await tester.pump();

      expect(find.text('ogretmen@okul.com'), findsOneWidget);
      expect(find.text('GizliSifre123'), findsOneWidget);
    });

    testWidgets('Toggling password visibility switches obscureText state', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.widgetWithText(TextField, 'Şifre');
      TextField passwordWidget = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordWidget.obscureText, isTrue);

      // Göz ikonuna tıkla
      final visibilityIcon = find.byIcon(Icons.visibility_off_rounded);
      expect(visibilityIcon, findsOneWidget);
      await tester.tap(visibilityIcon);
      await tester.pump();

      // Artık görünür olmalı
      passwordWidget = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordWidget.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

      // Tekrar tıkla, gizlenmeli
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump();
      passwordWidget = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordWidget.obscureText, isTrue);
    });
  });
}
