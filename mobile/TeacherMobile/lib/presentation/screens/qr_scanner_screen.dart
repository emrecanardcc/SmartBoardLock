import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/datasources/supabase_datasource.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final SupabaseDatasource _datasource = SupabaseDatasource();
  bool _isProcessing = false;

  // C# tarafındaki test verileriyle tamamen aynı olmalı
  final String _testBoardId = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
  final String _testOfflineSecret = "TAHTA_OZEL_GIZLI_TUZ_12345";

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
      if (parts.length != 3) throw Exception("Geçersiz QR formatı");

      final scannedBoardId = parts[0];
      final scannedTime = parts[1];
      final scannedSignature = parts[2];

      // 1. ID Kontrolü
      if (scannedBoardId != _testBoardId) throw Exception("Bu tahta size ait değil!");

      // 2. Zaman Damgası Kontrolü (Bayat QR kod engellemesi)
      final now = DateTime.now().toUtc();
      final currentMinute = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      
      // Güvenlik: 1 dakikadan eski QR kodları reddet
      if (int.parse(currentMinute) - int.parse(scannedTime) > 1) {
         throw Exception("Süresi dolmuş QR Kod. Lütfen yenilenmesini bekleyin.");
      }

      // 3. Kriptografik İmza Kontrolü (Sahte QR engellemesi)
      final rawData = scannedBoardId + _testOfflineSecret + scannedTime;
      final bytes = utf8.encode(rawData);
      final digest = sha256.convert(bytes);
      final hashBytes = digest.bytes;
      
      // C# ile aynı byte çevirimi
      String expectedSignature = "";
      for (int i = 0; i < hashBytes.length; i++) {
        expectedSignature += hashBytes[i].toRadixString(16).padLeft(2, '0').toUpperCase();
      }
      expectedSignature = expectedSignature.substring(0, 16);

      if (scannedSignature != expectedSignature) throw Exception("QR Kod imzası geçersiz!");

      // --- HER ŞEY DOĞRUYSA KİLİDİ AÇ ---
      await _datasource.updateLockStatus(true);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tahta başarıyla açıldı! ✅", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      Navigator.pop(context); // Tarayıcıyı kapat ve ana ekrana dön

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.toString().replaceAll('Exception: ', '')}", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      
      // 2 saniye sonra tekrar okumaya izin ver
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isProcessing = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tahtayı Aç'), backgroundColor: Colors.black),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            overlayBuilder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _isProcessing ? Colors.green : Colors.orange, width: 4),
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
                  Text("Doğrulanıyor...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, backgroundColor: Colors.black45)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}