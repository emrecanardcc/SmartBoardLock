using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Win32;
using System.Reflection;
using System.Diagnostics;

namespace KioskLockApp.Services
{
    public static class SecureSupabase
    {
        // Birincil: Oracle Cloud Always Free Self-Hosted Supabase
        public const string SUPABASE_URL = "http://130.61.78.192:8000";
        private const string _b64Key = "ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA==";
        public static readonly string SUPABASE_KEY = Encoding.UTF8.GetString(Convert.FromBase64String(_b64Key));

        // İkincil / Yedek: Canlı Geçiş Güvenlik Ağı (Cloud Supabase)
        public const string FALLBACK_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        private const string _b64FallbackKey = "ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW1Oc2EyRnpibUp3Yldoa1pHaHpkRzlwZUdSNklpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RJNU9EYzRPRFFzSW1WNGNDSTZNakE1T0RVMk16ZzROSDAuS3B3T1pvV3dPdTJEZndPZWMweTVMU3ZTNk1SR0d5NFVxb3QtUTFHMF94OA==";
        public static readonly string FALLBACK_KEY = Encoding.UTF8.GetString(Convert.FromBase64String(_b64FallbackKey));

        // Tekil HttpClient (Zaman aşımı / Timeout hatalarını bitirir)
        private static readonly HttpClient sharedClient = CreateClient(SUPABASE_KEY);
        private static readonly HttpClient fallbackClient = CreateClient(FALLBACK_KEY);

        private static HttpClient CreateClient(string apiKey)
        {
            var client = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
            client.DefaultRequestHeaders.Add("apikey", apiKey);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + apiKey);
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

        public static string GetCurrentAppVersion()
        {
            try
            {
                var ver = Assembly.GetExecutingAssembly().GetName().Version;
                return ver != null ? $"{ver.Major}.{ver.Minor}.{ver.Build}" : "2.0.8";
            }
            catch
            {
                return "2.0.8";
            }
        }

        private static DateTime lastHeartbeatTime = DateTime.MinValue;

        /// <summary>
        /// Sadece tahta ilk açıldığında veya sürüm güncellendiğinde 1 KEZ çağrılır.
        /// Hem yüklü sürümü hem de başlangıç pingini kaydeder. Veritabanını şişirmez.
        /// </summary>
        public static async Task ReportStartupAndVersionAsync()
        {
            string boardId = GetRegistryValue("BoardId");
            if (string.IsNullOrEmpty(boardId)) return;

            try
            {
                string version = GetCurrentAppVersion();
                string nowUtc = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = $"{{\"app_version\": \"{version}\", \"last_ping_at\": \"{nowUtc}\"}}";

                var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");

                await sharedClient.SendAsync(request);
                lastHeartbeatTime = DateTime.UtcNow;
            }
            catch { }
        }

        /// <summary>
        /// Periyodik hafif heartbeat. SADECE last_ping_at günceller (app_version içermez).
        /// En az 100 saniye geçmeden tekrar istek atmaz (DB kotasını korur).
        /// </summary>
        public static async Task SendHeartbeatAsync(bool force = false)
        {
            string boardId = GetRegistryValue("BoardId");
            if (string.IsNullOrEmpty(boardId)) return;

            // Throttle: force değilse ve son 100 saniyede atılmışsa pas geç (DB şişmesini önler)
            if (!force && (DateTime.UtcNow - lastHeartbeatTime).TotalSeconds < 100)
            {
                return;
            }

            try
            {
                string nowUtc = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = $"{{\"last_ping_at\": \"{nowUtc}\"}}";

                var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");

                await sharedClient.SendAsync(request);
                lastHeartbeatTime = DateTime.UtcNow;
            }
            catch { }
        }

        public static async Task ClearRemoteCommandAsync(string boardId)
        {
            // 1. Birincil (Oracle VM)
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = "{\"remote_command\": null}";
                var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");
                await sharedClient.SendAsync(request);
            }
            catch { }

            // 2. İkincil (Cloud Supabase)
            try
            {
                string fallbackUrl = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = "{\"remote_command\": null}";
                var request = new HttpRequestMessage(new HttpMethod("PATCH"), fallbackUrl)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");
                await fallbackClient.SendAsync(request);
            }
            catch { }
        }

