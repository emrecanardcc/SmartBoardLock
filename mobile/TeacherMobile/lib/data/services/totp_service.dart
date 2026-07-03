import 'dart:convert';
import 'package:crypto/crypto.dart';

class TotpService {
  static String generateCode({
    required String boardId,
    required String offlineSecret,
    required DateTime time,
  }) {
    // ÖNEMLİ: C# ve Flutter'ın aynı şifreyi üretmesi için UTC saat dilimini baz almalıyız!
    final utcTime = time.toUtc();
    final timeString = "${utcTime.year}${utcTime.month.toString().padLeft(2, '0')}${utcTime.day.toString().padLeft(2, '0')}${utcTime.hour.toString().padLeft(2, '0')}${utcTime.minute.toString().padLeft(2, '0')}";
    
    final rawData = boardId.trim() + offlineSecret.trim() + timeString;
    
    final bytes = utf8.encode(rawData);
    final digest = sha256.convert(bytes);
    final hashBytes = digest.bytes;

    // Little-Endian okuma (C# uyumlu)
    int num = ((hashBytes[0] << 24) | 
             (hashBytes[1] << 16) | 
             (hashBytes[2] << 8) | 
             hashBytes[3]) & 0x7FFFFFFF;
               
    int pin = num % 1000000;
    
    return pin.toString().padLeft(6, '0');
  }
}