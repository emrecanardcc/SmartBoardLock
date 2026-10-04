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

            // ==============================================================
            // 1. ZEKİ KLONLAMA MİMARİSİ (KENDİNİ TEMP'E KOPYALA VE SERBEST BIRAK)
            // ==============================================================
            string currentExe = Application.ExecutablePath;
            string tempExe = Path.Combine(Path.GetTempPath(), "TahtaUpdater_Clone.exe");

            // Eğer şu an ProgramData klasöründeki orijinal dosyadan çalışıyorsak:
            if (!currentExe.Equals(tempExe, StringComparison.OrdinalIgnoreCase))
            {
                try
                {
                    // Kendimizi Windows Temp klasörüne kopyalayalım
                    File.Copy(currentExe, tempExe, true);

                    // Temp'teki klonumuzu aynı argümanlarla (ZIP yolu vs.) başlatalım
                    ProcessStartInfo psi = new ProcessStartInfo(tempExe, $"\"{zipPath}\" \"{targetFolder}\"")
                    {
                        UseShellExecute = true
                    };
                    Process.Start(psi);
                }
                catch { }

                // Orijinal dosyayı anında kapat! Böylece Windows dosyanın kilidini açar ve silinmesine izin verir.
                return;
            }
            // ==============================================================
            // Eğer kod buraya geldiyse, şu an Temp'teki KLON çalışıyor demektir. Operasyona başla!

            string logPath = Path.Combine(Path.GetTempPath(), "updater_log.txt");
            File.WriteAllText(logPath, "Updater Clone basladi...\n");

            // --- MODERN GÜNCELLEME EKRANI ---
            Form updateForm = new Form
            {
                FormBorderStyle = FormBorderStyle.None,
                WindowState = FormWindowState.Maximized,
                BackColor = Color.FromArgb(245, 247, 251),
                TopMost = true,
                ShowInTaskbar = false,
                Cursor = Cursors.WaitCursor
            };

            TableLayoutPanel rootGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 3 };
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            updateForm.Controls.Add(rootGrid);

            Panel card = new Panel { Size = new Size(600, 350), BackColor = Color.White };
            TableLayoutPanel cardContent = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1, Padding = new Padding(40) };
            cardContent.Controls.Add(new Label { Text = "🔄", Font = new Font("Segoe UI", 48), ForeColor = Color.FromArgb(37, 99, 235), AutoSize = true, Anchor = AnchorStyles.None }, 0, 0);
            cardContent.Controls.Add(new Label { Text = "Sınıf360", Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = Color.FromArgb(37, 99, 235), AutoSize = true, Anchor = AnchorStyles.None, Margin = new Padding(0, 10, 0, 10) }, 0, 1);
            cardContent.Controls.Add(new Label { Text = "Sistem Güncelleniyor...", Font = new Font("Segoe UI", 26, FontStyle.Bold), ForeColor = Color.FromArgb(17, 24, 39), AutoSize = true, Anchor = AnchorStyles.None, Margin = new Padding(0, 0, 0, 15) }, 0, 2);
            cardContent.Controls.Add(new Label { Text = "Lütfen akıllı tahtayı kapatmayın.\nYeni versiyon yükleniyor, bu işlem birkaç saniye sürecektir.", Font = new Font("Segoe UI", 13), ForeColor = Color.FromArgb(107, 114, 128), AutoSize = true, TextAlign = ContentAlignment.MiddleCenter, Anchor = AnchorStyles.None }, 0, 3);

            card.Controls.Add(cardContent);
            rootGrid.Controls.Add(card, 1, 1);

            updateForm.Shown += async (s, e) => {
                await Task.Run(() => PerformUpdate(zipPath, targetFolder, logPath));
                Application.Exit();
            };

            Application.Run(updateForm);
        }

        static void PerformUpdate(string zipPath, string targetFolder, string logPath)
        {
            try
            {
                Thread.Sleep(1000); // Orijinal Updater'ın ve Kiosk'un tamamen kapanması için 1 saniye bekle

                // 2. ADIM: WATCHDOG VE KIOSK'U ZORLA ÖLDÜR
                Process[] watchdogs = Process.GetProcessesByName("WatchdogService");
                foreach (var w in watchdogs) { try { w.Kill(); w.WaitForExit(); } catch { } }

                Process[] kiosks = Process.GetProcessesByName("KioskLockApp");
                foreach (var k in kiosks) { try { k.Kill(); k.WaitForExit(); } catch { } }

                File.AppendAllText(logPath, "Eski surecler durduruldu.\n");

                // 3. ADIM: TERTEMİZ SAYFA (SADECE UNINSTALLER DOSYALARINI KORU)
                if (Directory.Exists(targetFolder))
                {
                    foreach (string file in Directory.GetFiles(targetFolder))
                    {
                        string fileName = Path.GetFileName(file);

                        // SADECE Inno Setup'ın unins000.exe ve unins000.dat dosyalarını koru!
                        // Eski TahtaUpdater.exe artık kilitli olmadığı için acımadan silinecek.
                        if (fileName.StartsWith("unins000", StringComparison.OrdinalIgnoreCase))
                            continue;

                        try { File.Delete(file); } catch { }
                    }
                }

                // 4. ADIM: YENİ DOSYALARI ZIP'TEN SIFIRDAN ÇIKART
                if (File.Exists(zipPath))
                {
                    using (ZipArchive archive = ZipFile.OpenRead(zipPath))
                    {
                        foreach (ZipArchiveEntry file in archive.Entries)
                        {
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
                    File.Delete(zipPath); // ZIP'i temizle
                }

                // 5. ADIM: YENİ KIOSK'U AYAĞA KALDIR
                string newExePath = Path.Combine(targetFolder, "KioskLockApp.exe");
                if (File.Exists(newExePath))
                {
                    ProcessStartInfo startInfo = new ProcessStartInfo(newExePath) { UseShellExecute = true, WorkingDirectory = targetFolder };
                    Process.Start(startInfo);
                }
            }
            catch (Exception ex)
            {
                File.AppendAllText(logPath, "HATA: " + ex.Message + "\n");
            }
        }
    }
}