using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    public static class SecureSupabase
    {
        private const string SUPABASE_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        private const string SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

        // Registry'den veri okumak için tek merkez
        public static string GetRegistryValue(string keyName)
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

        public static async Task<bool?> CheckIfUnlockedAsync()
        {
            string boardId = GetRegistryValue("BoardId");
            if (string.IsNullOrEmpty(boardId)) return false;

            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=is_unlocked";
                    string response = await client.GetStringAsync(url);
                    string cleanResponse = response.Replace(" ", "").ToLower();

                    if (cleanResponse.Contains("\"is_unlocked\":true")) return true;
                    if (cleanResponse.Contains("\"is_unlocked\":false")) return false;
                }
            }
            catch { return null; }
            return false;
        }

        public static async Task<string> GenerateAndRegisterPairingCodeAsync()
        {
            Random rnd = new Random();
            using (HttpClient client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);
                client.DefaultRequestHeaders.Add("Prefer", "return=minimal");

                for (int i = 0; i < 5; i++)
                {
                    string code = rnd.Next(100000, 999999).ToString();
                    string url = $"{SUPABASE_URL}/rest/v1/board_pairings";
                    string jsonBody = $"{{\"pairing_code\": \"{code}\", \"status\": \"pending\"}}";

                    try
                    {
                        var response = await client.PostAsync(url, new StringContent(jsonBody, Encoding.UTF8, "application/json"));
                        if (response.IsSuccessStatusCode) return code;
                    }
                    catch { }
                }
            }
            return null;
        }

        // YENİ: Eşleşme tamamlandığında artık 'name' bilgisini de alıyoruz
        public static async Task<Dictionary<string, string>> CheckPairingStatusAsync(string code)
        {
            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    // Sorguya 'name' ekledik
                    string url = $"{SUPABASE_URL}/rest/v1/board_pairings?pairing_code=eq.{code}&select=board_id,offline_secret,status";
                    string response = await client.GetStringAsync(url);

                    if (response.Replace(" ", "").ToLower().Contains("\"status\":\"completed\""))
                    {
                        string boardId = ExtractJsonStringValue(response, "board_id");
                        string offlineSecret = ExtractJsonStringValue(response, "offline_secret");
                        

                        if (!string.IsNullOrEmpty(boardId) && !string.IsNullOrEmpty(offlineSecret))
                        {
                            return new Dictionary<string, string>
                            {
                                { "board_id", boardId },
                                { "offline_secret", offlineSecret },
                                
                            };
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        private static string ExtractJsonStringValue(string json, string key)
        {
            string searchKey = $"\"{key}\"";
            int startIndex = json.IndexOf(searchKey);
            if (startIndex == -1) return "";
            startIndex += searchKey.Length;
            int quoteStart = json.IndexOf("\"", startIndex);
            if (quoteStart == -1) return "";
            int quoteEnd = json.IndexOf("\"", quoteStart + 1);
            if (quoteEnd == -1) return "";
            return json.Substring(quoteStart + 1, quoteEnd - quoteStart - 1);
        }
        public static async Task<string> GetBoardNameAsync(string boardId)
        {
            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=name";
                    string response = await client.GetStringAsync(url);

                    return ExtractJsonStringValue(response, "name");
                }
            }
            catch
            {
                return "";
            }
        }
    }
}