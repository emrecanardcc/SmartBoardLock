import 'dart:convert';
import 'package:crypto/crypto.dart';

class TotpService {
  /// Kiosk ekranındaki 4 haneli meydan okuma (challenge) kodunu alıp 
  /// 6 haneli kilit açma PIN'ini üretir (RFC 4226 Dinamik Kırpma uyumlu).
  static String generateResponse({
    required String offlineSecret,
    required String challengeCode,
  }) {
    if (offlineSecret.trim().isEmpty || challengeCode.trim().isEmpty) {
      return '';
    }

    // 1. C# OfflineTotpEngine ile birebir aynı girdi: challengeCode + "-" + offlineSecret
    final secretKey = offlineSecret.trim();
    final rawData = '${challengeCode.trim()}-$secretKey';

    // 2. HMAC-SHA256 Algoritması (Key = secretKey, Message = rawData)
    final keyBytes = utf8.encode(secretKey);
    final messageBytes = utf8.encode(rawData);

    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    final hashBytes = digest.bytes;

    // 3. RFC 4226 Dinamik Kırpma (Dynamic Truncation - Son 4 bitten offset alma)
    final offset = hashBytes[hashBytes.length - 1] & 0x0F;
    final binary = ((hashBytes[offset] & 0x7F) << 24) |
        ((hashBytes[offset + 1] & 0xFF) << 16) |
        ((hashBytes[offset + 2] & 0xFF) << 8) |
        (hashBytes[offset + 3] & 0xFF);

    // 4. 6 Haneli PIN Formatı
    final pin = binary % 1000000;

    return pin.toString().padLeft(6, '0');
  }
}