using System;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.Win32; // Registry için gerekli

namespace KioskLockApp.Services
{
    public static class SecureSupabase
    {
        private const string SUPABASE_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        private const string SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

        private static string GetBoardIdFromRegistry()
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\AkilliTahta"))
                {
                    return key?.GetValue("BoardId")?.ToString() ?? "";
                }
            }
            catch { return ""; }
        }

        public static async Task<bool?> CheckIfUnlockedAsync()
        {
            string boardId = GetBoardIdFromRegistry();
            if (string.IsNullOrEmpty(boardId)) return false;

            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    // DÜZELTME: board_id yerine id yazdık!
                    string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=is_unlocked";

                    string response = await client.GetStringAsync(url);
                    string cleanResponse = response.Replace(" ", "").ToLower();

                    if (cleanResponse.Contains("\"is_unlocked\":true")) return true;
                    if (cleanResponse.Contains("\"is_unlocked\":false")) return false;
                }
            }
            catch
            {
                return null; // Sunucuya ulaşılamadı (Offline Modu Tetikler)
            }
            return false;
        }
    }
}