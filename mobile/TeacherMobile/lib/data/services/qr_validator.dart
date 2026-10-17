import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? boardId;
  final DateTime? timestamp;

  const QrValidationResult({
    required this.isValid,
    this.errorMessage,
    this.boardId,
    this.timestamp,
  });

  factory QrValidationResult.success(String boardId, DateTime timestamp) =>
      QrValidationResult(isValid: true, boardId: boardId, timestamp: timestamp);

  factory QrValidationResult.failure(String message) =>
      QrValidationResult(isValid: false, errorMessage: message);
}

class QrValidator {
  /// YYYYMMDDHHmm formatındaki 12 haneli UTC zaman damgasını DateTime nesnesine çevirir.
  static DateTime? parseQrTimestamp(String ts) {
    if (ts.length != 12) return null;
    try {
      final year = int.parse(ts.substring(0, 4));
      final month = int.parse(ts.substring(4, 6));
      final day = int.parse(ts.substring(6, 8));
      final hour = int.parse(ts.substring(8, 10));
      final minute = int.parse(ts.substring(10, 12));
      return DateTime.utc(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// C# DynamicQrEngine ile birebir uyumlu SHA-256 ilk 16 karakter Hex imzasını üretir.
  static String calculateExpectedSignature({
    required String boardId,
    required String offlineSecret,
    required String scannedTime,
  }) {
    final rawData = boardId.trim() + offlineSecret.trim() + scannedTime.trim();
    final bytes = utf8.encode(rawData);
    final digest = sha256.convert(bytes);
    final hashBytes = digest.bytes;

    final sb = StringBuffer();
    for (int i = 0; i < hashBytes.length; i++) {
      sb.write(hashBytes[i].toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString().substring(0, 16);
  }

  /// QR verisini (boardId|scannedTime|signature) ayrıştırır, zaman aşımını ve imzayı doğrular.
  /// Saat ve gün geçişlerindeki matematiksel taşmaları (10:59 -> 11:00) DateTime farkı ile engeller.
  static QrValidationResult validatePayload({
    required String scannedData,
    required String expectedBoardId,
    required String expectedOfflineSecret,
    DateTime? mockNowUtc, // Testler için zaman enjeksiyonu
    int toleranceSeconds = 120,
  }) {
    final parts = scannedData.split('|');
    if (parts.length != 3) {
      return QrValidationResult.failure('Hatalı Okutma: Geçersiz QR Formatı');
    }

    final scannedBoardId = parts[0].trim();
    final scannedTime = parts[1].trim();
    final scannedSignature = parts[2].trim().toUpperCase();

    // 1. Hedef Tahta Kimlik Kontrolü
    if (scannedBoardId != expectedBoardId.trim()) {
      return QrValidationResult.failure(
        'Geçersiz İşlem: Hedef Kimlik Uyuşmazlığı',
      );
    }

    // 2. Zaman Damgası Ayrıştırma ve Güvenli Süre Kontrolü
    final parsedTime = parseQrTimestamp(scannedTime);
    if (parsedTime == null) {
      return QrValidationResult.failure('Geçersiz İşlem: Bozuk Zaman Damgası');
    }

    final now = mockNowUtc ?? DateTime.now().toUtc();
    final diffSeconds = now.difference(parsedTime).inSeconds.abs();
    if (diffSeconds > toleranceSeconds) {
      return QrValidationResult.failure('Geçersiz İşlem: Süresi Dolmuş QR Kod');
    }

    // 3. Kriptografik İmza Doğrulama
    final expectedSignature = calculateExpectedSignature(
      boardId: expectedBoardId,
      offlineSecret: expectedOfflineSecret,
      scannedTime: scannedTime,
    );

    if (scannedSignature != expectedSignature) {
      return QrValidationResult.failure('Güvenlik İhlali: Geçersiz İmza');
    }

    return QrValidationResult.success(scannedBoardId, parsedTime);
  }
}
