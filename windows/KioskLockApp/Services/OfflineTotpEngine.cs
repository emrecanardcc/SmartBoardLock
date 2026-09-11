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

        // Ekranda öğretmene gösterilecek 4 haneli rastgele Meydan Okuma (Challenge) kodunu üretir
        public static string GenerateChallengeCode()
        {
            Random rnd = new Random();
            return rnd.Next(1000, 9999).ToString();
        }

        // Kod ve tahtanın gizli anahtarını harmanlayarak 6 haneli Kilit Açma PIN'ini üretir
        private static string CalculateResponsePin(string challengeCode)
        {
            string boardId = GetRegistryValue("BoardId");
            string offlineSecret = GetRegistryValue("OfflineSecret");

            if (string.IsNullOrEmpty(boardId) || string.IsNullOrEmpty(offlineSecret) || string.IsNullOrEmpty(challengeCode))
                return "000000";

            string rawData = challengeCode.Trim() + "-" + offlineSecret.Trim();

            using (HMACSHA256 hmac = new HMACSHA256(Encoding.UTF8.GetBytes(offlineSecret)))
            {
                byte[] hashBytes = hmac.ComputeHash(Encoding.UTF8.GetBytes(rawData));

                // Güvenli hash dönüşümü
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
            if (string.IsNullOrEmpty(enteredPin) || enteredPin.Length != 6)
                return false;

            string expectedPin = CalculateResponsePin(currentChallengeCode);
            return enteredPin == expectedPin;
        }
    }
}