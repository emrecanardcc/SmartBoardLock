using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Win32;
using System.Reflection;

namespace KioskLockApp.Services
{
    public static class SecureSupabase
    {
        private const string SUPABASE_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        private const string SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

        // Tekil HttpClient (Zaman aşımı / Timeout hatalarını bitirir)
        private static readonly HttpClient sharedClient = CreateSharedClient();

        private static HttpClient CreateSharedClient()
        {
            var client = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            client.DefaultRequestHeaders.Add("apikey", SUPABASE_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + SUPABASE_KEY);
            return client;
        }

        public static string GetRegistryValue(string keyName, string defaultValue = "")
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    return key?.GetValue(keyName)?.ToString()?.Trim() ?? defaultValue;
                }
            }
            catch { return defaultValue; }
        }

        public static void SetRegistryValue(string keyName, string value)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(@"Software\SmartBoardLock"))
                {
                    key.SetValue(keyName, value);
                }
            }
            catch { }
        }

        public static async Task<(string state, string boardName, bool isActive)> GetBoardStateSingleQueryAsync()
        {
            string boardId = GetRegistryValue("BoardId");
            string currentName = GetRegistryValue("BoardName");
            bool lastKnownActive = GetRegistryValue("LastKnownIsActive", "true") == "true";

            if (string.IsNullOrEmpty(boardId)) return ("DELETED", currentName, lastKnownActive);

            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=is_unlocked,is_active,name";
                string response = await sharedClient.GetStringAsync(url);
                string cleanResponse = response.Replace(" ", "").ToLower();

                if (cleanResponse == "[]") return ("DELETED", currentName, lastKnownActive);

                string fetchedName = ExtractJsonStringValue(response, "name");
                if (!string.IsNullOrEmpty(fetchedName) && fetchedName != currentName)
                {
                    SetRegistryValue("BoardName", fetchedName);
                    currentName = fetchedName;
                }

                bool isActive = cleanResponse.Contains("\"is_active\":true");
                SetRegistryValue("LastKnownIsActive", isActive ? "true" : "false");

                if (!isActive || cleanResponse.Contains("\"is_unlocked\":true"))
                    return ("UNLOCKED", currentName, isActive);

                return ("LOCKED", currentName, isActive);
            }
            catch
            {
                return ("ERROR", currentName, lastKnownActive);
            }
        }

        public static async Task SyncOfflineStatusAsync()
        {
            string pendingAction = GetRegistryValue("PendingOfflineSync");
            if (string.IsNullOrEmpty(pendingAction)) return;

            string boardId = GetRegistryValue("BoardId");
            if (string.IsNullOrEmpty(boardId)) return;

            try
            {
                bool targetUnlockState = (pendingAction == "UNLOCK");
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = $"{{\"is_unlocked\": {targetUnlockState.ToString().ToLower()}, \"last_locked_by\": \"Tahta (Çevrimdışı)\"}}";

                var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");

                var response = await sharedClient.SendAsync(request);
                if (response.IsSuccessStatusCode)
                {
                    SetRegistryValue("PendingOfflineSync", "");
                }
            }
            catch { }
        }

        public static async Task ForceUpdateLockStateAsync(bool unlock)
        {
            SetRegistryValue("PendingOfflineSync", unlock ? "UNLOCK" : "LOCK");
            await SyncOfflineStatusAsync();
        }

        public static async Task<(bool hasUpdate, string downloadUrl, string newVersion)> CheckForUpdatesAsync()
        {
            try
            {
                Version currentVersion = Assembly.GetExecutingAssembly().GetName().Version;
                string url = $"{SUPABASE_URL}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1";
                string response = await sharedClient.GetStringAsync(url);

                if (response != "[]" && response.Contains("version_number"))
                {
                    string dbVersionStr = ExtractJsonStringValue(response, "version_number");
                    string downloadUrl = ExtractJsonStringValue(response, "download_url");

                    if (!string.IsNullOrEmpty(dbVersionStr) && Version.TryParse(dbVersionStr, out Version latestVersion))
                    {
                        if (latestVersion > currentVersion) return (true, downloadUrl, dbVersionStr);
                    }
                }
            }
            catch { }
            return (false, string.Empty, string.Empty);
        }

        public static async Task<string> GenerateAndRegisterPairingCodeAsync()
        {
            Random rnd = new Random();
            for (int i = 0; i < 5; i++)
            {
                string code = rnd.Next(100000, 999999).ToString();
                string url = $"{SUPABASE_URL}/rest/v1/board_pairings";
                string jsonBody = $"{{\"pairing_code\": \"{code}\", \"status\": \"pending\"}}";

                try
                {
                    var request = new HttpRequestMessage(new HttpMethod("POST"), url) { Content = new StringContent(jsonBody, Encoding.UTF8, "application/json") };
                    request.Headers.Add("Prefer", "return=minimal");
                    var response = await sharedClient.SendAsync(request);
                    if (response.IsSuccessStatusCode) return code;
                }
                catch { }
            }
            return null;
        }

        public static async Task<Dictionary<string, string>> CheckPairingStatusAsync(string code)
        {
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/board_pairings?pairing_code=eq.{code}&select=board_id,offline_secret,status";
                string response = await sharedClient.GetStringAsync(url);

                if (response.Replace(" ", "").ToLower().Contains("\"status\":\"completed\""))
                {
                    string boardId = ExtractJsonStringValue(response, "board_id");
                    string offlineSecret = ExtractJsonStringValue(response, "offline_secret");

                    if (!string.IsNullOrEmpty(boardId) && !string.IsNullOrEmpty(offlineSecret))
                    {
                        return new Dictionary<string, string> { { "board_id", boardId }, { "offline_secret", offlineSecret } };
                    }
                }
            }
            catch { }
            return null;
        }

        public static async Task<string> GetBoardNameAsync(string boardId)
        {
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=name";
                string response = await sharedClient.GetStringAsync(url);
                return ExtractJsonStringValue(response, "name");
            }
            catch { return ""; }
        }

        public static async Task<string> GetSchoolNameAsync(string boardId)
        {
            try
            {
                string boardUrl = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=school_id";
                string boardResponse = await sharedClient.GetStringAsync(boardUrl);
                string schoolId = ExtractJsonStringValue(boardResponse, "school_id").Replace("\"", "").Trim();

                if (string.IsNullOrEmpty(schoolId)) return "Bilinmeyen Okul";

                string schoolUrl = $"{SUPABASE_URL}/rest/v1/schools?id=eq.{schoolId}&select=name";
                string schoolResponse = await sharedClient.GetStringAsync(schoolUrl);
                string schoolName = ExtractJsonStringValue(schoolResponse, "name").Replace("\"", "").Trim();

                return string.IsNullOrEmpty(schoolName) ? "Bilinmeyen Okul" : schoolName;
            }
            catch { return "Bilinmeyen Okul"; }
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
    }
}