using System;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    public static class OfflineTotpEngine
    {
        // Tahtanın kimlik bilgilerini Registry'den güvenle çeken metot
        private static string GetRegistryValue(string keyName)
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\AkilliTahta"))
                {
                    return key?.GetValue(keyName)?.ToString()?.Trim() ?? "";
                }
            }
            catch { return ""; }
        }

        // Belirli bir zaman için 6 haneli acil durum şifresini (PIN) üreten çekirdek metot
        public static string GenerateCodeForTime(DateTime time)
        {
            string boardId = GetRegistryValue("BoardId");
            string offlineSecret = GetRegistryValue("OfflineSecret");

            // Eğer veriler boşsa güvenlik için sıfır döndür (kilitli kalsın)
            if (string.IsNullOrEmpty(boardId) || string.IsNullOrEmpty(offlineSecret))
                return "000000";

            // Zamanı YYYYMMDDHHMM formatına çevir (Örn: 202607022125)
            string timeString = time.ToString("yyyyMMddHHmm");

            // Veri Formülü: ID + SECRET + ZAMAN
            string rawData = boardId + offlineSecret + timeString;

            using (SHA256 sha256 = SHA256.Create())
            {
                byte[] hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(rawData));

                // İlk 4 byte'ı alıp pozitif bir tam sayıya (integer) çevir
                int num = ((hashBytes[0] << 24) | (hashBytes[1] << 16) | (hashBytes[2] << 8) | hashBytes[3]) & 0x7FFFFFFF;

                // Modulo 1000000 ile 6 haneli bir PIN elde et
                int pin = num % 1000000;
                return pin.ToString("D6"); // "123" ise "000123" yapar
            }
        }

        // Ekrana kopya (cheat) şifresini yazdırmak için
        public static string GetCurrentPin()
        {
            return GenerateCodeForTime(DateTime.UtcNow);
        }

        // Tuş takımından girilen şifreyi doğrulayan ve TOLERANS sağlayan metot
        public static bool VerifyPin(string enteredPin)
        {
            DateTime now = DateTime.UtcNow;

            // Öğretmen tam dakika değişirken şifre girebilir, bu yüzden
            // ŞİMDİKİ, 1 DAKİKA ÖNCEKİ ve 1 DAKİKA SONRAKİ şifreleri kabul ediyoruz.
            string currentPin = GenerateCodeForTime(now);
            string previousPin = GenerateCodeForTime(now.AddMinutes(-1));
            string nextPin = GenerateCodeForTime(now.AddMinutes(1));

            if (enteredPin == currentPin || enteredPin == previousPin || enteredPin == nextPin)
            {
                return true;
            }

            return false;
        }
    }
}