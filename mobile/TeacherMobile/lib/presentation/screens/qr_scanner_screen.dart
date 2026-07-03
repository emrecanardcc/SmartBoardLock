import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/datasources/supabase_datasource.dart';

class QrScannerScreen extends StatefulWidget {
  // YENİ: Artık test verisi yok, bu ekran açılırken hangi tahtayı beklediğimizi bilecek.
  final String expectedBoardId;
  final String expectedOfflineSecret;
  final String boardName;

  const QrScannerScreen({
    super.key,
    required this.expectedBoardId,
    required this.expectedOfflineSecret,
    required this.boardName,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final SupabaseDatasource _datasource = SupabaseDatasource();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return; // Arka arkaya 100 kere okumasını engeller

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String rawValue = barcodes.first.rawValue!;
      
      setState(() { _isProcessing = true; });
      await _verifyAndUnlock(rawValue);
    }
  }

  Future<void> _verifyAndUnlock(String scannedData) async {
    try {
      // Veriyi parçala: "ID | ZAMAN | İMZA"
      final parts = scannedData.split('|');
      if (parts.length != 3) throw Exception("Hatalı Okutma: Geçersiz QR Formatı");

      final scannedBoardId = parts[0];
      final scannedTime = parts[1];
      final scannedSignature = parts[2];

      // 1. SIKI GÜVENLİK: ID KONTROLÜ (Farklı Sınıf Engellemesi)
      if (scannedBoardId != widget.expectedBoardId) {
         throw Exception("Geçersiz İşlem: Hedef Kimlik Uyuşmazlığı\n(Seçilen: ${widget.boardName})");
      }

      // 2. Zaman Damgası Kontrolü (Bayat QR kod engellemesi)
      final now = DateTime.now().toUtc();
      final currentMinute = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      
      // Güvenlik: 1 dakikadan eski QR kodları reddet
      if (int.parse(currentMinute) - int.parse(scannedTime) > 1) {
         throw Exception("Geçersiz İşlem: Süresi Dolmuş QR Kod");
      }

      // 3. Kriptografik İmza Kontrolü (Sahte QR engellemesi)
      // Artık test secret yerine, o tahtaya ait gerçek şifreyi (widget.expectedOfflineSecret) kullanıyoruz
      final rawData = scannedBoardId + widget.expectedOfflineSecret + scannedTime;
      final bytes = utf8.encode(rawData);
      final digest = sha256.convert(bytes);
      final hashBytes = digest.bytes;
      
      // C# ile aynı byte çevirimi
      String expectedSignature = "";
      for (int i = 0; i < hashBytes.length; i++) {
        expectedSignature += hashBytes[i].toRadixString(16).padLeft(2, '0').toUpperCase();
      }
      expectedSignature = expectedSignature.substring(0, 16);

      if (scannedSignature != expectedSignature) throw Exception("Güvenlik İhlali: Geçersiz İmza");

      // --- HER ŞEY DOĞRUYSA KİLİDİ AÇ ---
      // NOT: Datasource metoduna tahtanın ID'sini de gönderdiğinden emin ol.
      // Eğer updateLockStatus(true, widget.expectedBoardId) gibi bir yapı kullanıyorsan onu güncelle.
      await _datasource.updateLockStatus(
  boardId: widget.expectedBoardId,
  isUnlocked: true,
);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erişim Onaylandı. Kilit Açılıyor...", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      Navigator.pop(context); // Tarayıcıyı kapat ve ana ekrana dön

    } catch (e) {
      if (!mounted) return;
      // Hatayı daha teknik ve temiz göstermek için .replaceAll kullanıyoruz
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        )
      );
      
      // 2 saniye sonra tekrar okumaya izin ver
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isProcessing = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.boardName} Kilidini Aç'), 
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            overlayBuilder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _isProcessing ? Colors.green : Colors.blueAccent, width: 4),
                  borderRadius: BorderRadius.circular(16)
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.15,
                  vertical: constraints.maxHeight * 0.25,
                ),
              );
            },
          ),
          if (_isProcessing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text("Kimlik Doğrulanıyor...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, backgroundColor: Colors.black45)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}