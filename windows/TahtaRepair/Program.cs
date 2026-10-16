using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace TahtaRepair
{
    static class Program
    {
        public const string SUPABASE_URL = "https://clkasnbpmhddhstoixdz.supabase.co";
        public const string SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

        private static string logPath = Path.Combine(Path.GetTempPath(), "tahta_repair_log.txt");

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            Log("==========================================");
            Log($"TahtaRepair Başlatıldı: {DateTime.Now}");
            Log($"Argümanlar: {string.Join(" ", args)}");

            // Watchdog'un araya girmesini engellemek için Global Mutex'i al
            using (Mutex updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out bool createdNew))
            {
                // Hedef kurulum klasörünü belirle
                string targetFolder = DetermineTargetFolder(args);
                Log($"Hedef Uygulama Klasörü: {targetFolder}");

                // Modern Tam Ekran Kurtarma Penceresini Aç
                RepairForm repairForm = new RepairForm(targetFolder);
                Application.Run(repairForm);
            }
        }

        private static string DetermineTargetFolder(string[] args)
        {
            // 1. Argüman olarak verilmiş mi?
            foreach (var arg in args)
            {
                if (!arg.StartsWith("-") && Directory.Exists(arg))
                {
                    return arg;
                }
            }

            // 2. ProgramData altındaki standart kurulum dizini var mı?
            string programDataDir = @"C:\ProgramData\AkilliTahtaKilitSistemi";
            if (Directory.Exists(programDataDir))
            {
                return programDataDir;
            }

            // 3. Registry'den oku
            try
            {
                using (RegistryKey? rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                {
                    if (rk != null)
                    {
                        object? regVal = rk.GetValue("AkilliTahtaKilitSistemi");
                        if (regVal != null)
                        {
                            string? dir = Path.GetDirectoryName(regVal.ToString());
                            if (!string.IsNullOrEmpty(dir) && Directory.Exists(dir))
                                return dir;
                        }
                    }
                }
            }
            catch { }

            // 4. Exe'nin çalıştığı dizin
            return AppDomain.CurrentDomain.BaseDirectory;
        }

        public static void Log(string message)
        {
            try
            {
                File.AppendAllText(logPath, $"[{DateTime.Now:HH:mm:ss}] {message}\n");
                Debug.WriteLine(message);
            }
            catch { }
        }
    }

    public class RepairForm : Form
    {
        private readonly string targetFolder;
        private Label lblStatus = null!;
        private ProgressBar progressBar = null!;
        private Label lblDetail = null!;
        private Button btnClose = null!;

        public RepairForm(string targetFolder)
        {
            this.targetFolder = targetFolder;

            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251);
            this.TopMost = true;
            this.ShowInTaskbar = false;
            this.Cursor = Cursors.WaitCursor;

            BuildUI();

            this.Shown += async (s, e) =>
            {
                await RunRepairProcessAsync();
            };
        }

        private void BuildUI()
        {
            TableLayoutPanel rootGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 3 };
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            this.Controls.Add(rootGrid);

            Panel card = new Panel
            {
                Size = new Size(650, 420),
                BackColor = Color.White
            };
            card.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(Color.FromArgb(229, 231, 235), 1.5f))
                {
                    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                    e.Graphics.DrawRectangle(pen, 0, 0, card.Width - 1, card.Height - 1);
                }
            };

            TableLayoutPanel cardLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 6,
                ColumnCount = 1,
                Padding = new Padding(35)
            };
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 70)); // İkon
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 30)); // Logo Sınıf360
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 45)); // Başlık
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 55)); // Açıklama
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 40)); // Progress
            cardLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F)); // Durum & Buton

            Label lblIcon = new Label
            {
                Text = "🛠️",
                Font = new Font("Segoe UI", 44),
                AutoSize = true,
                Anchor = AnchorStyles.None
            };

            Label lblBrand = new Label
            {
                Text = "Sınıf360 • Sistem Kurtarma & Onarım",
                Font = new Font("Segoe UI", 12, FontStyle.Bold),
                ForeColor = Color.FromArgb(37, 99, 235),
                AutoSize = true,
                Anchor = AnchorStyles.None
            };

            Label lblTitle = new Label
            {
                Text = "Uygulama Bütünlüğü Onarılıyor",
                Font = new Font("Segoe UI", 22, FontStyle.Bold),
                ForeColor = Color.FromArgb(17, 24, 39),
                AutoSize = true,
                Anchor = AnchorStyles.None
            };

            lblDetail = new Label
            {
                Text = "En son sürüm dosyaları sıfırdan indirilip doğrulanıyor.\nEşleştirme ve okul ayarlarınız korunmaktadır. Lütfen bekleyin...",
                Font = new Font("Segoe UI", 11),
                ForeColor = Color.FromArgb(107, 114, 128),
                AutoSize = true,
                TextAlign = ContentAlignment.MiddleCenter,
                Anchor = AnchorStyles.None
            };

            progressBar = new ProgressBar
            {
                Dock = DockStyle.Fill,
                Style = ProgressBarStyle.Marquee,
                MarqueeAnimationSpeed = 30
            };

            TableLayoutPanel pnlBottom = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 2,
                ColumnCount = 1
            };
            pnlBottom.RowStyles.Add(new RowStyle(SizeType.Percent, 60F));
            pnlBottom.RowStyles.Add(new RowStyle(SizeType.Percent, 40F));

            lblStatus = new Label
            {
                Text = "İşlem başlatılıyor...",
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                ForeColor = Color.FromArgb(37, 99, 235),
                AutoSize = true,
                Anchor = AnchorStyles.None
            };

            btnClose = new Button
            {
                Text = "Kapat ve Başlat",
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Size = new Size(160, 36),
                Visible = false,
                Anchor = AnchorStyles.None,
                BackColor = Color.FromArgb(37, 99, 235),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };
            btnClose.FlatAppearance.BorderSize = 0;
            btnClose.Click += (s, e) => Application.Exit();

            pnlBottom.Controls.Add(lblStatus, 0, 0);
            pnlBottom.Controls.Add(btnClose, 0, 1);

            cardLayout.Controls.Add(lblIcon, 0, 0);
            cardLayout.Controls.Add(lblBrand, 0, 1);
            cardLayout.Controls.Add(lblTitle, 0, 2);
            cardLayout.Controls.Add(lblDetail, 0, 3);
            cardLayout.Controls.Add(progressBar, 0, 4);
            cardLayout.Controls.Add(pnlBottom, 0, 5);

            card.Controls.Add(cardLayout);
            rootGrid.Controls.Add(card, 1, 1);
        }

        private void UpdateStatus(string message, int progress = -1)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => UpdateStatus(message, progress)));
                return;
            }

            lblStatus.Text = message;
            Program.Log(message);

            if (progress >= 0 && progress <= 100)
            {
                progressBar.Style = ProgressBarStyle.Continuous;
                progressBar.Value = progress;
            }
            else
            {
                progressBar.Style = ProgressBarStyle.Marquee;
            }
        }

        private async Task RunRepairProcessAsync()
        {
            try
            {
                // 1. ADIM: ÇALIŞAN UYGULAMA SÜREÇLERİNİ DURDUR
                UpdateStatus("Çalışan servisler ve kilit ekranı durduruluyor...", 10);
                StopProcess("KioskLockApp");
                StopProcess("WatchdogService");
                StopProcess("TahtaUpdater");
                await Task.Delay(1000);

                // 2. ADIM: SUPABASE'DEN EN GÜNCEL PAKET BİLGİSİNİ AL
                UpdateStatus("Veritabanından en son sürüm bilgisi alınıyor...", 20);
                var (downloadUrl, version) = await FetchLatestAppVersionAsync();

                if (string.IsNullOrEmpty(downloadUrl))
                {
                    throw new Exception("En güncel sürüm için indirme bağlantısı veritabanında bulunamadı!");
                }

                UpdateStatus($"En güncel paket bulundu: v{version}. İndirme başlatılıyor...", 30);

                // 3. ADIM: DOSYAYI İNDİR
                string tempZipPath = Path.Combine(Path.GetTempPath(), $"TahtaRepair_Package_{version}.zip");
                await DownloadPackageWithProgressAsync(downloadUrl, tempZipPath);

                // 4. ADIM: HEDEF KLASÖRDEKİ DOSYALARI SİL (KENDİSİ HARİÇ!)
                UpdateStatus("Eski ve bozuk uygulama dosyaları temizleniyor...", 65);
                CleanTargetFolderExceptSelf(targetFolder);

                // 5. ADIM: YENİ DOSYALARI SIFIRDAN ÇIKART
                UpdateStatus("Yeni dosyalar eksiksiz olarak kuruluyor...", 75);
                ExtractZipPackage(tempZipPath, targetFolder);

                // 6. ADIM: BÜTÜNLÜK DOĞRULAMA (INTEGRITY CHECK)
                UpdateStatus("Uygulama bütünlüğü doğrulanıyor...", 90);
                VerifyInstalledIntegrity(targetFolder);

                // Geçici zip'i sil
                try { if (File.Exists(tempZipPath)) File.Delete(tempZipPath); } catch { }

                // 7. ADIM: YENİ UYGULAMALARI BAŞLAT
                UpdateStatus("Onarım tamamlandı! Sistem yeniden başlatılıyor...", 100);
                await Task.Delay(1500);

                StartApp(Path.Combine(targetFolder, "WatchdogService.exe"), targetFolder);
                StartApp(Path.Combine(targetFolder, "KioskLockApp.exe"), targetFolder);

                await Task.Delay(1000);
                Application.Exit();
            }
            catch (Exception ex)
            {
                Program.Log($"KRİTİK HATA: {ex.Message}");
                if (this.InvokeRequired)
                {
                    this.Invoke(new Action(() => ShowErrorState(ex.Message)));
                }
                else
                {
                    ShowErrorState(ex.Message);
                }
            }
        }

        private void ShowErrorState(string error)
        {
            this.Cursor = Cursors.Default;
            progressBar.Visible = false;
            lblStatus.ForeColor = Color.FromArgb(220, 38, 38);
            lblStatus.Text = "Onarım Sırasında Hata Oluştu!";
            lblDetail.Text = $"Detay: {error}\n\nLütfen internet bağlantınızı kontrol edip tekrar deneyin.";
            btnClose.Visible = true;
        }

        private void StopProcess(string procName)
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(procName))
                {
                    try
                    {
                        p.Kill();
                        p.WaitForExit(3000);
                    }
                    catch { }
                }
                Program.Log($"Süreç durduruldu: {procName}");
            }
            catch { }
        }

        private async Task<(string downloadUrl, string version)> FetchLatestAppVersionAsync()
        {
            using (HttpClient client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) })
            {
                client.DefaultRequestHeaders.Add("apikey", Program.SUPABASE_KEY);
                client.DefaultRequestHeaders.Add("Authorization", $"Bearer {Program.SUPABASE_KEY}");

                string url = $"{Program.SUPABASE_URL}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1";
                string json = await client.GetStringAsync(url);

                using (JsonDocument doc = JsonDocument.Parse(json))
                {
                    var root = doc.RootElement;
                    if (root.ValueKind == JsonValueKind.Array && root.GetArrayLength() > 0)
                    {
                        var first = root[0];
                        string ver = first.GetProperty("version_number").GetString() ?? "unknown";
                        string dl = first.GetProperty("download_url").GetString() ?? "";
                        return (dl, ver);
                    }
                }
            }
            return (string.Empty, string.Empty);
        }

        private async Task DownloadPackageWithProgressAsync(string downloadUrl, string destinationPath)
        {
            using (HttpClient client = new HttpClient { Timeout = TimeSpan.FromMinutes(5) })
            using (var response = await client.GetAsync(downloadUrl, HttpCompletionOption.ResponseHeadersRead))
            {
                response.EnsureSuccessStatusCode();
                long? totalBytes = response.Content.Headers.ContentLength;

                using (var contentStream = await response.Content.ReadAsStreamAsync())
                using (var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true))
                {
                    byte[] buffer = new byte[16384];
                    long totalRead = 0;
                    int bytesRead;

                    while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                    {
                        await fileStream.WriteAsync(buffer, 0, bytesRead);
                        totalRead += bytesRead;

                        if (totalBytes.HasValue && totalBytes.Value > 0)
                        {
                            int pct = (int)((totalRead * 30) / totalBytes.Value) + 30; // 30% - 60% aralığı
                            UpdateStatus($"Paket indiriliyor: {totalRead / 1024 / 1024} MB / {totalBytes.Value / 1024 / 1024} MB (%{pct})", pct);
                        }
                    }
                }
            }
            Program.Log($"İndirme tamamlandı: {destinationPath}");
        }

        private void CleanTargetFolderExceptSelf(string folder)
        {
            if (!Directory.Exists(folder))
            {
                Directory.CreateDirectory(folder);
                return;
            }

            string currentExeName = Path.GetFileName(Environment.ProcessPath ?? "TahtaRepair.exe");

            foreach (string file in Directory.GetFiles(folder, "*", SearchOption.TopDirectoryOnly))
            {
                string fName = Path.GetFileName(file);

                // KENDİSİ HARİÇ: TahtaRepair ile başlayan dosyaları silme
                if (fName.StartsWith("TahtaRepair", StringComparison.OrdinalIgnoreCase) ||
                    fName.Equals(currentExeName, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try
                {
                    File.SetAttributes(file, FileAttributes.Normal);
                    File.Delete(file);
                }
                catch (Exception ex)
                {
                    Program.Log($"Dosya silinemedi (atlanıyor): {fName} - {ex.Message}");
                }
            }

            Program.Log("Hedef klasördeki eski dosyalar temizlendi.");
        }

        private void ExtractZipPackage(string zipPath, string folder)
        {
            using (ZipArchive archive = ZipFile.OpenRead(zipPath))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    // Boş klasör girdilerini atla
                    if (string.IsNullOrEmpty(entry.Name)) continue;

                    string destFileName = Path.Combine(folder, entry.FullName);
                    string? dir = Path.GetDirectoryName(destFileName);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                    }

                    // Eğer zip içindeki dosya TahtaRepair.exe ise:
                    // Çalışan dosya kilitli olduğu için TahtaRepair.exe.new olarak çıkart!
                    if (entry.Name.Equals("TahtaRepair.exe", StringComparison.OrdinalIgnoreCase))
                    {
                        string newRepairPath = Path.Combine(folder, "TahtaRepair.exe.new");
                        entry.ExtractToFile(newRepairPath, true);
                        Program.Log("Yeni TahtaRepair.exe.new olarak çıkartıldı.");
                        continue;
                    }

                    try
                    {
                        if (File.Exists(destFileName))
                        {
                            File.SetAttributes(destFileName, FileAttributes.Normal);
                        }
                        entry.ExtractToFile(destFileName, true);
                    }
                    catch (Exception ex)
                    {
                        Program.Log($"Dosya çıkarma hatası: {entry.FullName} - {ex.Message}");
                    }
                }
            }
            Program.Log("Yeni dosyalar sıfırdan başarıyla çıkartıldı.");
        }

        private void VerifyInstalledIntegrity(string folder)
        {
            string kioskPath = Path.Combine(folder, "KioskLockApp.exe");
            if (!File.Exists(kioskPath))
            {
                throw new Exception("Bütünlük Hatası: KioskLockApp.exe bulunamadı!");
            }

            FileInfo fi = new FileInfo(kioskPath);
            if (fi.Length < 1024)
            {
                throw new Exception("Bütünlük Hatası: KioskLockApp.exe boyutu geçersiz (bozuk dosya)!");
            }

            Program.Log($"Bütünlük doğrulandı: KioskLockApp.exe ({fi.Length} bytes)");
        }

        private void StartApp(string exePath, string workingDir)
        {
            if (File.Exists(exePath))
            {
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo(exePath)
                    {
                        UseShellExecute = true,
                        WorkingDirectory = workingDir
                    };
                    Process.Start(psi);
                    Program.Log($"Başlatıldı: {exePath}");
                }
                catch (Exception ex)
                {
                    Program.Log($"Başlatma hatası ({exePath}): {ex.Message}");
                }
            }
        }
    }
}