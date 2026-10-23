using System;
using System.Diagnostics;
using System.Threading;
using System.Windows.Forms;
using KioskLockApp.UI;
using KioskLockApp.Services;
using KioskLockApp.Core;
using KioskLockApp.Hooks;
using Microsoft.Win32;

namespace KioskLockApp
{
    internal class Program
    {
        private static Mutex? _singleInstanceMutex;

        [STAThread]
        static void Main()
        {
            string debugLog = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "kiosk_debug.log");
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Main started (PID: {Environment.ProcessId})\n");

            // =========================================================================
            // TEK ÖRNEK (SINGLE-INSTANCE) GÜVENCESİ: ÇİFTE AÇILMAYI KESİNLİKLE ENGELLE
            // Windows başlangıcında HKLM, HKCU veya Watchdog kaynaklı mükerrer açılmaları
            // atomik çekirdek Mutex'i ile anında engeller.
            // =========================================================================
            bool createdNew = false;
            try
            {
                _singleInstanceMutex = new Mutex(true, @"Global\AkilliTahtaKioskLockMutex", out createdNew);
            }
            catch
            {
                try
                {
                    _singleInstanceMutex = new Mutex(true, @"Local\AkilliTahtaKioskLockMutex", out createdNew);
                }
                catch
                {
                    createdNew = true;
                }
            }

            if (!createdNew)
            {
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] MÜKERRER KİOSK ENGELLENDİ: İkinci kopya anında kapatıldı (PID: {Environment.ProcessId})\n");
                return; // Zaten çalışan bir KioskLockApp var, ikinciyi hemen sonlandır!
            }

            AppDomain.CurrentDomain.ProcessExit += (s, e) =>
            {
                try
                {
                    _singleInstanceMutex?.ReleaseMutex();
                    _singleInstanceMutex?.Dispose();
                }
                catch { }
            };

