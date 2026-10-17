using System;
using System.Windows.Forms;
using KioskLockApp.UI;
using KioskLockApp.Services;
using Microsoft.Win32; // Kayıt Defteri (Registry) işlemleri için gerekli kütüphane

namespace KioskLockApp
{
    internal class Program
    {
        [STAThread]
        static void Main()
        {
            string debugLog = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "kiosk_debug.log");
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Main started\n");

            AppDomain.CurrentDomain.UnhandledException += (s, e) => {
                try
                {
                    string logPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "kiosk_crash.log");
                    System.IO.File.AppendAllText(logPath, $"[{DateTime.UtcNow}] CRASH: {e.ExceptionObject}\n");
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] CRASH: {e.ExceptionObject}\n");
                }
                catch { }
            };

            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Bekleyen güncellemeleri (.new dosyaları) uygula
            ApplyPendingUpdates();
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Pending updates checked\n");

            // Windows başlar başlamaz çalışması için Kayıt Defterine kanca atıyoruz
            ForceStartup();
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] ForceStartup completed\n");

            // Registry'den kayıtlı tahta var mı kontrol et
            string boardId = "";
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    if (key != null)
                    {
                        boardId = key.GetValue("BoardId") as string;
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
                // LİSANS DOĞRULAMA & SESSİZ KAPANMA KONTROLÜ
                // =========================================================================
                bool isLicensed = true;
                try
                {
                    var licenseTask = System.Threading.Tasks.Task.Run(() => SecureSupabase.CheckLicenseStatusAsync(boardId));
                    if (licenseTask.Wait(3000))
                    {
                        isLicensed = licenseTask.Result;
                        System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] License online check: {isLicensed}\n");
                    }
                    else
                    {
                        isLicensed = SecureSupabase.GetCachedLicenseStatus();
                        System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] License timed out, cached: {isLicensed}\n");
                    }
                }
                catch (Exception ex)
                {
                    isLicensed = SecureSupabase.GetCachedLicenseStatus();
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] License exception: {ex.Message}, cached: {isLicensed}\n");
                }

                if (!isLicensed)
                {
                    System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] EXITING: Not licensed\n");
                    Environment.Exit(0);
                    return;
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

        // --- BAŞLANGIÇTA ZORLA ÇALIŞTIRMA FONKSİYONU ---
        private static void ForceStartup()
        {
            try
            {
                // Uygulamanın bilgisayarda o an nerede çalıştığını (.exe yolunu) bul
                string appName = "AkilliTahtaKilitSistemi";
                string exePath = Application.ExecutablePath;

                // Windows'un "Otomatik Başlat" listesini aç (Düzenleme yetkisiyle)
                RegistryKey rk = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", true);

                if (rk != null)
                {
                    // Eğer uygulamamız listede yoksa veya .exe'nin yeri değişmişse, listeye ZORLA YAZ!
                    if (rk.GetValue(appName) == null || rk.GetValue(appName).ToString() != exePath)
                    {
                        rk.SetValue(appName, exePath);
                    }
                }
            }
            catch
            {
                // Eğer bir yetki veya kısıtlama sorunu olursa uygulamanın çökmesini engelle
            }
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