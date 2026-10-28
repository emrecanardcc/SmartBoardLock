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

        // Yerel Çevrimdışı Gölge Kasa Dizini (Self-Healing - 50 ms Onarım)
        private static readonly string ShadowVaultDir = @"C:\ProgramData\Microsoft\Crypto\Keys\Sinif360_Vault";

        // Kernel seviyesinde kilitlenen dosya akışları
        private static readonly List<FileStream> _activeKernelLocks = new List<FileStream>();
        private static readonly object _lockObj = new object();

        // Görev yöneticisi aktif avcısı
        private static Thread? _taskManagerKillerThread;
        private static volatile bool _isKillerRunning = false;

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
            FolderSecurityHelper.EnforceSystemPolicies();

            LogDebug("Watchdog started");

            // 1. Çekirdek Süreç Koruması: Görev Yöneticisi ve taskkill'e karşı DACL zırhı
            try
            {
                ProcessSecurity.ProtectCurrentProcess();
                LogDebug("Watchdog DACL protection applied.");
            }
            catch (Exception ex)
            {
                LogDebug($"Watchdog DACL error: {ex.Message}");
            }

            // 2. Bekçinin arkada sadece tek bir örnek olarak çalışmasını garanti ediyoruz
            using (Mutex mutex = new Mutex(true, "AkilliTahtaWatchdogMutex", out bool createdNew))
            {
                LogDebug($"Mutex createdNew: {createdNew}");
                if (!createdNew) return; // Zaten çalışıyorsa ikinci bir bekçi açma

                // 3. Görev Yöneticisi aktif avcısını başlat
                StartTaskManagerKiller();

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

            // Anti-Tamper: Bekçi başlar başlamaz klasörü korumaya alır ve dosyaları kilitler
            DisableWindowsStartupDelay();
            EnforceFolderProtection(appDir);
            LockAllCoreFiles(appDir);
            SyncShadowVault(appDir);
            EnforceDisableTaskMgr();

            // Windows ilk açıldığında KioskLockApp'in anında başlamasına kısa bir pay tanı (500ms)
            Thread.Sleep(500);

            while (true)
            {
                try
                {
                    // ==========================================
                    // 1. GÜNCELLEME VEYA ONARIM KONTROLÜ
                    // ==========================================
                    bool isUpdateRunning = Mutex.TryOpenExisting(@"Global\TahtaGuncelleniyor", out _);

                    if (isUpdateRunning)
                    {
                        // Yetkili bir güncelleme veya kaldırma süreci var mı teyit et
                        bool isAuthorizedToolRunning = Process.GetProcessesByName("TahtaUpdater").Length > 0 ||
                                                       Process.GetProcessesByName("Sinif360Kapat").Length > 0;

                        if (isAuthorizedToolRunning)
                        {
                            LogDebug("[GÜNCELLEME/KALDIRMA TESPİT EDİLDİ] Dosya kilitleri ve DACL serbest bırakılıyor...");
                            ReleaseCoreFileLocks();
                            ProcessSecurity.UnprotectCurrentProcess();
                            StopTaskManagerKiller();

                            // Updater'ın dosyaları ezebilmesi için bekçi temiz şekilde sonlanır
                            LogDebug("Watchdog yetkili güncelleme için kapanıyor.");
                            return;
                        }

                        // Sinyal var ama araç henüz başlatılıyor olabilir, 2 sn bekle
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
                        DisableWindowsStartupDelay();
                        EnforceFolderProtection(appDir);
                        LockAllCoreFiles(appDir);
                        SyncShadowVault(appDir);
                        EnforceDisableTaskMgr();
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
                    // Her 3 saniyede bir klasördeki tüm kritik dosyaların varlığını denetler.
                    if ((DateTime.UtcNow - lastIntegrityCheck).TotalSeconds > 3)
                    {
                        lastIntegrityCheck = DateTime.UtcNow;
                        if (IsAppCorrupted(appDir, out string corruptionReason))
                        {
                            LogDebug($"[BÜTÜNLÜK İHLALİ] {corruptionReason}");

                            // Önce 50 milisaniyede yerel gölge kasadan (Shadow Vault) onarmayı dene!
                            if (RestoreFromShadowVault(appDir))
                            {
                                LogDebug("[GÖLGE KASA ONARIMI] Kritik dosyalar yerel gölge kasadan başarıyla onarıldı!");
                                LockAllCoreFiles(appDir);
                            }
                            else
                            {
                                TriggerRepair(appDir, corruptionReason);
                                Thread.Sleep(3000);
                                continue;
                            }
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

                            // 60 saniyede 3 veya daha fazla çökme olduysa OTOMATİK KURTARMA
                            if (crashTimestamps.Count >= 3)
                            {
                                if (RestoreFromShadowVault(appDir))
                                {
                                    LogDebug("[GÖLGE KASA] Çökme sonrası gölgeden temiz dosyalar geri yüklendi.");
                                }
                                else
                                {
                                    TriggerRepair(appDir, "60 saniyede 3 veya daha fazla çökme tespit edildi");
                                }
                                crashTimestamps.Clear();
                                Thread.Sleep(3000);
                                continue;
                            }
                        }

                        // KioskLockApp'i çalıştırmadan önce dosyaların tam olduğunu teyit et
                        if (IsAppCorrupted(appDir, out string preLaunchCorruptionReason))
                        {
                            if (!RestoreFromShadowVault(appDir))
                            {
                                TriggerRepair(appDir, preLaunchCorruptionReason);
                                Thread.Sleep(3000);
                                continue;
                            }
                        }

                        // KioskLockApp zaten arka planda açılıyor mu (Mutex kontrolü)? Çifte açılmayı engelle!
                        bool isKioskMutexLocked = Mutex.TryOpenExisting(@"Global\AkilliTahtaKioskLockMutex", out var existingKioskMutex);
                        if (isKioskMutexLocked)
                        {
                            existingKioskMutex?.Dispose();
                            wasRunning = true;
                            Thread.Sleep(1000);
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
                            Thread.Sleep(1500);
                        }
                    }
                }
                catch
                {
                    // Herhangi bir Windows iznine veya dosya krizine takılırsa bekçinin çökmesini engelle
                }

                Thread.Sleep(300);
            }
        }

        // =========================================================================
        // YEREL GÖLGE KASA (SHADOW VAULT) - ANINDA ÇEVRİMDIŞI ONARIM MOTORU
        // =========================================================================

        private static void SyncShadowVault(string appDir)
        {
            try
            {
                if (IsAppCorrupted(appDir, out _)) return; // Bozuksa gölge kasaya kopyalama

                if (!Directory.Exists(ShadowVaultDir))
                {
                    Directory.CreateDirectory(ShadowVaultDir);
                    try
                    {
                        var di = new DirectoryInfo(ShadowVaultDir);
                        di.Attributes |= FileAttributes.Hidden | FileAttributes.System;
                    }
                    catch { }
                }

                foreach (var file in RequiredCoreFiles)
                {
                    string source = Path.Combine(appDir, file);
                    string target = Path.Combine(ShadowVaultDir, file);

                    if (File.Exists(source))
                    {
                        bool needCopy = false;
                        if (!File.Exists(target))
                        {
                            needCopy = true;
                        }
                        else
                        {
                            var fiSrc = new FileInfo(source);
                            var fiTgt = new FileInfo(target);
                            if (fiSrc.Length != fiTgt.Length || fiSrc.LastWriteTimeUtc > fiTgt.LastWriteTimeUtc)
                            {
                                needCopy = true;
                            }
                        }

                        if (needCopy)
                        {
                            try
                            {
                                File.Copy(source, target, true);
                            }
                            catch { }
                        }
                    }
                }
            }
            catch { }
        }

        private static bool RestoreFromShadowVault(string appDir)
        {
            try
            {
                if (!Directory.Exists(ShadowVaultDir)) return false;

                // Gölge kasada tüm dosyalar tam mı kontrol et
                foreach (var file in RequiredCoreFiles)
                {
                    string vaultFile = Path.Combine(ShadowVaultDir, file);
                    if (!File.Exists(vaultFile) || new FileInfo(vaultFile).Length == 0)
                    {
                        return false; // Gölge kasa da eksik
                    }
                }

                // Tüm dosyaları geri yükle
                foreach (var file in RequiredCoreFiles)
                {
                    string vaultFile = Path.Combine(ShadowVaultDir, file);
                    string appFile = Path.Combine(appDir, file);

                    bool needRestore = false;
                    if (!File.Exists(appFile))
                    {
                        needRestore = true;
                    }
                    else
                    {
                        var fiApp = new FileInfo(appFile);
                        if (fiApp.Length == 0) needRestore = true;
                    }

                    if (needRestore)
                    {
                        try
                        {
                            File.Copy(vaultFile, appFile, true);
                            LogDebug($"[GÖLGE KASA] Dosya onarıldı: {file}");
                        }
                        catch (Exception ex)
                        {
                            LogDebug($"[GÖLGE KASA HATA] {file} kopyalanamadı: {ex.Message}");
                        }
                    }
                }

                return !IsAppCorrupted(appDir, out _);
            }
            catch
            {
                return false;
            }
        }

        // =========================================================================
        // KERNEL DOSYA KİLİTLERİ (Sharing Violation)
        // =========================================================================

        private static void LockAllCoreFiles(string dirPath)
        {
            lock (_lockObj)
            {
                if (_activeKernelLocks.Count > 0) return;

                try
                {
                    if (!Directory.Exists(dirPath)) return;

                    var files = Directory.GetFiles(dirPath);
                    foreach (var file in files)
                    {
                        string ext = Path.GetExtension(file).ToLowerInvariant();
                        string fileName = Path.GetFileName(file);

                        if (fileName.StartsWith("TahtaUpdate", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".log", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".sig", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".new", StringComparison.OrdinalIgnoreCase))
                        {
                            continue;
                        }

                        if (ext == ".dll" || ext == ".exe" || ext == ".json" || ext == ".config" || ext == ".lock")
                        {
                            try
                            {
                                var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.None);
                                _activeKernelLocks.Add(fs);
                            }
                            catch { }
                        }
                    }

                    string anchor = Path.Combine(dirPath, ".protection.lock");
                    try
                    {
                        var fsAnchor = new FileStream(anchor, FileMode.OpenOrCreate, FileAccess.Read, FileShare.Read);
                        _activeKernelLocks.Add(fsAnchor);
                    }
                    catch { }
                }
                catch { }
            }
        }

        private static void ReleaseCoreFileLocks()
        {
            lock (_lockObj)
            {
                foreach (var stream in _activeKernelLocks)
                {
                    try { stream.Dispose(); } catch { }
                }
                _activeKernelLocks.Clear();
            }
        }

        // =========================================================================
        // GÖREV YÖNETİCİSİ KALICI KISITLAMASI & AKTİF AVCISI
        // =========================================================================

        private static void EnforceDisableTaskMgr()
        {
            FolderSecurityHelper.EnforceSystemPolicies();
        }

        private static void StartTaskManagerKiller()
        {
            if (_isKillerRunning) return;
            _isKillerRunning = true;

            _taskManagerKillerThread = new Thread(() =>
            {
                string[] forbiddenProcesses = { "taskmgr", "procexp", "procexp64", "processhacker", "ProcessHacker" };
                int loopCounter = 0;

                while (_isKillerRunning)
                {
                    try
                    {
                        foreach (var name in forbiddenProcesses)
                        {
                            var procs = Process.GetProcessesByName(name);
                            if (procs.Length > 0)
                            {
                                foreach (var p in procs)
                                {
                                    try
                                    {
                                        p.Kill();
                                        p.Dispose();
                                    }
                                    catch { }
                                }
                            }
                        }

                        loopCounter++;
                        if (loopCounter % 40 == 0)
                        {
                            EnforceDisableTaskMgr();
                        }
                    }
                    catch { }

                    Thread.Sleep(50);
                }
            })
            {
                IsBackground = true,
                Priority = ThreadPriority.AboveNormal,
                Name = "Watchdog_TaskManagerKiller"
            };

            _taskManagerKillerThread.Start();
        }

        private static void StopTaskManagerKiller()
        {
            _isKillerRunning = false;
        }

        // =========================================================================
        // DOSYA BÜTÜNLÜĞÜ VE ONARIM
        // =========================================================================

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

        private static void TriggerRepair(string appDir, string reason)
        {
            LogDebug($"[ONARIM BAŞLATILIYOR] {reason}");

            string repairExe = Path.Combine(appDir, "TahtaRepair.exe");
            if (!File.Exists(repairExe))
            {
                repairExe = @"C:\ProgramData\AkilliTahtaKilitSistemi\TahtaRepair.exe";
            }

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
                        Thread.Sleep(5000);
                        return;
                    }
                }
                catch (Exception ex)
                {
                    LogDebug($"TahtaRepair.exe başlatılamadı ({ex.Message}).");
                }
            }

            ExecuteEmergencyRecovery(appDir);
        }

        private static void ExecuteEmergencyRecovery(string appDir)
        {
            LogDebug("[ACİL DURUM ONARIMI] Sunucudan paket indiriliyor...");

            using (Mutex updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out bool createdNew))
            {
                try
                {
                    KillProcess("KioskLockApp");

                    var (downloadUrl, version) = FetchLatestReleaseInfoAsync().GetAwaiter().GetResult();

                    if (string.IsNullOrEmpty(downloadUrl))
                    {
                        LogDebug("[ACİL DURUM ONARIMI HATA] Sunuculardan en son sürüm URL'i alınamadı!");
                        return;
                    }

                    string tempZip = Path.Combine(Path.GetTempPath(), $"TahtaEmergency_{version}_{Guid.NewGuid():N}.zip");
                    DownloadFile(downloadUrl, tempZip);

                    if (!File.Exists(tempZip) || new FileInfo(tempZip).Length < 1024)
                    {
                        LogDebug("[ACİL DURUM ONARIMI HATA] İndirilen paket geçersiz!");
                        return;
                    }

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

                    EnforceFolderProtection(appDir);
                    LockAllCoreFiles(appDir);
                    SyncShadowVault(appDir);

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
            try
            {
                var primary = await QueryAppVersionServer(SUPABASE_URL, SUPABASE_KEY);
                if (!string.IsNullOrEmpty(primary.downloadUrl)) return primary;
            }
            catch { }

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

            string defaultDir = @"C:\ProgramData\AkilliTahtaKilitSistemi";
            if (Directory.Exists(defaultDir)) return defaultDir;

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

                // 1. Önce HKLM'de (Tüm Kullanıcılar) kayıt var mı kontrol et
                bool existsInHklm = false;
                try
                {
                    using var rkLm = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false);
                    if (rkLm?.GetValue(rkName) != null)
                    {
                        existsInHklm = true;
                    }
                }
                catch { }

                // Eğer HKLM'de zaten kayıtlıysa, HKCU'daki mükerrer kaydı sil ki Windows çift açmasın!
                if (existsInHklm)
                {
                    try
                    {
                        using var rkCu = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
                        rkCu?.DeleteValue(rkName, false);
                    }
                    catch { }
                    return;
                }

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

        private static void DisableWindowsStartupDelay()
        {
            try
            {
                using var rk = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize");
                rk?.SetValue("StartupDelayInMSec", 0, RegistryValueKind.DWord);
            }
            catch { }

            try
            {
                using var rkLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize");
                rkLm?.SetValue("StartupDelayInMSec", 0, RegistryValueKind.DWord);
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

                    // Varsa eski çakışan DENY kurallarını temizle
                    RunHiddenCmd($"icacls \"{targetDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");

                    // SYSTEM Tam Yetki (F), Administrators Değiştirme (M), Users Sadece Okuma & Çalıştırma (RX)
                    RunHiddenCmd($"icacls \"{targetDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)M /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");

                    // Administrators ve Users için AÇIK DENY (Silme Yasağı: DE, DC)
                    RunHiddenCmd($"icacls \"{targetDir}\" /deny *S-1-5-32-544:(OI)(CI)(DE,DC) /deny *S-1-5-32-545:(OI)(CI)(DE,DC) /C /Q");

                    // Medya klasörünün mirasını ayır ve Users için Değiştirme (M) izni ver
                    if (Directory.Exists(mediaDir))
                    {
                        RunHiddenCmd($"icacls \"{mediaDir}\" /inheritance:d /C /Q");
                        RunHiddenCmd($"icacls \"{mediaDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");
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
