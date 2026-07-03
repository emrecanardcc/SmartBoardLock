using System;
using System.Security.Cryptography;
using System.Text;

namespace KioskLockApp.Services
{
    public static class DynamicQrEngine
    {
        public static string GenerateQrPayload()
        {
            // Ortak metottan verileri çekiyoruz
            string boardId = SecureSupabase.GetRegistryValue("BoardId");
            string offlineSecret = SecureSupabase.GetRegistryValue("OfflineSecret");

            // Eğer veriler yoksa boş döner (Ekran boş kalır)
            if (string.IsNullOrEmpty(boardId) || string.IsNullOrEmpty(offlineSecret))
                return "ERR_NO_CONFIG";

            // Boşlukları temizle
            boardId = boardId.Trim();
            offlineSecret = offlineSecret.Trim();

            string timeString = DateTime.UtcNow.ToString("yyyyMMddHHmm");
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