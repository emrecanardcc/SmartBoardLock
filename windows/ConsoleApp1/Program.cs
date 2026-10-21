using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Runtime.Versioning;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace WatchdogService
{
    [SupportedOSPlatform("windows")]
    internal class Program
    {
        // Birincil Sunucu: Oracle Cloud Always Free Self-Hosted Supabase
        public const string SUPABASE_URL = "http://130.61.78.192:8000";
        private const string _b64Key = "ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA==";
        public static readonly string SUPABASE_KEY = Encoding.UTF8.GetString(Convert.FromBase64String(_b64Key));

        // İkincil / Yedek Sunucu: Cloud Supabase
        public const string FALLBACK_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        private const string _b64FallbackKey = "ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW1Oc2EyRnpibUp3Yldoa1pHaHpkRzlwZUdSNklpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RJNU9EYzRPRFFzSW1WNGNDSTZNakE1T0RVMk16ZzROSDAuS3B3T1pvV3dPdTJEZndPZWMweTVMU3ZTNk1SR0d5NFVxb3QtUTFHMF94OA==";
        public static readonly string FALLBACK_KEY = Encoding.UTF8.GetString(Convert.FromBase64String(_b64FallbackKey));

        // Sistemin çalışması için klasörde MUTLAKA bulunması ve 0 bayttan büyük olması gereken kritik çekirdek dosyalar
        private static readonly string[] RequiredCoreFiles = new[]
        {
            "KioskLockApp.exe",
            "KioskLockApp.dll",
            "KioskLockApp.runtimeconfig.json",
            "KioskLockApp.deps.json",
            "WatchdogService.exe",
            "WatchdogService.dll",
            "WatchdogService.runtimeconfig.json",
            "TahtaRepair.exe",
            "TahtaUpdater.exe",
            "Supabase.dll",
            "Supabase.Realtime.dll",
            "Supabase.Storage.dll",
            "Supabase.Postgrest.dll",
            "Supabase.Gotrue.dll",
            "QRCoder.dll",
            "Otp.NET.dll",
            "Newtonsoft.Json.dll",
            "Microsoft.IdentityModel.Tokens.dll",
            "Microsoft.IdentityModel.JsonWebTokens.dll"
        };

        static void Main(string[] args)
        {
            LogDebug("Watchdog started");

            // Bekçinin arkada sadece tek bir örnek olarak çalışmasını garanti ediyoruz
            using (Mutex mutex = new Mutex(true, "AkilliTahtaWatchdogMutex", out bool createdNew))
            {
                LogDebug($"Mutex createdNew: {createdNew}");
                if (!createdNew) return; // Zaten çalışıyorsa ikinci bir bekçi açma
                StartWatchdogLoop();
            }
        }

        private static void StartWatchdogLoop()
        {
            string rkName = "AkilliTahtaKilitSistemi";
            string targetProcessName = "KioskLockApp";
            List<DateTime> crashTimestamps = new List<DateTime>();
            bool wasRunning = false;
            DateTime lastIntegrityCheck = DateTime.MinValue;
            DateTime lastProtectionCheck = DateTime.MinValue;

            string appDir = ResolveAppDirectory();

            // Anti-Tamper: Bekçi başlar başlamaz klasörü korumaya alır
            EnforceFolderProtection(appDir);

            while (true)
            {
                try
                {
                    // ==========================================
                    // 1. GÜNCELLEME VEYA ONARIM KONTROLÜ
                    // ==========================================
                    // İşletim sisteminde "Global\TahtaGuncelleniyor" adında bir sinyal var mı bakıyoruz
                    bool isUpdateRunning = Mutex.TryOpenExisting(@"Global\TahtaGuncelleniyor", out _);

                    if (isUpdateRunning)
                    {
                        // Sinyal var! Demek ki KioskLockApp güncelleniyor veya TahtaRepair çalışıyor.
                        // Kiosk'u geri açmaya ÇALIŞMA, 2 saniye bekle ve döngüyü başa sar.
                        wasRunning = false;
                        Thread.Sleep(2000);
                        continue;
                    }

                    // ==========================================
                    // 2. DİZİN VE REGISTRY TEYİDİ
                    // ==========================================
                    appDir = ResolveAppDirectory();
                    string kioskExePath = Path.Combine(appDir, "KioskLockApp.exe");

                    // Periyodik Klasör Koruması & Başlangıç Kaydı Güvencesi (her 60 saniyede bir)
                    if ((DateTime.UtcNow - lastProtectionCheck).TotalSeconds > 60)
                    {
                        lastProtectionCheck = DateTime.UtcNow;
                        EnforceFolderProtection(appDir);
                        EnsureStartupRegistry(rkName, kioskExePath);

                        string newRepair = Path.Combine(appDir, "TahtaRepair.exe.new");
                        if (File.Exists(newRepair))
                        {
                            try { File.Move(newRepair, Path.Combine(appDir, "TahtaRepair.exe"), true); } catch { }
                        }
                    }

                    // ==========================================
                    // 3. DOSYA BÜTÜNLÜĞÜ TARAMASI (Self-Healing)
                    // ==========================================
                    // Her 5 saniyede bir klasördeki tüm kritik dosyaların varlığını ve boyutunu denetler.
                    // Bir öğrenci Görev Yöneticisi -> "Dosya konumunu aç" ile dosya silmişse anında tespit edilir.
                    if ((DateTime.UtcNow - lastIntegrityCheck).TotalSeconds > 5)
                    {
                        lastIntegrityCheck = DateTime.UtcNow;
                        if (IsAppCorrupted(appDir, out string corruptionReason))
                        {
                            TriggerRepair(appDir, corruptionReason);
                            Thread.Sleep(3000);
                            continue;
                        }
                    }

                    // ==========================================
                    // 4. SÜREÇ İZLEME VE ÇÖKME / KAPATMA YÖNETİMİ
                    // ==========================================
                    Process[] processes = Process.GetProcessesByName(targetProcessName);

                    if (processes.Length > 0)
                    {
                        wasRunning = true;
                    }
                    else
                    {
                        // Süreç çalışmıyor!

                        // LİSANS KONTROLÜ: Lisans geçersizse bekçi KioskLockApp'i çalıştırmaz
                        if (!IsLicenseValid())
                        {
                            Thread.Sleep(5000);
                            continue;
                        }

                        // Eğer daha önce çalışıyorduysa ve şimdi kapandıysa -> Çökme tespiti
                        if (wasRunning)
                        {
                            wasRunning = false;
                            crashTimestamps.RemoveAll(t => (DateTime.UtcNow - t).TotalSeconds > 60);
                            crashTimestamps.Add(DateTime.UtcNow);

                            // 60 saniyede 3 veya daha fazla çökme olduysa OTOMATİK KURTARMA (TahtaRepair)
                            if (crashTimestamps.Count >= 3)
                            {
                                TriggerRepair(appDir, "60 saniyede 3 veya daha fazla çökme tespit edildi");
                                crashTimestamps.Clear();
                                Thread.Sleep(5000);
                                continue;
                            }
                        }

                        // KioskLockApp'i çalıştırmadan önce dosyaların tam olduğunu garantiye al!
                        if (IsAppCorrupted(appDir, out string preLaunchCorruptionReason))
                        {
                            TriggerRepair(appDir, preLaunchCorruptionReason);
                            Thread.Sleep(3000);
                            continue;
                        }

                        // Normal yeniden başlatma
                        if (File.Exists(kioskExePath))
                        {
                            ProcessStartInfo startInfo = new ProcessStartInfo(kioskExePath)
                            {
                                UseShellExecute = true,
                                WorkingDirectory = appDir
                            };
                            Process.Start(startInfo);
                            // Uygulamanın ayağa kalkması için 1.5 saniye bekle
                            Thread.Sleep(1500);
                        }
                    }
                }
                catch
                {
                    // Herhangi bir Windows iznine veya dosya krizine takılırsa bekçinin çökmesini engelle
                }

                // 300 milisaniyede bir kontrolü tekrarla
                Thread.Sleep(300);
            }
        }

        /// <summary>
        /// Uygulama klasöründeki kritik yürütülebilir ve kütüphane dosyalarını tarar.
        /// Eksik veya 0 bayt (bozulmuş) bir dosya bulunursa true döner.
        /// </summary>
        public static bool IsAppCorrupted(string appDir, out string reason)
        {
            reason = string.Empty;
            if (string.IsNullOrWhiteSpace(appDir) || !Directory.Exists(appDir))
            {
                reason = $"Kurulum dizini bulunamadı: '{appDir}'";
                return true;
            }

            foreach (var file in RequiredCoreFiles)
            {
                string fullPath = Path.Combine(appDir, file);
                if (!File.Exists(fullPath))
                {
                    reason = $"Kritik sistem dosyası eksik veya silinmiş: {file}";
                    return true;
                }

                try
                {
                    var fi = new FileInfo(fullPath);
                    if (fi.Length == 0)
                    {
                        reason = $"Kritik sistem dosyası bozulmuş (0 bayt): {file}";
                        return true;
                    }
                }
                catch (Exception ex)
                {
                    reason = $"Dosyaya erişilemiyor ({file}): {ex.Message}";
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// Hasar tespiti durumunda onarımı tetikler.
        /// TahtaRepair.exe mevcutsa tam ekran kurtarma modunda onu çalıştırır;
        /// TahtaRepair.exe de silinmişse bekçi doğrudan sunucudan en güncel paketi indirip onarımı tamamlar.
        /// </summary>
        private static void TriggerRepair(string appDir, string reason)
        {
            LogDebug($"[BÜTÜNLÜK İHLALİ] {reason}. Onarım mekanizması devreye giriyor...");

            string repairExe = Path.Combine(appDir, "TahtaRepair.exe");
            if (!File.Exists(repairExe))
            {
                repairExe = @"C:\ProgramData\AkilliTahtaKilitSistemi\TahtaRepair.exe";
            }

            // 1. ADIM: TahtaRepair.exe mevcutsa çalıştır
            if (File.Exists(repairExe))
            {
                try
                {
                    var fi = new FileInfo(repairExe);
                    if (fi.Length > 1024)
                    {
                        ProcessStartInfo repairInfo = new ProcessStartInfo(repairExe, $"--auto-recovery \"{appDir}\"")
                        {
                            UseShellExecute = true,
                            WorkingDirectory = Path.GetDirectoryName(repairExe) ?? appDir
                        };
                        Process.Start(repairInfo);
                        LogDebug($"TahtaRepair.exe başarıyla tetiklendi. Parametre: --auto-recovery \"{appDir}\"");
                        Thread.Sleep(5000);
                        return;
                    }
                }
                catch (Exception ex)
                {
                    LogDebug($"TahtaRepair.exe başlatılamadı ({ex.Message}). Acil durum onarımı devreye giriyor.");
                }
            }

            // 2. ADIM: TahtaRepair.exe yoksa veya silinmişse -> Bekçi doğrudan sunucudan en güncel paketi indirip kurtarır!
            ExecuteEmergencyRecovery(appDir);
        }

        /// <summary>
        /// TahtaRepair.exe bile silinmişse devreye giren en üst düzey yedek onarım motoru.
        /// Sunucudan (Oracle VM veya Fallback Cloud) en son yayın paketini çeker, açar ve sistemi ayağa kaldırır.
        /// </summary>
        private static void ExecuteEmergencyRecovery(string appDir)
        {
            LogDebug("[ACİL DURUM ONARIMI] TahtaRepair bulunamadı veya hasarlı. Watchdog doğrudan sunucu ile eşitleniyor...");

            // Watchdog ve updater çakışmasını önle
            using (Mutex updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out bool createdNew))
            {
                try
                {
                    // Çalışan Kiosk sürecini durdur
                    KillProcess("KioskLockApp");

                    // En son sürüm bilgisini sunuculardan sorgula
                    var (downloadUrl, version) = FetchLatestReleaseInfoAsync().GetAwaiter().GetResult();

                    if (string.IsNullOrEmpty(downloadUrl))
                    {
                        LogDebug("[ACİL DURUM ONARIMI HATA] Sunuculardan en son sürüm URL'i alınamadı!");
                        return;
                    }

                    LogDebug($"[ACİL DURUM ONARIMI] En güncel sürüm bulundu: v{version}. İndiriliyor: {downloadUrl}");

                    string tempZip = Path.Combine(Path.GetTempPath(), $"TahtaEmergency_{version}_{Guid.NewGuid():N}.zip");
                    DownloadFile(downloadUrl, tempZip);

                    if (!File.Exists(tempZip) || new FileInfo(tempZip).Length < 1024)
                    {
                        LogDebug("[ACİL DURUM ONARIMI HATA] İndirilen paket geçersiz veya bozuk!");
                        return;
                    }

                    // Dosyaları çıkart
                    LogDebug($"[ACİL DURUM ONARIMI] Paket {appDir} dizinine çıkartılıyor...");
                    using (ZipArchive archive = ZipFile.OpenRead(tempZip))
                    {
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            if (string.IsNullOrEmpty(entry.Name)) continue;

                            string destFile = Path.Combine(appDir, entry.FullName);
                            string? destDir = Path.GetDirectoryName(destFile);
                            if (!string.IsNullOrEmpty(destDir) && !Directory.Exists(destDir))
                            {
                                Directory.CreateDirectory(destDir);
                            }

                            // Çalışan Watchdog exe'si kilitli olacağından WatchdogService.exe.new olarak bırakabiliriz
                            if (entry.Name.Equals("WatchdogService.exe", StringComparison.OrdinalIgnoreCase))
                            {
                                try
                                {
                                    entry.ExtractToFile(destFile, true);
                                }
                                catch
                                {
                                    entry.ExtractToFile(Path.Combine(appDir, "WatchdogService.exe.new"), true);
                                }
                                continue;
                            }

                            try
                            {
                                if (File.Exists(destFile))
                                {
                                    File.SetAttributes(destFile, FileAttributes.Normal);
                                }
                                entry.ExtractToFile(destFile, true);
                            }
                            catch (Exception ex)
                            {
                                LogDebug($"Dosya açma atlandı: {entry.FullName} ({ex.Message})");
                            }
                        }
                    }

                    try { File.Delete(tempZip); } catch { }

                    LogDebug("[ACİL DURUM ONARIMI] Dosyalar başarıyla geri yüklendi. Kiosk yeniden başlatılıyor.");

                    // Klasör korumasını yeniden sağla
                    EnforceFolderProtection(appDir);

                    // KioskLockApp'i başlat
                    string kioskExe = Path.Combine(appDir, "KioskLockApp.exe");
                    if (File.Exists(kioskExe))
                    {
                        Process.Start(new ProcessStartInfo(kioskExe)
                        {
                            UseShellExecute = true,
                            WorkingDirectory = appDir
                        });
                    }
                }
                catch (Exception ex)
                {
                    LogDebug($"[ACİL DURUM ONARIMI KRİTİK HATA] {ex.Message}");
                }
            }
        }

        private static async Task<(string downloadUrl, string version)> FetchLatestReleaseInfoAsync()
        {
            // 1. Oracle Cloud Always Free VM
            try
            {
                var primary = await QueryAppVersionServer(SUPABASE_URL, SUPABASE_KEY);
                if (!string.IsNullOrEmpty(primary.downloadUrl)) return primary;
            }
            catch { }

            // 2. Cloud Supabase Fallback
            try
            {
                var fallback = await QueryAppVersionServer(FALLBACK_URL, FALLBACK_KEY);
                if (!string.IsNullOrEmpty(fallback.downloadUrl)) return fallback;
            }
            catch { }

            return (string.Empty, string.Empty);
        }

        private static async Task<(string downloadUrl, string version)> QueryAppVersionServer(string baseUrl, string apiKey)
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
            client.DefaultRequestHeaders.Add("apikey", apiKey);
            client.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");

            string url = $"{baseUrl}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1";
            string json = await client.GetStringAsync(url);

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            if (root.ValueKind == JsonValueKind.Array && root.GetArrayLength() > 0)
            {
                var first = root[0];
                string ver = first.GetProperty("version_number").GetString() ?? "";
                string dl = first.GetProperty("download_url").GetString() ?? "";
                return (dl, ver);
            }

            return (string.Empty, string.Empty);
        }

        private static void DownloadFile(string url, string destination)
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
            using var s = client.GetStreamAsync(url).GetAwaiter().GetResult();
            using var fs = new FileStream(destination, FileMode.Create, FileAccess.Write, FileShare.None);
            s.CopyTo(fs);
        }

        private static void KillProcess(string procName)
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(procName))
                {
                    try { p.Kill(); p.WaitForExit(2000); } catch { }
                }
            }
            catch { }
        }

        private static string ResolveAppDirectory()
        {
            try
            {
                // 1. Registry'den oku
                using (var rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                {
                    if (rk != null)
                    {
                        var val = rk.GetValue("AkilliTahtaKilitSistemi")?.ToString();
                        if (!string.IsNullOrWhiteSpace(val))
                        {
                            string? dir = Path.GetDirectoryName(val);
                            if (!string.IsNullOrWhiteSpace(dir) && Directory.Exists(dir))
                                return dir;
                        }
                    }
                }
            }
            catch { }

            // 2. Standart ProgramData
            string defaultDir = @"C:\ProgramData\AkilliTahtaKilitSistemi";
            if (Directory.Exists(defaultDir)) return defaultDir;

            // 3. Çalıştığı klasör
            return AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
        }

        private static bool IsLicenseValid()
        {
            try
            {
                using var rkLock = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock", false);
                if (rkLock != null)
                {
                    string isLicensed = rkLock.GetValue("IsLicensed")?.ToString()?.Trim() ?? "1";
                    if (isLicensed == "0") return false;

                    string licenseExpiresAt = rkLock.GetValue("LicenseExpiresAt")?.ToString()?.Trim() ?? "";
                    if (!string.IsNullOrEmpty(licenseExpiresAt) && DateTime.TryParse(licenseExpiresAt, out DateTime expDate))
                    {
                        if (DateTime.UtcNow > expDate.ToUniversalTime())
                            return false;
                    }
                }
            }
            catch { }
            return true;
        }

        private static void EnsureStartupRegistry(string rkName, string kioskExePath)
        {
            try
            {
                if (!File.Exists(kioskExePath)) return;
                using var rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
                if (rk != null)
                {
                    object? val = rk.GetValue(rkName);
                    if (val == null || !string.Equals(val.ToString(), kioskExePath, StringComparison.OrdinalIgnoreCase))
                    {
                        rk.SetValue(rkName, kioskExePath);
                        LogDebug($"Başlangıç kayıt defteri anahtarı güvenceye alındı: {kioskExePath}");
                    }
                }
            }
            catch { }
        }

        private static void EnforceFolderProtection(string? customPath = null)
        {
            try
            {
                string targetDir = customPath ?? AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
                if (!targetDir.Contains("ProgramData", StringComparison.OrdinalIgnoreCase) &&
                    !targetDir.Contains("AkilliTahtaKilitSistemi", StringComparison.OrdinalIgnoreCase))
                {
                    targetDir = @"C:\ProgramData\AkilliTahtaKilitSistemi";
                }

                if (Directory.Exists(targetDir))
                {
                    try
                    {
                        var dirInfo = new DirectoryInfo(targetDir);
                        dirInfo.Attributes |= FileAttributes.Hidden | FileAttributes.System;
                    }
                    catch { }

                    string mediaDir = Path.Combine(targetDir, "Media");
                    try
                    {
                        if (!Directory.Exists(mediaDir)) Directory.CreateDirectory(mediaDir);
                        string postersDir = Path.Combine(mediaDir, "Posters");
                        string defaultDir = Path.Combine(mediaDir, "Default");
                        string annDir = Path.Combine(mediaDir, "Announcements");
                        if (!Directory.Exists(postersDir)) Directory.CreateDirectory(postersDir);
                        if (!Directory.Exists(defaultDir)) Directory.CreateDirectory(defaultDir);
                        if (!Directory.Exists(annDir)) Directory.CreateDirectory(annDir);
                    }
                    catch { }

                    // Varsa eski çakışan DENY kuralını kaldır
                    RunHiddenCmd($"icacls \"{targetDir}\" /remove:d *S-1-5-32-545 /C /Q");

                    // Ana klasör: SYSTEM ve Administrators Tam Yetki (F), Users sadece Okuma & Çalıştırma (RX)
                    RunHiddenCmd($"icacls \"{targetDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");

                    // Medya klasörünün mirasını ayır ve Users için Değiştirme (M) izni ver
                    if (Directory.Exists(mediaDir))
                    {
                        RunHiddenCmd($"icacls \"{mediaDir}\" /inheritance:d /C /Q");
                        RunHiddenCmd($"icacls \"{mediaDir}\" /remove:d *S-1-5-32-545 /C /Q");
                        RunHiddenCmd($"icacls \"{mediaDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)M /C /Q");
                    }
                }
            }
            catch { }
        }

        private static void RunHiddenCmd(string command)
        {
            try
            {
                using var p = Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/c {command}",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                });
                p?.WaitForExit(3000);
            }
            catch { }
        }

        private static void LogDebug(string message)
        {
            try
            {
                string debugLog = Path.Combine(Path.GetTempPath(), "watchdog_debug.log");
                File.AppendAllText(debugLog, $"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}] {message}\n");
            }
            catch { }
        }
    }
}
