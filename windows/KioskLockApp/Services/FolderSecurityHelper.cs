using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    /// <summary>
    /// Sınıf360 Akıllı Tahta Anti-Tamper & Klasör Koruma Motoru ("Demir Zırh").
    /// 1. NTFS seviyesinde Administrators ve Users için AÇIK DENY (Silme Yasağı: DE, DC).
    /// 2. Klasördeki tüm yürütülebilir (.exe) ve kütüphane (.dll) dosyalarına Kernel FileShare.Read kilidi.
    /// 3. Görev Yöneticisi'nin (taskmgr.exe) hiçbir koşulda açılmasına izin vermeyen aktif killer ve registry kilidi.
    /// 4. Windows Başlangıç Gecikmesini (10-15 sn) sıfırlayarak anında açılma güvencesi.
    /// 5. Uygulama yalnızca şifreli yetkili yönetici aracı (Sinif360_Kaldir.exe) ile kaldırılabilir.
    /// </summary>
    public static class FolderSecurityHelper
    {
        private static readonly List<FileStream> _activeKernelLocks = new List<FileStream>();
        private static readonly object _lockObj = new object();
        private static Thread? _taskManagerKillerThread;
        private static volatile bool _isKillerRunning = false;
        private static Task? _protectionTask;

        /// <summary>
        /// Sınıf360 kurulum klasörünü NTFS ve Çekirdek (Kernel) düzeyinde silinmeye ve değiştirilmeye karşı kilitler.
        /// Başlangıç hızını maksimize etmek için kritik çekirdek kilitleri 10 ms içinde alır,
        /// ağır icacls işlemlerini arka planda asenkron tamamlar.
        /// </summary>
        public static void EnsureProtected(string? customPath = null, bool synchronous = false)
        {
            try
            {
                string targetDir = customPath ?? AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');

                // Sadece ProgramData altındaki hedef klasörde veya test dizininde çalıştır
                if (!targetDir.Contains("ProgramData", StringComparison.OrdinalIgnoreCase) &&
                    !targetDir.Contains("AkilliTahtaKilitSistemi", StringComparison.OrdinalIgnoreCase) &&
                    !targetDir.Contains("AkilliTahtaKilitSistemi_Test_", StringComparison.OrdinalIgnoreCase))
                {
                    return;
                }

                if (!Directory.Exists(targetDir)) return;

                // 1. Kritik çekirdek dosya kilitlerini ANINDA al (Donanım/Kernel seviyesi - 2 ms)
                LockAllCoreFiles(targetDir);

                // 2. Sistem güvenlik politikalarını kalıcı olarak kayıt defterine işle (1 ms)
                EnforceSystemPolicies();

                // 3. Windows 10-15 saniyelik başlangıç gecikmesini sıfırla (0 ms açılış)
                DisableWindowsStartupDelay();

                // 4. Görev Yöneticisi aktif avcısını başlat (50 ms döngü)
                StartTaskManagerKiller();

                // 5. Media ve alt klasörlerin varlığını ANINDA garantiye al (<1 ms)
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

                // 6. icacls izinlerini ve klasör özniteliklerini uygula (Prod: arka planda, Test: senkron)
                Action applyAction = () =>
                {
                    try
                    {
                        var dirInfo = new DirectoryInfo(targetDir);
                        dirInfo.Attributes |= FileAttributes.Hidden | FileAttributes.System;
                    }
                    catch { }

                    ApplyIcaclsProtection(targetDir);
                };

                if (synchronous)
                {
                    applyAction();
                }
                else
                {
                    _protectionTask = Task.Run(applyAction);
                }
            }
            catch
            {
                // Hata durumunda uygulamanın açılışını engelleme
            }
        }

        public static void ApplyIcaclsProtection(string dirPath)
        {
            try
            {
                // 1. Media ve alt klasörlerin varlığını garantiye al
                string mediaDir = Path.Combine(dirPath, "Media");
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

                // 2. Varsa eski çakışan DENY kurallarını temizle
                RunHiddenCmd($"icacls \"{dirPath}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");

                // 3. Ana klasör temel izinleri:
                //    - SYSTEM (*S-1-5-18): Tam Yetki (Full Control)
                //    - Administrators (*S-1-5-32-544): Değiştirme (M) - (Yazma/Güncelleme serbest)
                //    - Users (*S-1-5-32-545): Sadece Okuma ve Çalıştırma (RX)
                RunHiddenCmd($"icacls \"{dirPath}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)M /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");

                // 4. AÇIK DENY (Silme ve Alt Klasör/Dosya Silme Yasağı):
                //    Administrators ve Users grupları için (DE,DC) - Delete and Delete Child açıkça engellenir!
                //    Windows NTFS'te DENY kuralı her zaman GRANT kuralını ezer.
                RunHiddenCmd($"icacls \"{dirPath}\" /deny *S-1-5-32-544:(OI)(CI)(DE,DC) /deny *S-1-5-32-545:(OI)(CI)(DE,DC) /C /Q");

                // 5. Medya önbellek klasörünün mirasını ayır ve afiş indirmeleri için Users & Admin'e Değiştirme (M) izni ver
                if (Directory.Exists(mediaDir))
                {
                    RunHiddenCmd($"icacls \"{mediaDir}\" /inheritance:d /C /Q");
                    RunHiddenCmd($"icacls \"{mediaDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");
                    RunHiddenCmd($"icacls \"{mediaDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)M /C /Q");
                }
            }
            catch { }
        }

        /// <summary>
        /// Ana klasördeki tüm .exe, .dll, .json, .config dosyalarını FileShare.Read ile kernel seviyesinde kilitler.
        /// Windows I/O Yöneticisi, bu dosyalara gelecek herhangi bir silme (Delete) veya isim değiştirme çağrısını
        /// ERROR_SHARING_VIOLATION (0x20) hatası ile reddeder.
        /// </summary>
        public static void LockAllCoreFiles(string dirPath)
        {
            lock (_lockObj)
            {
                if (_activeKernelLocks.Count > 0) return; // Zaten kilitli

                try
                {
                    if (!Directory.Exists(dirPath)) return;

                    var files = Directory.GetFiles(dirPath);
                    foreach (var file in files)
                    {
                        string ext = Path.GetExtension(file).ToLowerInvariant();
                        string fileName = Path.GetFileName(file);

                        // Geçici güncelleme veya log dosyalarını kilitleme
                        if (fileName.StartsWith("TahtaUpdate", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".log", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".sig", StringComparison.OrdinalIgnoreCase) ||
                            fileName.EndsWith(".new", StringComparison.OrdinalIgnoreCase))
                        {
                            continue;
                        }

                        // Kritik yürütülebilir, kütüphane ve konfigürasyon dosyalarını kilitle
                        if (ext == ".dll" || ext == ".exe" || ext == ".json" || ext == ".config" || ext == ".lock")
                        {
                            try
                            {
                                var fs = new FileStream(
                                    file,
                                    FileMode.Open,
                                    FileAccess.Read,
                                    FileShare.Read,
                                    4096,
                                    FileOptions.None);

                                _activeKernelLocks.Add(fs);
                            }
                            catch
                            {
                                // Zaten kilitli veya erişilemiyorsa devam et
                            }
                        }
                    }

                    // Ayrıca özel anchor lock dosyası aç (FileAccess.Read)
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

        /// <summary>
        /// Güncelleme esnasında dosyaların değiştirilebilmesi için kernel kilitlerini serbest bırakır.
        /// </summary>
        public static void ReleaseCoreFileLocks()
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

        /// <summary>
        /// Güncelleme veya kaldırma işlemi öncesinde klasör üzerindeki DENY kilitlerini ve dosya akışlarını kaldırır.
        /// </summary>
        public static void UnlockFolder(string dirPath)
        {
            try
            {
                // Arka planda devam eden icacls görevi varsa tamamlanmasını bekle
                try { _protectionTask?.Wait(4000); } catch { }

                StopTaskManagerKiller();
                RestoreSystemPolicies();
                ReleaseCoreFileLocks();

                // DENY ACE'lerini temizle
                RunHiddenCmd($"icacls \"{dirPath}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /T /C /Q");

                // Yöneticilere Tam Yetki, Kullanıcılara Değiştirme izni ver
                RunHiddenCmd($"icacls \"{dirPath}\" /grant *S-1-5-32-544:(OI)(CI)F /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q");

                // Gizli ve Sistem özniteliklerini kaldır
                RunHiddenCmd($"attrib -s -h \"{dirPath}\"");
            }
            catch { }
        }

        /// <summary>
        /// Kritik Windows sistem politikalarını hem HKCU hem de HKLM düzeyinde kayıt defterine yazar:
        /// 1. Policies\System\DisableTaskMgr = 1 (Görev Yöneticisi açılmasını engeller)
        /// 2. Policies\System\DisableLockWorkstation = 1 (Win+L kilit ekranını engeller)
        /// 3. Policies\Explorer\NoRun = 1 (Win+R / Çalıştır iletişim kutusunu engeller)
        /// 4. Policies\ActiveDesktop\NoChangingWallPaper = 1 (Masaüstü duvar kâğıdı değiştirilmesini engeller)
        /// </summary>
        public static void EnforceSystemPolicies(RegistryKey? testRootKey = null)
        {
            if (testRootKey != null)
            {
                try
                {
                    using var rkSys = testRootKey.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System");
                    rkSys?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                    rkSys?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
                }
                catch { }

                try
                {
                    using var rkExp = testRootKey.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                    rkExp?.SetValue("NoRun", 1, RegistryValueKind.DWord);
                }
                catch { }

                try
                {
                    using var rkAd = testRootKey.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                    rkAd?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
                }
                catch { }
                return;
            }

            // 1. Policies\System (HKCU)
            try
            {
                using var rkSys = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSys?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSys?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 2. Policies\System (HKLM)
            try
            {
                using var rkSysLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSysLm?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSysLm?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 3. Policies\Explorer (HKCU)
            try
            {
                using var rkExp = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExp?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 4. Policies\Explorer (HKLM)
            try
            {
                using var rkExpLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExpLm?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 5. Policies\ActiveDesktop (HKCU)
            try
            {
                using var rkAd = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAd?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 6. Policies\ActiveDesktop (HKLM)
            try
            {
                using var rkAdLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAdLm?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }
        }

        /// <summary>
        /// Kısıtlayıcı sistem politikalarını hem HKCU hem de HKLM kovanlarından temizler.
        /// Kilit açma (Unlock) ve kaldırma (Uninstall) senaryolarında çağrılır.
        /// </summary>
        public static void RestoreSystemPolicies(RegistryKey? testRootKey = null)
        {
            if (testRootKey != null)
            {
                try
                {
                    using var key = testRootKey.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System", true);
                    key?.DeleteValue("DisableTaskMgr", false);
                    key?.DeleteValue("DisableLockWorkstation", false);
                }
                catch { }

                try
                {
                    using var key = testRootKey.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", true);
                    key?.DeleteValue("NoRun", false);
                }
                catch { }

                try
                {
                    using var key = testRootKey.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true);
                    key?.DeleteValue("NoChangingWallPaper", false);
                }
                catch { }
                return;
            }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System", true);
                key?.DeleteValue("DisableTaskMgr", false);
                key?.DeleteValue("DisableLockWorkstation", false);
            }
            catch { }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", true);
                key?.DeleteValue("NoRun", false);
            }
            catch { }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true);
                key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", true);
                key?.DeleteValue("DisableTaskMgr", false);
                key?.DeleteValue("DisableLockWorkstation", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", true);
                key?.DeleteValue("NoRun", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true);
                key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }
        }

        /// <summary>
        /// Kayıt Defteri üzerinden Görev Yöneticisi'ni devre dışı bırakır (DisableTaskMgr = 1).
        /// Hem HKCU hem HKLM seviyesinde yazılır.
        /// </summary>
        public static void EnforceDisableTaskMgr()
        {
            EnforceSystemPolicies();
        }

        /// <summary>
        /// Windows'un başlangıç uygulamalarını 10-15 saniye ertelemesini (Startup Delay) devre dışı bırakır.
        /// Uygulamanın oturum açıldığı saniyede (0 ms gecikmeyle) başlamasını sağlar.
        /// </summary>
        public static void DisableWindowsStartupDelay()
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

        /// <summary>
        /// Görev Yöneticisi veya benzeri süreç inceleme araçlarını 50 ms içinde tespit edip anında sonlandırır.
        /// </summary>
        public static void StartTaskManagerKiller()
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
                            EnforceSystemPolicies();
                            DisableWindowsStartupDelay();
                        }
                    }
                    catch { }

                    Thread.Sleep(50);
                }
            })
            {
                IsBackground = true,
                Priority = ThreadPriority.AboveNormal,
                Name = "Sinif360_TaskManagerKiller"
            };

            _taskManagerKillerThread.Start();
        }

        public static void StopTaskManagerKiller()
        {
            _isKillerRunning = false;
        }

        public static void RunHiddenCmd(string command)
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
    }
}
