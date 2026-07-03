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

        public static string GenerateCodeForTime(DateTime time)
        {
            string boardId = GetRegistryValue("BoardId");
            string offlineSecret = GetRegistryValue("OfflineSecret");

            if (string.IsNullOrEmpty(boardId) || string.IsNullOrEmpty(offlineSecret))
                return "000000";

            string timeString = time.ToString("yyyyMMddHHmm");

            // Trim() eklenerek boşluk kaynaklı bozulmalar engellendi
            string rawData = boardId.Trim() + offlineSecret.Trim() + timeString;

            using (SHA256 sha256 = SHA256.Create())
            {
                byte[] hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(rawData));

                // SENİN ORİJİNAL, DOĞRU ALGORİTMANA GERİ DÖNÜLDÜ
                int num = ((hashBytes[0] << 24) | (hashBytes[1] << 16) | (hashBytes[2] << 8) | hashBytes[3]) & 0x7FFFFFFF;

                int pin = num % 1000000;
                return pin.ToString("D6");
            }
        }

        public static string GetCurrentPin()
        {
            return GenerateCodeForTime(DateTime.UtcNow);
        }

        public static bool VerifyPin(string enteredPin)
        {
            DateTime now = DateTime.UtcNow;

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