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
            Mutex updateMutex = null;
            try
            {
                // Watchdog'un ve diger sureclerin guncelleme sirasinda Kiosk'u yeniden baslatmasini engelle
                updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out _);
            }
            catch { }

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
                await Task.Run(() => PerformUpdate(zipPath, targetFolder, logPath, updateMutex));
                Application.Exit();
            };

            Application.Run(updateForm);
        }

        static void PerformUpdate(string zipPath, string targetFolder, string logPath, Mutex updateMutex)
        {
            string mainExeName = "KioskLockApp.exe";

            try
            {
                // 1. ADIM: WATCHDOG VE ESKI KIOSK'U ZORLA ÖLDÜR
                Process[] watchdogs = Process.GetProcessesByName("WatchdogService");
                foreach (var w in watchdogs) { try { w.Kill(); w.WaitForExit(2000); } catch { } }

                Process[] kiosks = Process.GetProcessesByName("KioskLockApp");
                foreach (var k in kiosks) { try { k.Kill(); k.WaitForExit(2000); } catch { } }

                Thread.Sleep(1000);
                File.AppendAllText(logPath, "Eski surecler durduruldu.\n");

                // 1.5 ADIM: KLASÖRÜ GEÇİCİ OLARAK GÜNCELLEME İÇİN AÇ (KİLİDİ KALDIR)
                UnlockFolder(targetFolder);

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
                    try { File.Delete(zipPath); } catch { }
                    File.AppendAllText(logPath, "Yeni dosyalar sifirdan yuklendi!\n");

                    // Anti-Tamper: Yeni dosyalar yüklendikten sonra klasörü tekrar NTFS silme korumasına al
                    ProtectFolder(targetFolder);
                }

                // 3.5 ADIM: GÜNCELLEME SİNYALİNİ (MUTEX) SERBEST BIRAK
                if (updateMutex != null)
                {
                    try
                    {
                        updateMutex.ReleaseMutex();
                        updateMutex.Dispose();
                        File.AppendAllText(logPath, "Guncelleme kilidi (Mutex) serbest birakildi.\n");
                    }
                    catch { }
                }

                // 4. ADIM: YENİ KIOSK VE WATCHDOG'U AYAĞA KALDIR
                string newExePath = Path.Combine(targetFolder, mainExeName);
                if (File.Exists(newExePath))
                {
                    ProcessStartInfo startInfo = new ProcessStartInfo(newExePath)
                    {
                        UseShellExecute = true,
                        WorkingDirectory = targetFolder
                    };
                    Process.Start(startInfo);
                    File.AppendAllText(logPath, "Yeni Kiosk baslatildi.\n");
                }

                string watchdogExePath = Path.Combine(targetFolder, "WatchdogService.exe");
                if (File.Exists(watchdogExePath))
                {
                    ProcessStartInfo wdInfo = new ProcessStartInfo(watchdogExePath)
                    {
                        UseShellExecute = true,
                        WorkingDirectory = targetFolder
                    };
                    Process.Start(wdInfo);
                    File.AppendAllText(logPath, "Watchdog baslatildi.\n");
                }

                Thread.Sleep(1500);
                File.AppendAllText(logPath, "Operasyon basariyla tamamlandi!\n");
            }
            catch (Exception ex)
            {
                File.AppendAllText(logPath, "HATA: " + ex.Message + "\n");
            }
        }

        private static void UnlockFolder(string dirPath)
        {
            try
            {
                RunHiddenCmd($"icacls \"{dirPath}\" /remove:d *S-1-5-32-545 /T /C /Q");
                RunHiddenCmd($"icacls \"{dirPath}\" /grant *S-1-5-32-544:(OI)(CI)F /T /C /Q");
                RunHiddenCmd($"attrib -s -h \"{dirPath}\"");
            }
            catch { }
        }

        private static void ProtectFolder(string dirPath)
        {
            try
            {
                if (!dirPath.Contains("ProgramData", StringComparison.OrdinalIgnoreCase) &&
                    !dirPath.Contains("AkilliTahtaKilitSistemi", StringComparison.OrdinalIgnoreCase))
                {
                    return;
                }

                try
                {
                    var dirInfo = new DirectoryInfo(dirPath);
                    dirInfo.Attributes |= FileAttributes.Hidden | FileAttributes.System;
                }
                catch { }

                RunHiddenCmd($"icacls \"{dirPath}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");
                RunHiddenCmd($"icacls \"{dirPath}\" /deny *S-1-5-32-545:(DE,DC,WD,AD) /C /Q");

                string mediaDir = Path.Combine(dirPath, "Media");
                if (Directory.Exists(mediaDir))
                {
                    RunHiddenCmd($"icacls \"{mediaDir}\" /grant *S-1-5-32-545:(OI)(CI)M /C /Q");
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
    }
}