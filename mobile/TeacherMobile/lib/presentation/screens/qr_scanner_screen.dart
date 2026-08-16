import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/datasources/supabase_datasource.dart';

// --- YEPYENİ CANLI VE PROFESYONEL RENK PALETİ ---
const Color bgLight = Color(0xFFF1F5F9);      // Açık Arduvaz
const Color cardColor = Color(0xFFFFFFFF);    // Saf Beyaz 
const Color textDark = Color(0xFF0F172A);     // Çok Koyu Arduvaz 
const Color textGrey = Color(0xFF64748B);     // Orta Arduvaz 
const Color primaryBlue = Color(0xFF3B82F6);  // Canlı Mavi 
const Color successGreen = Color(0xFF10B981); // Zümrüt Yeşili 
const Color dangerRed = Color(0xFFF43F5E);    // Gül Kırmızısı 

class QrScannerScreen extends StatefulWidget {
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
    if (_isProcessing) return; // Arka arkaya okumayı engeller

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String rawValue = barcodes.first.rawValue!;
      
      setState(() { _isProcessing = true; });
      await _verifyAndUnlock(rawValue);
    }
  }

  // --- YENİ: Modern Snackbar ---
  void _showModernSnackbar(String message, {required bool isSuccess, required Color bgColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: bgColor, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      )
    );
  }

  Future<void> _verifyAndUnlock(String scannedData) async {
    try {
      // Veriyi parçala: "ID | ZAMAN | İMZA"
      final parts = scannedData.split('|');
      if (parts.length != 3) throw Exception("Hatalı Okutma: Geçersiz QR Formatı");

      final scannedBoardId = parts[0];
      final scannedTime = parts[1];
      final scannedSignature = parts[2];

      // 1. SIKI GÜVENLİK: ID KONTROLÜ
      if (scannedBoardId != widget.expectedBoardId) {
         throw Exception("Geçersiz İşlem: Hedef Kimlik Uyuşmazlığı\n(Seçilen: ${widget.boardName})");
      }

      // 2. Zaman Damgası Kontrolü
      final now = DateTime.now().toUtc();
      final currentMinute = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      
      if (int.parse(currentMinute) - int.parse(scannedTime) > 1) {
         throw Exception("Geçersiz İşlem: Süresi Dolmuş QR Kod");
      }

      // 3. Kriptografik İmza Kontrolü
      final rawData = scannedBoardId + widget.expectedOfflineSecret + scannedTime;
      final bytes = utf8.encode(rawData);
      final digest = sha256.convert(bytes);
      final hashBytes = digest.bytes;
      
      String expectedSignature = "";
      for (int i = 0; i < hashBytes.length; i++) {
        expectedSignature += hashBytes[i].toRadixString(16).padLeft(2, '0').toUpperCase();
      }
      expectedSignature = expectedSignature.substring(0, 16);

      if (scannedSignature != expectedSignature) throw Exception("Güvenlik İhlali: Geçersiz İmza");

      // --- HER ŞEY DOĞRUYSA KİLİDİ AÇ ---
      await _datasource.updateLockStatus(
        boardId: widget.expectedBoardId,
        isUnlocked: true,
      );
      
      if (!mounted) return;
      _showModernSnackbar("Erişim Onaylandı. Kilit Açılıyor...", isSuccess: true, bgColor: successGreen);
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      _showModernSnackbar(e.toString().replaceAll('Exception: ', ''), isSuccess: false, bgColor: dangerRed);
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _isProcessing = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Kamera arkaplanı karanlık kalmalı
      extendBodyBehindAppBar: true,  // Kameranın AppBar altına kadar uzanmasını sağlar
      appBar: AppBar(
        title: Text('${widget.boardName} Kilidini Aç', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)), 
        backgroundColor: Colors.black54, // Yarı saydam karanlık appbar
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            overlayBuilder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  // Doğrulanıyorsa yeşil, bekliyorsa canlı mavi çerçeve
                  border: Border.all(color: _isProcessing ? successGreen : primaryBlue, width: 4),
                  borderRadius: BorderRadius.circular(24) // Daha yumuşak hatlı çerçeve
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.15,
                  vertical: constraints.maxHeight * 0.25,
                ),
              );
            },
          ),
          
          // --- MODERN DOĞRULANIYOR KARTI ---
          if (_isProcessing)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10)),
                  ]
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
                    SizedBox(height: 24),
                    Text(
                      "Doğrulanıyor...", 
                      style: TextStyle(color: textDark, fontSize: 20, fontWeight: FontWeight.w900)
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Kriptografik imza çözülüyor", 
                      style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}