            // UI ve Thread Seviyesinde Hata Yakalayıcılar
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += (s, e) =>
            {
                try
                {
                    string logPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "kiosk_crash.log");
                    System.IO.File.AppendAllText(logPath, $"[{DateTime.UtcNow}] THREAD_CRASH: {e.Exception}\n");
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] THREAD_CRASH: {e.Exception}\n");
                }
                catch { }
            };

            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
            {
                try
                {
                    string logPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "kiosk_crash.log");
                    System.IO.File.AppendAllText(logPath, $"[{DateTime.UtcNow}] CRASH: {e.ExceptionObject}\n");
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] CRASH: {e.ExceptionObject}\n");
                }
                catch { }
            };

            Application.SetHighDpiMode(HighDpiMode.DpiUnawareGdiScaled);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // 1. Çekirdek Süreç Koruması: DACL seviyesinde Görev Yöneticisi ve taskkill sonlandırmalarını engelle
            try
            {
                ProcessSecurity.ProtectCurrentProcess();
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Process DACL protection enforced\n");
            }
            catch { }

            // 2. Küresel klavye kancasını başlat (Ctrl+Shift+Esc ve kilit tuşlarını yakalamak için)
            try
            {
                DeepWindowsHooks.InitializeHooks();
            }
            catch { }

            // 3. Bekleyen güncellemeleri (.new dosyaları) uygula
            ApplyPendingUpdates();
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Pending updates checked\n");

            // 4. Windows başlangıç kaydı güvencesi (Mükerrer HKCU kayıtlarını temizleyip tekil tutar)
            ForceStartup();
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] ForceStartup completed\n");

            // 5. Anti-Tamper: Program ve sistem klasörünü öğrencilerin silmesine karşı NTFS düzeyinde kilitle
            try
            {
                FolderSecurityHelper.EnsureProtected();
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Folder protection enforced\n");
            }
            catch { }

            // Registry'den kayıtlı tahta var mı kontrol et
            string boardId = "";
            try
            {
                using (RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    if (key != null)
                    {
                        boardId = key.GetValue("BoardId") as string ?? "";
                    }
                }
            }
            catch (Exception ex)
            {
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Registry error: {ex.Message}\n");
            }

            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] BoardId: '{boardId}'\n");

            // Eğer boardId yoksa (veya boşsa) kurulum/eşleşme ekranını aç
            if (string.IsNullOrEmpty(boardId))
            {
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Launching PairingScreen\n");
                Application.Run(new PairingScreen());
            }
            else
            {
                // =========================================================================
                // ANINDA AÇILMA (0ms) & ARKA PLANDA ASENKRON LİSANS DOĞRULAMA
                // =========================================================================
                // Windows açılışında ağ henüz bağlanmamışken 3 sn senkron beklemeyi kaldırıyoruz.
                // Önbellek durumunu yerel kayıt defterinden 0.05 ms içinde oku.
                bool isLicensed = SecureSupabase.GetCachedLicenseStatus();
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Instant cached license status: {isLicensed}\n");

                if (!isLicensed)
                {
                    // Önbellekte lisans açıkça geçersizse, son bir kez online teyit et
                    try
                    {
                        var licenseTask = System.Threading.Tasks.Task.Run(() => SecureSupabase.CheckLicenseStatusAsync(boardId));
                        if (licenseTask.Wait(2000))
                        {
                            isLicensed = licenseTask.Result;
                            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] License online check: {isLicensed}\n");
                        }
                    }
                    catch { }

                    if (!isLicensed)
                    {
                        System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] EXITING: Not licensed\n");
                        Environment.Exit(0);
                        return;
                    }
                }
                else
                {
                    // Önbellekte lisans geçerli: Kilit ekranı HİÇ BEKLEMEDEN ANINDA AÇILIR!
                    // Lisans doğrulaması ağ bağlantısı oturduktan sonra (5 sn sonra) arka planda teyit edilir.
                    System.Threading.Tasks.Task.Run(async () =>
                    {
                        try
                        {
                            await System.Threading.Tasks.Task.Delay(5000);
                            bool onlineStatus = await SecureSupabase.CheckLicenseStatusAsync(boardId);
                            if (!onlineStatus)
                            {
                                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Background license check failed/revoked, exiting.\n");
                                Environment.Exit(0);
                            }
                        }
                        catch { }
                    });
                }

                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Launching SecureRenderer\n");
                try
                {
                    Application.Run(new SecureRenderer());
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] SecureRenderer Application.Run exited normally\n");
                }
                catch (Exception ex)
                {
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] SecureRenderer Run EXCEPTION: {ex}\n");
                }
            }
        }

        // --- BAŞLANGIÇTA ZORLA ÇALIŞTIRMA VE HIZLANDIRMA FONKSİYONU ---
        private static void ForceStartup()
        {
            try
            {
                // 1. Windows Explorer 10-15 sn Başlangıç Gecikmesini (Startup Delay) sıfırla (0 ms açılış)
                FolderSecurityHelper.DisableWindowsStartupDelay();

                // 2. Windows Zamanlanmış Görevi (Task Scheduler OnLogon) kaydını güvenceye al:
                // Oturum açıldığı AN (0 ms) en yüksek yetkiyle başlar, Explorer masaüstü gecikmesine takılmaz.
                EnsureLogonScheduledTask();

                string appName = "AkilliTahtaKilitSistemi";
                string exePath = Application.ExecutablePath;

                // 1. Önce HKLM'de (Tüm Kullanıcılar) kayıt var mı kontrol et
                bool existsInHklm = false;
                try
                {
                    using (RegistryKey? rkLm = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                    {
                        if (rkLm?.GetValue(appName) != null)
                        {
                            existsInHklm = true;
                        }
                    }
                }
                catch { }

                // Eğer HKLM'de zaten kayıtlıysa, HKCU'daki mükerrer kaydı SİL ki Windows çift açmasın!
                if (existsInHklm)
                {
                    try
                    {
                        using (RegistryKey? rkCu = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                        {
                            rkCu?.DeleteValue(appName, false);
                        }
                    }
                    catch { }
                    return;
                }

                // HKLM'de yoksa HKCU'ya tekil olarak ekle
                using (RegistryKey? rk = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", true))
                {
                    if (rk != null)
                    {
                        if (rk.GetValue(appName) == null || rk.GetValue(appName)?.ToString() != exePath)
                        {
                            rk.SetValue(appName, exePath);
                        }
                    }
                }
            }
            catch { }
        }

        /// <summary>
        /// Windows Görev Zamanlayıcısı'na kullanıcı oturum açtığı anda çalışacak yüksek öncelikli görev kaydeder.
        /// Bu yöntem Windows Explorer'ın 10-15 saniyelik başlangıç bekleme sırasını tamamen atlar.
        /// </summary>
        private static void EnsureLogonScheduledTask()
        {
            try
            {
                string taskName = "Sinif360_InstantKiosk";
                string exePath = Application.ExecutablePath;

                System.Threading.Tasks.Task.Run(() =>
                {
                    try
                    {
                        var psi = new System.Diagnostics.ProcessStartInfo
                        {
                            FileName = "schtasks.exe",
                            Arguments = $"/create /tn \"{taskName}\" /tr \"\\\"{exePath}\\\"\" /sc onlogon /rl highest /f",
                            CreateNoWindow = true,
                            UseShellExecute = false,
                            WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden
                        };
                        using var proc = System.Diagnostics.Process.Start(psi);
                        proc?.WaitForExit(3000);
                    }
                    catch { }
                });
            }
            catch { }
        }

        // --- BEKLEYEN GÜNCELLEMELERİ UYGULA (.new dosyaları) ---
        private static void ApplyPendingUpdates()
        {
            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;

                // TahtaRepair.exe.new -> TahtaRepair.exe
                string repairNew = System.IO.Path.Combine(baseDir, "TahtaRepair.exe.new");
                string repairTarget = System.IO.Path.Combine(baseDir, "TahtaRepair.exe");
                if (System.IO.File.Exists(repairNew))
                {
                    try
                    {
                        if (System.IO.File.Exists(repairTarget))
                        {
                            System.IO.File.Delete(repairTarget);
                        }
                        System.IO.File.Move(repairNew, repairTarget);
                    }
                    catch { }
                }

                // TahtaUpdater.exe.new -> TahtaUpdater.exe
                string updaterNew = System.IO.Path.Combine(baseDir, "TahtaUpdater.exe.new");
                string updaterTarget = System.IO.Path.Combine(baseDir, "TahtaUpdater.exe");
                if (System.IO.File.Exists(updaterNew))
                {
                    try
                    {
                        if (System.IO.File.Exists(updaterTarget))
                        {
                            System.IO.File.Delete(updaterTarget);
                        }
                        System.IO.File.Move(updaterNew, updaterTarget);
                    }
                    catch { }
                }

                // Updater_v2.bin -> TahtaUpdater.exe (TahtaUpdater'ın StartsWith filtresini aşmak için)
                string updaterV2 = System.IO.Path.Combine(baseDir, "Updater_v2.bin");
                if (System.IO.File.Exists(updaterV2))
                {
                    try
                    {
                        if (System.IO.File.Exists(updaterTarget))
                        {
                            System.IO.File.Delete(updaterTarget);
                        }
                        System.IO.File.Move(updaterV2, updaterTarget);
                    }
                    catch { }
                }
            }
            catch { }
        }
    }
}
