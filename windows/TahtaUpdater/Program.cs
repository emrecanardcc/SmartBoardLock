using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace TahtaUpdater
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            if (args.Length < 2) return;

            string zipPath = args[0].Replace("\"", "");
            string targetFolder = args[1].Replace("\"", "");

            string logPath = Path.Combine(Path.GetTempPath(), "updater_log.txt");
            File.WriteAllText(logPath, "Updater (UI) basladi...\n");
            File.AppendAllText(logPath, $"Hedef Klasör: {targetFolder}\n");

            // --- MODERN GÜNCELLEME EKRANI (FLUENT DESIGN) ---
            Form updateForm = new Form
            {
                FormBorderStyle = FormBorderStyle.None,
                WindowState = FormWindowState.Maximized,
                BackColor = Color.FromArgb(245, 247, 251), // Sınıf360 Açık Gri Arka Plan
                TopMost = true,
                ShowInTaskbar = false,
                Cursor = Cursors.WaitCursor
            };

            // Ekranı 3x3 bölüp ortaya kartı oturtma
            TableLayoutPanel rootGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 3 };
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            updateForm.Controls.Add(rootGrid);

            // Ortadaki Beyaz Kart
            Panel card = new Panel { Size = new Size(600, 350), BackColor = Color.White };

            TableLayoutPanel cardContent = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(40) };
            cardContent.Controls.Add(new Label { Text = "🔄", Font = new Font("Segoe UI", 48), ForeColor = Color.FromArgb(37, 99, 235), AutoSize = true, Anchor = AnchorStyles.None }, 0, 0);
            cardContent.Controls.Add(new Label { Text = "Sınıf360", Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = Color.FromArgb(37, 99, 235), AutoSize = true, Anchor = AnchorStyles.None, Margin = new Padding(0, 10, 0, 10) }, 0, 1);
            cardContent.Controls.Add(new Label { Text = "Sistem Güncelleniyor...", Font = new Font("Segoe UI", 26, FontStyle.Bold), ForeColor = Color.FromArgb(17, 24, 39), AutoSize = true, Anchor = AnchorStyles.None, Margin = new Padding(0, 0, 0, 15) }, 0, 2);
            cardContent.Controls.Add(new Label { Text = "Lütfen akıllı tahtayı kapatmayın.\nYeni versiyon yükleniyor, bu işlem birkaç saniye sürecektir.", Font = new Font("Segoe UI", 13), ForeColor = Color.FromArgb(107, 114, 128), AutoSize = true, TextAlign = ContentAlignment.MiddleCenter, Anchor = AnchorStyles.None }, 0, 3);

            card.Controls.Add(cardContent);
            rootGrid.Controls.Add(card, 1, 1);

            // Ekran yüklendiğinde arka planda çıkarma işlemine başla
            updateForm.Shown += async (s, e) => {
                await Task.Run(() => PerformUpdate(zipPath, targetFolder, logPath));
                Application.Exit();
            };

            Application.Run(updateForm);
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

                Thread.Sleep(1000);
                File.AppendAllText(logPath, "Eski surecler durduruldu.\n");

                // 2. ADIM: TERTEMİZ SAYFA (KLASÖRÜN İÇİNİ KOMPLE SİL - UPDATER HARİÇ)
                if (Directory.Exists(targetFolder))
                {
                    foreach (string file in Directory.GetFiles(targetFolder))
                    {
                        if (Path.GetFileName(file).StartsWith("TahtaUpdater", StringComparison.OrdinalIgnoreCase))
                            continue;

                        try { File.Delete(file); } catch { }
                    }
                    File.AppendAllText(logPath, "Eski dosyalar tamamen temizlendi (Sifirlandi).\n");
                }

                // 3. ADIM: YENİ DOSYALARI ZIP'TEN SIFIRDAN ÇIKART
                if (File.Exists(zipPath))
                {
                    using (ZipArchive archive = ZipFile.OpenRead(zipPath))
                    {
                        foreach (ZipArchiveEntry file in archive.Entries)
                        {
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
                    File.Delete(zipPath);
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