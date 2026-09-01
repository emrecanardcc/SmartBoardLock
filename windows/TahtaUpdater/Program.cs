using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms; // Windows Forms tam yetkiyle çağrıldı

namespace TahtaUpdater
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // ÇAKIŞMAYI ÖNLEMEK İÇİN NET ADRES KULLANIYORUZ
            System.Windows.Forms.Application.EnableVisualStyles();
            System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false);

            if (args.Length < 2) return;

            string zipPath = args[0].Replace("\"", "");
            string targetFolder = args[1].Replace("\"", "");

            string logPath = Path.Combine(Path.GetTempPath(), "updater_log.txt");
            File.WriteAllText(logPath, "Updater (UI) basladi...\n");
            File.AppendAllText(logPath, $"Hedef Klasör: {targetFolder}\n");

            // 1. TAM EKRAN SİYAH KİLİT EKRANI OLUŞTURULUYOR
            System.Windows.Forms.Form updateForm = new System.Windows.Forms.Form();
            updateForm.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None;
            updateForm.WindowState = System.Windows.Forms.FormWindowState.Maximized;
            updateForm.BackColor = Color.Black;
            updateForm.TopMost = true;
            updateForm.ShowInTaskbar = false;
            updateForm.Cursor = System.Windows.Forms.Cursors.WaitCursor;

            System.Windows.Forms.Label lblInfo = new System.Windows.Forms.Label();
            lblInfo.Text = "SİSTEM GÜNCELLENİYOR...\nLütfen tahtayı kapatmayın.";
            lblInfo.ForeColor = Color.White;
            lblInfo.Font = new Font("Arial", 36, FontStyle.Bold);
            lblInfo.TextAlign = ContentAlignment.MiddleCenter;
            lblInfo.Dock = DockStyle.Fill;
            updateForm.Controls.Add(lblInfo);

            // 2. EKRAN GÖRÜNDÜĞÜ AN ARKA PLANDA ÇIKARMA İŞLEMİNİ BAŞLAT
            updateForm.Shown += async (s, e) => {
                await Task.Run(() => PerformUpdate(zipPath, targetFolder, logPath));
                System.Windows.Forms.Application.Exit(); // İşlem bitince ekranı kapat
            };

            System.Windows.Forms.Application.Run(updateForm);
        }

       static void PerformUpdate(string zipPath, string targetFolder, string logPath)
        {
            string mainExeName = "KioskLockApp.exe";

            try
            {
                // 1. ADIM: WATCHDOG VE ESKI KIOSK'U ZORLA ÖLDÜR
                Process[] watchdogs = Process.GetProcessesByName("WatchdogService");
                foreach (var w in watchdogs) { w.Kill(); w.WaitForExit(); }

                Process[] kiosks = Process.GetProcessesByName("KioskLockApp");
                foreach (var k in kiosks) { k.Kill(); k.WaitForExit(); }

                Thread.Sleep(1000); // 1 saniye nefes al
                File.AppendAllText(logPath, "Eski surecler durduruldu.\n");

                // 2. ADIM: TERTEMİZ SAYFA (KLASÖRÜN İÇİNİ KOMPLE SİL - UPDATER HARİÇ)
                // Bu sayede eski çöpler, kalıntı dosyalar tamamen temizlenir!
                if (Directory.Exists(targetFolder))
                {
                    foreach (string file in Directory.GetFiles(targetFolder))
                    {
                        // Updater kendi dosyasını silemez (çünkü şu an çalışıyor), onu es geçiyoruz
                        if (Path.GetFileName(file).StartsWith("TahtaUpdater", StringComparison.OrdinalIgnoreCase))
                            continue;

                        try { File.Delete(file); } catch { }
                    }
                    File.AppendAllText(logPath, "Eski dosyalar tamamen temizlendi (Sifirlandi).\n");
                }

                // 3. ADIM: YENİ DOSYALARI ZIP'TEN SIFIRDAN ÇIKart
                if (File.Exists(zipPath))
                {
                    using (ZipArchive archive = ZipFile.OpenRead(zipPath))
                    {
                        foreach (ZipArchiveEntry file in archive.Entries)
                        {
                            // Zip'in içinde updater varsa onu da es geçebiliriz
                            if (file.Name.StartsWith("TahtaUpdater", StringComparison.OrdinalIgnoreCase))
                                continue;

                            string completeFileName = Path.Combine(targetFolder, file.FullName);
                            string directory = Path.GetDirectoryName(completeFileName);
                            
                            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory)) 
                                Directory.CreateDirectory(directory);

                            if (!string.IsNullOrEmpty(file.Name))
                            {
                                file.ExtractToFile(completeFileName, true);
                            }
                        }
                    }
                    File.Delete(zipPath); // Zip çöpünü temizle
                    File.AppendAllText(logPath, "Yeni dosyalar sifirdan yuklendi!\n");
                }

                // 4. ADIM: YENİ KIOSK'U AYAĞA KALDIR
                string newExePath = Path.Combine(targetFolder, mainExeName);
                if (File.Exists(newExePath))
                {
                    ProcessStartInfo startInfo = new ProcessStartInfo(newExePath) { UseShellExecute = true, WorkingDirectory = targetFolder };
                    Process.Start(startInfo);
                    File.AppendAllText(logPath, "Yeni Kiosk baslatildi. Operasyon basarili!\n");
                }
            }
            catch (Exception ex)
            {
                File.AppendAllText(logPath, "HATA: " + ex.Message + "\n");
            }
        }
    }
}