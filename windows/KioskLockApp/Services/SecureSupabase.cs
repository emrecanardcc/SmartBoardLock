using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Win32;
using System.Reflection; // YENİ: Uygulama versiyonunu okumak için eklendi

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

        // ==========================================
        // YENİ: OTOMATİK GÜNCELLEME KONTROL SİSTEMİ
        // ==========================================
        public static async Task<(bool hasUpdate, string downloadUrl, string newVersion)> CheckForUpdatesAsync()
        {
            try
            {
                // 1. Kendi gömülü versiyonumuzu okuyoruz (Örn: "1.0.0.0")
                Version currentVersion = Assembly.GetExecutingAssembly().GetName().Version;

                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    // 2. app_versions tablosundan oluşturulma tarihine göre en son eklenen 1 kaydı çekiyoruz
                    string url = $"{SUPABASE_URL}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1";
                    string response = await client.GetStringAsync(url);

                    // Eğer veritabanı boş değilse
                    if (response != "[]" && response.Contains("version_number"))
                    {
                        // Senin yazdığın harika ayrıştırıcı ile verileri çekiyoruz
                        string dbVersionStr = ExtractJsonStringValue(response, "version_number");
                        string downloadUrl = ExtractJsonStringValue(response, "download_url");

                        if (!string.IsNullOrEmpty(dbVersionStr) && Version.TryParse(dbVersionStr, out Version latestVersion))
                        {
                            // 3. Karşılaştırma yapıyoruz: Veritabanındaki sürüm BÜYÜKSE güncelleme vardır
                            if (latestVersion > currentVersion)
                            {
                                return (true, downloadUrl, dbVersionStr);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // İnternet yoksa sessizce devam et, tahtayı kilitli tut
                System.Diagnostics.Debug.WriteLine("Güncelleme kontrol hatası: " + ex.Message);
            }

            // Güncelleme yoksa veya hata olduysa false dön
            return (false, string.Empty, string.Empty);
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

        public static async Task<Dictionary<string, string>> CheckPairingStatusAsync(string code)
        {
            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

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
                                { "offline_secret", offlineSecret }
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

        public static async Task<string> GetSchoolNameAsync(string boardId)
        {
            try
            {
                using (HttpClient client = new HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(5);
                    client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);

                    string boardUrl = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=school_id";
                    string boardResponse = await client.GetStringAsync(boardUrl);

                    string schoolId = ExtractJsonStringValue(boardResponse, "school_id");
                    schoolId = schoolId.Replace("\"", "").Trim();

                    if (string.IsNullOrEmpty(schoolId))
                    {
                        return "Bilinmeyen Okul";
                    }

                    string schoolUrl = $"{SUPABASE_URL}/rest/v1/schools?id=eq.{schoolId}&select=name";
                    string schoolResponse = await client.GetStringAsync(schoolUrl);

                    string schoolName = ExtractJsonStringValue(schoolResponse, "name");
                    schoolName = schoolName.Replace("\"", "").Trim();

                    return string.IsNullOrEmpty(schoolName) ? "Bilinmeyen Okul" : schoolName;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("Supabase Hatası (GetSchoolNameAsync): " + ex.Message);
                return "Bilinmeyen Okul";
            }
        }
    }
}