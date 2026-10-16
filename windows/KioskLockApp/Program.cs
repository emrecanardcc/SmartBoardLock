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
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Bekleyen güncellemeleri (.new dosyaları) uygula
            ApplyPendingUpdates();

            // Windows başlar başlamaz çalışması için Kayıt Defterine kanca atıyoruz
            ForceStartup();

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
            catch
            {
                // Okuma hatası olursa boş kabul et
            }

            // Eğer boardId yoksa (veya boşsa) kurulum/eşleşme ekranını aç
            if (string.IsNullOrEmpty(boardId))
            {
                Application.Run(new PairingScreen());
            }
            else
            {
                // =========================================================================
                // LİSANS DOĞRULAMA & SESSİZ KAPANMA KONTROLÜ
                // =========================================================================
                // Eğer okulun lisansı yoksa, pasife alınmışsa veya süresi dolmuşsa:
                // Tahta ekranı ASLA kilitlenmez, arka planda hiçbir işlem çalışmaz,
                // uygulama tamamen sessizce anında sonlanır (Environment.Exit(0)).
                // =========================================================================
                bool isLicensed = true;
                try
                {
                    var licenseTask = SecureSupabase.CheckLicenseStatusAsync(boardId);
                    if (licenseTask.Wait(3000))
                    {
                        isLicensed = licenseTask.Result;
                    }
                    else
                    {
                        isLicensed = SecureSupabase.GetCachedLicenseStatus();
                    }
                }
                catch
                {
                    isLicensed = SecureSupabase.GetCachedLicenseStatus();
                }

                if (!isLicensed)
                {
                    // Lisans geçersiz veya bitmiş: Sessizce sonlandır
                    Environment.Exit(0);
                    return;
                }

                // Lisans aktif: Kilit ekranını ve donanım korumasını başlat
                Application.Run(new SecureRenderer());
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
            }
            catch { }
        }
    }
}