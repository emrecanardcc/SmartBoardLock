using System;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    public static class OfflineTotpEngine
    {
        // Tahtanın kimlik bilgilerini Registry'den çeken metot
        private static string GetRegistryValue(string keyName)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    return key?.GetValue(keyName)?.ToString()?.Trim() ?? "";
                }
            }
            catch { return ""; }
        }

        // Ekranda öğretmene gösterilecek 4 haneli rastgele Meydan Okuma (Challenge) kodunu üretir (Kriptografik Güvenli)
        public static string GenerateChallengeCode()
        {
            return RandomNumberGenerator.GetInt32(1000, 10000).ToString();
        }

        // Kod ve tahtanın gizli anahtarını harmanlayarak 6 haneli Kilit Açma PIN'ini üretir (Registry tabanlı)
        public static string CalculateResponsePin(string challengeCode)
        {
            string offlineSecret = GetRegistryValue("OfflineSecret");
            return CalculateResponsePin(challengeCode, offlineSecret);
        }

        // Test edilebilir ve açık gizli anahtar alan hesaplama metodu (RFC 4226 Dinamik Kırpma)
        public static string CalculateResponsePin(string challengeCode, string offlineSecret)
        {
            if (string.IsNullOrWhiteSpace(challengeCode) || string.IsNullOrWhiteSpace(offlineSecret))
            {
                return string.Empty; // Güvenlik Kalkanı: Boş secret durumunda asla '000000' veya geçerli PIN üretme!
            }

            string rawData = challengeCode.Trim() + "-" + offlineSecret.Trim();

            using (HMACSHA256 hmac = new HMACSHA256(Encoding.UTF8.GetBytes(offlineSecret.Trim())))
            {
                byte[] hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(rawData));

                // RFC 4226 Uyumlu Güvenli Dinamik Kırpma (Dynamic Truncation)
                int offset = hashBytes[hashBytes.Length - 1] & 0x0F;
                int binary =
                    ((hashBytes[offset] & 0x7f) << 24) |
                    ((hashBytes[offset + 1] & 0xff) << 16) |
                    ((hashBytes[offset + 2] & 0xff) << 8) |
                    (hashBytes[offset + 3] & 0xff);

                int pin = binary % 1000000;
                return pin.ToString("D6");
            }
        }

        // Girilen PIN'in doğru olup olmadığını kontrol eder
        public static bool VerifyPin(string enteredPin, string currentChallengeCode)
        {
            string offlineSecret = GetRegistryValue("OfflineSecret");
            return VerifyPin(enteredPin, currentChallengeCode, offlineSecret);
        }

        // Test edilebilir parametreli PIN doğrulama metodu
        public static bool VerifyPin(string enteredPin, string currentChallengeCode, string offlineSecret)
        {
            if (string.IsNullOrWhiteSpace(enteredPin) || enteredPin.Length != 6)
                return false;

            if (string.IsNullOrWhiteSpace(offlineSecret))
                return false; // Boş anahtar ile doğrulama yapılamaz

            string expectedPin = CalculateResponsePin(currentChallengeCode, offlineSecret);
            if (string.IsNullOrEmpty(expectedPin))
                return false;

            return enteredPin == expectedPin;
        }
    }
}