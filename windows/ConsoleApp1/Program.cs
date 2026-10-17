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
            string debugLog = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "watchdog_debug.log");
            System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Watchdog started\n");

            // Bekçinin arkada sadece tek bir örnek olarak çalışmasını garanti ediyoruz
            using (Mutex mutex = new Mutex(true, "AkilliTahtaWatchdogMutex", out bool createdNew))
            {
                System.IO.File.AppendAllText(debugLog, $"[{DateTime.UtcNow}] Mutex createdNew: {createdNew}\n");
                if (!createdNew) return; // Zaten çalışıyorsa ikinci bir bekçi açma
                StartWatchdogLoop();
            }
        }

        private static void StartWatchdogLoop()
        {
            string rkName = "AkilliTahtaKilitSistemi";
            string targetProcessName = "KioskLockApp"; // İzlenecek ana kilit uygulaması
            System.Collections.Generic.List<DateTime> crashTimestamps = new System.Collections.Generic.List<DateTime>();
            bool wasRunning = false;

            while (true)
            {
                try
                {
                    // ==========================================
                    // GÜNCELLEME VEYA ONARIM KONTROLÜ
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

                    // KioskLockApp sürecinin çalışıp çalışmadığını kontrol et
                    Process[] processes = Process.GetProcessesByName(targetProcessName);

                    if (processes.Length > 0)
                    {
                        wasRunning = true;
                    }
                    else
                    {
                        // Süreç çalışmıyor!

                        // =========================================================================
                        // LİSANS GEÇERLİLİK KONTROLÜ
                        // =========================================================================
                        // Eğer okulun lisansı yoksa, devre dışıysa veya süresi dolmuşsa:
                        // Bekçi KioskLockApp'i ASLA çalıştırmaz, sessizce bekler.
                        // =========================================================================
                        string isLicensed = "1";
                        string licenseExpiresAt = "";
                        try
                        {
                            using (RegistryKey? rkLock = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock", false))
                            {
                                if (rkLock != null)
                                {
                                    isLicensed = rkLock.GetValue("IsLicensed")?.ToString()?.Trim() ?? "1";
                                    licenseExpiresAt = rkLock.GetValue("LicenseExpiresAt")?.ToString()?.Trim() ?? "";
                                }
                            }
                        }
                        catch { }

                        if (isLicensed == "0")
                        {
                            Thread.Sleep(5000);
                            continue;
                        }

                        if (!string.IsNullOrEmpty(licenseExpiresAt) && DateTime.TryParse(licenseExpiresAt, out DateTime expDate))
                        {
                            if (DateTime.UtcNow > expDate.ToUniversalTime())
                            {
                                Thread.Sleep(5000);
                                continue;
                            }
                        }

                        // Kayıt Defterinden (Registry) kurulu olduğu yolu oku
                        string kioskExePath = "";
                        using (RegistryKey? rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                        {
                            if (rk != null)
                            {
                                object? regValue = rk.GetValue(rkName);
                                if (regValue != null)
                                {
                                    kioskExePath = regValue.ToString() ?? "";
                                }
                            }
                        }

                        if (!string.IsNullOrEmpty(kioskExePath))
                        {
                            string appDir = System.IO.Path.GetDirectoryName(kioskExePath) ?? "";

                            // Eğer daha önce çalışıyorduysa ve şimdi kapandıysa -> Çökme tespiti
                            if (wasRunning)
                            {
                                wasRunning = false;
                                crashTimestamps.RemoveAll(t => (DateTime.UtcNow - t).TotalSeconds > 60);
                                crashTimestamps.Add(DateTime.UtcNow);

                                // 60 saniyede 3 veya daha fazla çökme olduysa OTOMATİK KURTARMA (TahtaRepair)
                                if (crashTimestamps.Count >= 3)
                                {
                                    string repairExe = System.IO.Path.Combine(appDir, "TahtaRepair.exe");
                                    if (!System.IO.File.Exists(repairExe))
                                    {
                                        repairExe = @"C:\ProgramData\AkilliTahtaKilitSistemi\TahtaRepair.exe";
                                    }

                                    if (System.IO.File.Exists(repairExe))
                                    {
                                        ProcessStartInfo repairInfo = new ProcessStartInfo(repairExe, "--auto-recovery")
                                        {
                                            UseShellExecute = true,
                                            WorkingDirectory = System.IO.Path.GetDirectoryName(repairExe)
                                        };
                                        Process.Start(repairInfo);
                                        crashTimestamps.Clear();
                                        Thread.Sleep(5000); // TahtaRepair'in mutex almasını bekle
                                        continue;
                                    }
                                }
                            }

                            // Normal yeniden başlatma
                            if (System.IO.File.Exists(kioskExePath))
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