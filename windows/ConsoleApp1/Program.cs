using System;
using System.Diagnostics;
using System.Threading;
using Microsoft.Win32;

namespace WatchdogService
{
    internal class Program
    {
        static void Main(string[] args)
        {
            // Bekçinin arkada sadece tek bir örnek olarak çalışmasını garanti ediyoruz
            using (Mutex mutex = new Mutex(true, "AkilliTahtaWatchdogMutex", out bool createdNew))
            {
                if (!createdNew) return; // Zaten çalışıyorsa ikinci bir bekçi açma
                StartWatchdogLoop();
            }
        }

        private static void StartWatchdogLoop()
        {
            string rkName = "AkilliTahtaKilitSistemi";
            string targetProcessName = "KioskLockApp"; // İzlenecek ana kilit uygulaması

            while (true)
            {
                try
                {
                    // ==========================================
                    // YENİ EKLENEN KISIM: GÜNCELLEME KONTROLÜ
                    // ==========================================
                    // İşletim sisteminde "Global\TahtaGuncelleniyor" adında bir sinyal var mı bakıyoruz
                    bool isUpdateRunning = Mutex.TryOpenExisting(@"Global\TahtaGuncelleniyor", out _);

                    if (isUpdateRunning)
                    {
                        // Sinyal var! Demek ki KioskLockApp arka planda güncelleniyor.
                        // Kiosk'u geri açmaya ÇALIŞMA, 2 saniye bekle ve döngüyü başa sar.
                        Thread.Sleep(2000);
                        continue;
                    }
                    // ==========================================

                    // KioskLockApp sürecinin çalışıp çalışmadığını kontrol et
                    Process[] processes = Process.GetProcessesByName(targetProcessName);

                    if (processes.Length == 0)
                    {
                        // Eğer süreç kapatıldıysa Kayıt Defterinden (Registry) kurulu olduğu yolu oku
                        RegistryKey rk = Registry.CurrentUser.OpenSubKey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", false);

                        if (rk != null)
                        {
                            object regValue = rk.GetValue(rkName);
                            if (regValue != null)
                            {
                                string kioskExePath = regValue.ToString();

                                // Uygulamayı kendi klasör bağlamıyla (Pencere izinleri dahil) yeniden tetikle
                                ProcessStartInfo startInfo = new ProcessStartInfo(kioskExePath)
                                {
                                    UseShellExecute = true,
                                    WorkingDirectory = System.IO.Path.GetDirectoryName(kioskExePath) // Yol karmaşasını önleyen kritik ayar
                                };

                                Process.Start(startInfo);
                            }
                        }
                    }
                }
                catch
                {
                    // Herhangi bir Windows iznine veya dosya krizine takılırsa bekçinin çökmesini engelle
                }

                // 300 milisaniyede bir (göz açıp kapayıncaya kadar) kontrolü tekrarla
                Thread.Sleep(300);
            }
        }
    }
}