        public static async Task ReportActiveMediaIdAsync(string mediaId)
        {
            string boardId = GetRegistryValue("BoardId");
            if (string.IsNullOrEmpty(boardId)) return;

            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                string jsonBody = $"{{\"active_media_id\": \"{mediaId}\"}}";

                var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                request.Headers.Add("Prefer", "return=minimal");

                await sharedClient.SendAsync(request);
            }
            catch { }
        }

        public static void ExecuteShutdown()
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("shutdown.exe", "/s /t 5 /f")
                {
                    CreateNoWindow = true,
                    UseShellExecute = false
                };
                Process.Start(psi);
            }
            catch { }
        }

        public static async Task<(string state, string boardName, bool isActive, string remoteCommand)> GetBoardStateSingleQueryAsync()
        {
            string boardId = GetRegistryValue("BoardId");
            string currentName = GetRegistryValue("BoardName");
            bool lastKnownActive = GetRegistryValue("LastKnownIsActive", "true") == "true";

            if (string.IsNullOrEmpty(boardId)) return ("DELETED", currentName, lastKnownActive, "");

            string primaryResponse = "";
            string fallbackResponse = "";

            // 1. Birincil Sunucu (Oracle Cloud Supabase)
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=is_unlocked,is_active,name,remote_command";
                primaryResponse = await sharedClient.GetStringAsync(url);
            }
            catch { }

            // 2. İkincil Sunucu (Cloud Supabase - Canlı Güvenlik Ağı)
            try
            {
                string fallbackUrl = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}&select=is_unlocked,is_active,name,remote_command";
                fallbackResponse = await fallbackClient.GetStringAsync(fallbackUrl);
            }
            catch { }

            string cleanPrimary = (primaryResponse ?? "").Replace(" ", "").ToLower();
            string cleanFallback = (fallbackResponse ?? "").Replace(" ", "").ToLower();

            // İki sunucuda da kayıt yoksa silinmiştir
            if (cleanPrimary == "[]" && cleanFallback == "[]")
            {
                return ("DELETED", currentName, lastKnownActive, "");
            }

            // Birincil sunucuda eksikse Fallback'ten Oracle VM'e otomatik taşı
            if (cleanPrimary == "[]" && cleanFallback != "[]" && !string.IsNullOrEmpty(fallbackResponse))
            {
                _ = SyncBoardFromCloudToOracleAsync(boardId);
            }

            // İsim Eşitleme: Hangisinde güncel/farklı isim varsa al ve iki tarafa da yaz
            string primaryName = ExtractJsonStringValue(primaryResponse ?? "", "name");
            string fallbackName = ExtractJsonStringValue(fallbackResponse ?? "", "name");

            string latestName = currentName;
            if (!string.IsNullOrEmpty(fallbackName) && fallbackName != currentName)
            {
                latestName = fallbackName;
            }
            else if (!string.IsNullOrEmpty(primaryName) && primaryName != currentName)
            {
                latestName = primaryName;
            }

            if (!string.IsNullOrEmpty(latestName) && latestName != currentName)
            {
                SetRegistryValue("BoardName", latestName);
                currentName = latestName;
                _ = SyncBoardNameAsync(boardId, latestName);
            }

            // Remote Command: Herhangi bir sunucuda bekleyen komut var mı?
            string remoteCommand = ExtractJsonStringValue(primaryResponse, "remote_command");
            if (string.IsNullOrEmpty(remoteCommand))
            {
                remoteCommand = ExtractJsonStringValue(fallbackResponse, "remote_command");
            }

            // Aktiflik kontrolü
            bool isActivePrimary = cleanPrimary.Contains("\"is_active\":true") || (!cleanPrimary.Contains("\"is_active\":false") && lastKnownActive);
            bool isActiveFallback = cleanFallback.Contains("\"is_active\":true") || (!cleanFallback.Contains("\"is_active\":false") && lastKnownActive);
            bool isActive = isActivePrimary && isActiveFallback;
            SetRegistryValue("LastKnownIsActive", isActive ? "true" : "false");

            // Kilit durumu: İki sunucudan herhangi birinde kilit açılmışsa (öğretmen QR okuttuysa veya mobilden açtıysa):
            // "Unlock-Wins" (Kilit Açma Önceliği): Öğretmenin derste mahsur kalmaması ve yarış durumlarının önlenmesi esastır.
            // Her iki sunucu kontrol edilir, herhangi biri açıksa kilit açılır.
            bool primaryUnlocked = cleanPrimary.Contains("\"is_unlocked\":true");
            bool fallbackUnlocked = cleanFallback.Contains("\"is_unlocked\":true");

            bool primaryHasData = !string.IsNullOrEmpty(primaryResponse) && cleanPrimary != "[]";
            bool fallbackHasData = !string.IsNullOrEmpty(fallbackResponse) && cleanFallback != "[]";
            bool isUnlocked;

            if (primaryUnlocked || fallbackUnlocked)
            {
                isUnlocked = true;
                // Henüz açılmamış olan sunucuyu da açarak iki sunucuyu milisaniyeler içinde senkronize et
                if (primaryHasData && !primaryUnlocked)
                {
                    _ = SyncUnlockStatusToServerAsync(SUPABASE_URL, sharedClient, boardId, true);
                }
                if (fallbackHasData && !fallbackUnlocked)
                {
                    _ = SyncUnlockStatusToServerAsync(FALLBACK_URL, fallbackClient, boardId, true);
                }
            }
            else
            {
                // İki sunucuda da kilit kapalıysa (veya veri yoksa) kilitli kal
                isUnlocked = false;
            }

            if (!isActive || isUnlocked)
            {
                return ("UNLOCKED", currentName, isActive, remoteCommand);
            }

            return ("LOCKED", currentName, isActive, remoteCommand);
        }

        public static async Task SyncUnlockStatusToServerAsync(string baseUrl, HttpClient client, string boardId, bool isUnlocked)
        {
            string jsonBody = $"{{\"is_unlocked\": {isUnlocked.ToString().ToLower()}}}";
            try
            {
                string url = $"{baseUrl}/rest/v1/boards?id=eq.{boardId}";
                var req = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                req.Headers.Add("Prefer", "return=minimal");
                await client.SendAsync(req);
            }
            catch { }
        }

        public static async Task SyncUnlockStatusAcrossServersAsync(string boardId, bool isUnlocked)
        {
            await Task.WhenAll(
                SyncUnlockStatusToServerAsync(SUPABASE_URL, sharedClient, boardId, isUnlocked),
                SyncUnlockStatusToServerAsync(FALLBACK_URL, fallbackClient, boardId, isUnlocked)
            );
        }

        public static async Task SyncBoardNameAsync(string boardId, string newName)
        {
            if (string.IsNullOrEmpty(newName)) return;
            string jsonBody = $"{{\"name\": \"{newName}\"}}";
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                var req = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                req.Headers.Add("Prefer", "return=minimal");
                await sharedClient.SendAsync(req);
            }
            catch { }

            try
            {
                string fallbackUrl = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}";
                var req = new HttpRequestMessage(new HttpMethod("PATCH"), fallbackUrl)
                {
                    Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                };
                req.Headers.Add("Prefer", "return=minimal");
                await fallbackClient.SendAsync(req);
            }
            catch { }
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
                string jsonBody = $"{{\"is_unlocked\": {targetUnlockState.ToString().ToLower()}, \"last_locked_by\": \"Tahta (Çevrimdışı)\"}}";

                // 1. Birincil (Oracle VM)
                try
                {
                    string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}";
                    var request = new HttpRequestMessage(new HttpMethod("PATCH"), url)
                    {
                        Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                    };
                    request.Headers.Add("Prefer", "return=minimal");
                    await sharedClient.SendAsync(request);
                }
                catch { }

                // 2. İkincil (Cloud Supabase)
                try
                {
                    string fallbackUrl = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}";
                    var request = new HttpRequestMessage(new HttpMethod("PATCH"), fallbackUrl)
                    {
                        Content = new StringContent(jsonBody, Encoding.UTF8, "application/json")
                    };
                    request.Headers.Add("Prefer", "return=minimal");
                    await fallbackClient.SendAsync(request);
                }
                catch { }

                SetRegistryValue("PendingOfflineSync", "");
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
            // 1. Önce Birincil (Self-Hosted) Sunucuyu Kontrol Et
            var primaryResult = await CheckUpdatesFromClientAsync(sharedClient, SUPABASE_URL);
            if (primaryResult.hasUpdate) return primaryResult;

            // 2. Eğer birincil sunucudan güncelleme gelmediyse (veya erişilemediyse), İkincil (Cloud) Sunucuyu Kontrol Et
            try
            {
                var fallbackResult = await CheckUpdatesFromClientAsync(fallbackClient, FALLBACK_URL);
                if (fallbackResult.hasUpdate) return fallbackResult;
            }
            catch { }

            return (false, string.Empty, string.Empty);
        }

        private static async Task<(bool hasUpdate, string downloadUrl, string newVersion)> CheckUpdatesFromClientAsync(HttpClient client, string baseUrl)
        {
            try
            {
                Version currentVersion = Assembly.GetExecutingAssembly().GetName().Version;
                string url = $"{baseUrl}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1";
                string response = await client.GetStringAsync(url);

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
                    if (response.IsSuccessStatusCode)
                    {
                        // FALLBACK: Cloud Supabase'e de çift yönlü kayıt açıyoruz
                        // Böylece öğretmenin telefonundaki mobil uygulama henüz App Store güncellemesi almamış olsa bile (eski buluta bağlıyken) tahtayı anında eşleştirebilir!
                        try
                        {
                            string fallbackUrl = $"{FALLBACK_URL}/rest/v1/board_pairings";
                            var fallbackRequest = new HttpRequestMessage(new HttpMethod("POST"), fallbackUrl) { Content = new StringContent(jsonBody, Encoding.UTF8, "application/json") };
                            fallbackRequest.Headers.Add("Prefer", "return=minimal");
                            await fallbackClient.SendAsync(fallbackRequest);
                        }
                        catch { }

                        return code;
                    }
                }
                catch { }
            }
            return null;
        }

        public static async Task<Dictionary<string, string>> CheckPairingStatusAsync(string code)
        {
            // 1. Önce Birincil (Oracle Cloud Always Free Supabase) Kontrolü
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

            // 2. İkincil / Fallback (Cloud Supabase) Kontrolü
            // Eğer eşleştirme eski mobil uygulama üzerinden Cloud Supabase'e yapıldıysa:
            try
            {
                string fallbackUrl = $"{FALLBACK_URL}/rest/v1/board_pairings?pairing_code=eq.{code}&select=board_id,offline_secret,status";
                string fallbackResponse = await fallbackClient.GetStringAsync(fallbackUrl);

                if (fallbackResponse.Replace(" ", "").ToLower().Contains("\"status\":\"completed\""))
                {
                    string boardId = ExtractJsonStringValue(fallbackResponse, "board_id");
                    string offlineSecret = ExtractJsonStringValue(fallbackResponse, "offline_secret");

                    if (!string.IsNullOrEmpty(boardId) && !string.IsNullOrEmpty(offlineSecret))
                    {
                        // Tahta kaydını Oracle VM'e de senkronize et
                        _ = SyncBoardFromCloudToOracleAsync(boardId);

                        return new Dictionary<string, string> { { "board_id", boardId }, { "offline_secret", offlineSecret } };
                    }
                }
            }
            catch { }

            return null;
        }

        public static async Task SyncBoardFromCloudToOracleAsync(string boardId)
        {
            try
            {
                string url = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}";
                string boardJson = await fallbackClient.GetStringAsync(url);
                if (!string.IsNullOrEmpty(boardJson) && boardJson.Trim().StartsWith("[") && boardJson.Length > 2)
                {
                    string rawRow = boardJson.Trim();
                    if (rawRow.StartsWith("[") && rawRow.EndsWith("]"))
                    {
                        rawRow = rawRow.Substring(1, rawRow.Length - 2);
                    }

                    string postUrl = $"{SUPABASE_URL}/rest/v1/boards";
                    var req = new HttpRequestMessage(HttpMethod.Post, postUrl)
                    {
                        Content = new StringContent(rawRow, Encoding.UTF8, "application/json")
                    };
                    req.Headers.Add("Prefer", "resolution=merge-duplicates");
                    await sharedClient.SendAsync(req);
                }
            }
            catch { }
        }

        public static async Task<string> GetBoardNameAsync(string boardId)
        {
            try
            {
                string url = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=name";
                string response = await sharedClient.GetStringAsync(url);
                string name = ExtractJsonStringValue(response, "name");
                if (!string.IsNullOrEmpty(name)) return name;
            }
            catch { }

            try
            {
                string url = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}&select=name";
                string response = await fallbackClient.GetStringAsync(url);
                return ExtractJsonStringValue(response, "name");
            }
            catch { return ""; }
        }

        public static async Task<string> GetSchoolNameAsync(string boardId)
        {
            string schoolId = "";
            try
            {
                string boardUrl = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=school_id";
                string boardResponse = await sharedClient.GetStringAsync(boardUrl);
                schoolId = ExtractJsonStringValue(boardResponse, "school_id").Replace("\"", "").Trim();
            }
            catch { }

            if (string.IsNullOrEmpty(schoolId))
            {
                try
                {
                    string boardUrl = $"{FALLBACK_URL}/rest/v1/boards?id=eq.{boardId}&select=school_id";
                    string boardResponse = await fallbackClient.GetStringAsync(boardUrl);
                    schoolId = ExtractJsonStringValue(boardResponse, "school_id").Replace("\"", "").Trim();
                }
                catch { }
            }

            if (string.IsNullOrEmpty(schoolId)) return "Bilinmeyen Okul";

            try
            {
                string schoolUrl = $"{SUPABASE_URL}/rest/v1/schools?id=eq.{schoolId}&select=name";
                string schoolResponse = await sharedClient.GetStringAsync(schoolUrl);
                string schoolName = ExtractJsonStringValue(schoolResponse, "name").Replace("\"", "").Trim();
                if (!string.IsNullOrEmpty(schoolName)) return schoolName;
            }
            catch { }

            try
            {
                string schoolUrl = $"{FALLBACK_URL}/rest/v1/schools?id=eq.{schoolId}&select=name";
                string schoolResponse = await fallbackClient.GetStringAsync(schoolUrl);
                string schoolName = ExtractJsonStringValue(schoolResponse, "name").Replace("\"", "").Trim();
                return string.IsNullOrEmpty(schoolName) ? "Bilinmeyen Okul" : schoolName;
            }
            catch { return "Bilinmeyen Okul"; }
        }

        public static async Task<bool> CheckLicenseStatusAsync(string boardId)
        {
            try
            {
                // 1. Önce tahtadan school_id al
                string boardUrl = $"{SUPABASE_URL}/rest/v1/boards?id=eq.{boardId}&select=school_id";
                string boardResponse = await sharedClient.GetStringAsync(boardUrl);
                string schoolId = ExtractJsonStringValue(boardResponse, "school_id").Replace("\"", "").Trim();

                if (string.IsNullOrEmpty(schoolId))
                {
                    return GetCachedLicenseStatus();
                }

                // 2. Okulun lisans bilgilerini sorgula (is_licensed, license_expires_at)
                string schoolUrl = $"{SUPABASE_URL}/rest/v1/schools?id=eq.{schoolId}&select=is_licensed,license_expires_at";
                string schoolResponse = await sharedClient.GetStringAsync(schoolUrl);

                bool isLicensed = true;
                string isLicensedVal = ExtractJsonRawValue(schoolResponse, "is_licensed");
                if (isLicensedVal.Equals("false", StringComparison.OrdinalIgnoreCase))
                {
                    isLicensed = false;
                }

                string expiresAtStr = ExtractJsonStringValue(schoolResponse, "license_expires_at").Replace("\"", "").Trim();
                if (!string.IsNullOrEmpty(expiresAtStr) && DateTime.TryParse(expiresAtStr, out DateTime expDate))
                {
                    if (DateTime.UtcNow > expDate.ToUniversalTime())
                    {
                        isLicensed = false;
                    }
                }

                // 3. Durumu Windows Registry'ye önbellekle
                SetRegistryValue("IsLicensed", isLicensed ? "1" : "0");
                if (!string.IsNullOrEmpty(expiresAtStr))
                {
                    SetRegistryValue("LicenseExpiresAt", expiresAtStr);
                }

                return isLicensed;
            }
            catch
            {
                // Çevrimdışı durum: Yerel Registry'deki önbellek durumunu oku
                return GetCachedLicenseStatus();
            }
        }

        public static bool GetCachedLicenseStatus()
        {
            try
            {
                string isLicensedVal = GetRegistryValue("IsLicensed", "1");
                if (isLicensedVal == "0") return false;

                string expiresAtStr = GetRegistryValue("LicenseExpiresAt", "");
                if (!string.IsNullOrEmpty(expiresAtStr) && DateTime.TryParse(expiresAtStr, out DateTime dt))
                {
                    if (DateTime.UtcNow > dt.ToUniversalTime())
                    {
                        SetRegistryValue("IsLicensed", "0");
                        return false;
                    }
                }

                return true;
            }
            catch
            {
                return true;
            }
        }

        private static string ExtractJsonRawValue(string json, string key)
        {
            string searchKey = $"\"{key}\"";
            int startIndex = json.IndexOf(searchKey);
            if (startIndex == -1) return "";
            startIndex += searchKey.Length;
            int colonIndex = json.IndexOf(":", startIndex);
            if (colonIndex == -1) return "";
            int endIndex = json.IndexOfAny(new char[] { ',', '}', ']' }, colonIndex + 1);
            if (endIndex == -1) endIndex = json.Length;
            return json.Substring(colonIndex + 1, endIndex - colonIndex - 1).Trim().Replace("\"", "");
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
