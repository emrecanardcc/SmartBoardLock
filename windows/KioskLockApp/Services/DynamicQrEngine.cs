using System;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    public static class DynamicQrEngine
    {
        // Registry'den verileri güvenli şekilde çeken metodumuz
        private static string GetRegistryValue(string keyName)
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\AkilliTahta"))
                {
                    // .Trim() ile boşluk hatalarını engelliyoruz
                    return key?.GetValue(keyName)?.ToString()?.Trim() ?? "";
                }
            }
            catch
            {
                return ""; // Hata durumunda boş döndür
            }
        }

        public static string GenerateQrPayload()
        {
            string boardId = GetRegistryValue("BoardId");
            string offlineSecret = GetRegistryValue("OfflineSecret");

            // Eğer Registry boşsa sistemin çökmemesi için koruma
            if (string.IsNullOrEmpty(boardId)) return "ERR_NO_CONFIG";

            // Değişkeni sadece BİR KERE tanımlıyoruz
            string timeString = DateTime.UtcNow.ToString("yyyyMMddHHmm");
            System.Diagnostics.Debug.WriteLine($"TAHTA_SAATI: {timeString}");

            string rawData = boardId + offlineSecret + timeString;

            using (SHA256 sha256 = SHA256.Create())
            {
                byte[] hashBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(rawData));
                string signature = BitConverter.ToString(hashBytes).Replace("-", "").Substring(0, 16);
                return $"{boardId}|{timeString}|{signature}";
            }
        }
    }
}