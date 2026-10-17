import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahta_kumandasi/presentation/screens/totp_screen.dart';

void main() {
  testWidgets('TotpScreen enters 4 digits, calculates 6-digit pin and unfocuses', (WidgetTester tester) async {
    const testSecret = 'TESTOFFLINESECRET';
    const testBoardId = 'board-123';
    const testBoardName = '10-A Sınıfı';

    await tester.pumpWidget(
      const MaterialApp(
        home: TotpScreen(
          boardId: testBoardId,
          offlineSecret: testSecret,
          boardName: testBoardName,
        ),
      ),
    );

    // Initial state: Title is displayed
    expect(find.text('10-A Sınıfı - Acil Durum'), findsOneWidget);
    expect(find.text('İnternet Bağlantısı Yoksa'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Type 4 digits
    await tester.enterText(find.byType(TextField), '4829');
    await tester.pump();

    // Verify 6-digit PIN is displayed
    expect(find.text('GİRİLECEK ŞİFRE (TAHTAYA YAZIN)'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    // Verify TextField has lost focus
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isFalse);

    // Verify "Klavyeyi Kapat / Kodu Göster" button exists and is clickable
    expect(find.text('Klavyeyi Kapat / Kodu Göster'), findsOneWidget);
    await tester.tap(find.text('Klavyeyi Kapat / Kodu Göster'));
    await tester.pump();
  });
}
