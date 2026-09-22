import 'dart:convert';
import 'package:crypto/crypto.dart';

class TotpService {
  /// Kiosk ekranındaki 4 haneli meydan okuma (challenge) kodunu alıp 
  /// 6 haneli kilit açma PIN'ini üretir.
  static String generateResponse({
    required String offlineSecret,
    required String challengeCode,
  }) {
    // 1. C# ile birebir aynı olması için boşlukları temizliyoruz
    final secretKey = offlineSecret.trim();
    final message = challengeCode.trim();

    // 2. HMAC-SHA256 Algoritması (Secret = Key, Challenge = Message)
    final keyBytes = utf8.encode(secretKey);
    final messageBytes = utf8.encode(message);

    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(messageBytes);
    final hashBytes = digest.bytes;

    // 3. Little-Endian Okuma (C# uyumluluğu için ilk 4 baytı alıyoruz)
    int num = ((hashBytes[0] << 24) | 
               (hashBytes[1] << 16) | 
               (hashBytes[2] << 8) | 
               hashBytes[3]) & 0x7FFFFFFF;
               
    // 4. 6 Haneli PIN Formatı
    int pin = num % 1000000;
    
    return pin.toString().padLeft(6, '0');
  }
}