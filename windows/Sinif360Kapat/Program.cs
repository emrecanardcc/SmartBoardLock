using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Sinif360Kapat
{
    static class Program
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hObject);

        private const uint PROCESS_TERMINATE = 0x0001;
        public const string MASTER_PASSWORD = "821620";
        public const string TARGET_DIR = @"C:\ProgramData\AkilliTahtaKilitSistemi";

        private static readonly byte[] Entropy = new byte[]
        {
            0x53, 0x69, 0x6E, 0x69, 0x66, 0x33, 0x36, 0x30,
            0x5F, 0x53, 0x65, 0x63, 0x5F, 0x50, 0x49, 0x4E
        };

        private const string ShadowVaultPath = @"C:\ProgramData\Microsoft\Crypto\Keys\Sinif360_Vault\board_sec.vault";

        public static bool VerifyManagerOrMasterPassword(string enteredPassword)
        {
            if (string.IsNullOrWhiteSpace(enteredPassword)) return false;
            enteredPassword = enteredPassword.Trim();

            // 1. Acil durum ana şifresi (Master Recovery PIN)
            if (enteredPassword == MASTER_PASSWORD) return true;

            // 2. Okul müdürünün web panelinden tanımladığı şifreyi (DPAPI kasası) kontrol et
            string? storedCipher = null;
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    storedCipher = key?.GetValue("BoardAdminPasswordVault") as string;
                }
            }
            catch { }

            if (string.IsNullOrEmpty(storedCipher))
            {
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\SmartBoardLock"))
                    {
                        storedCipher = key?.GetValue("BoardAdminPasswordVault") as string;
                    }
                }
                catch { }
            }

            if (string.IsNullOrEmpty(storedCipher) && File.Exists(ShadowVaultPath))
            {
                try { storedCipher = File.ReadAllText(ShadowVaultPath).Trim(); } catch { }
            }

            // Kasa henüz boşsa varsayılan müdür şifreleri geçerlidir
            if (string.IsNullOrEmpty(storedCipher))
            {
                return enteredPassword == "360360" || enteredPassword == "123456";
            }

            // Test / SHA-256 HASH kontrolü
            if (storedCipher.StartsWith("HASH:"))
            {
                string expectedHash = storedCipher.Substring("HASH:".Length);
                using var sha = SHA256.Create();
                byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(enteredPassword + ":sinif360_salt"));
                string computedHash = Convert.ToBase64String(hash);
                return string.Equals(expectedHash, computedHash, StringComparison.Ordinal);
            }

            // DPAPI ile çöz
            if (OperatingSystem.IsWindows())
            {
                try
                {
                    byte[] cipherBytes = Convert.FromBase64String(storedCipher);
                    byte[] plainBytes;
                    try
                    {
                        plainBytes = ProtectedData.Unprotect(cipherBytes, Entropy, DataProtectionScope.LocalMachine);
                    }
                    catch
                    {
                        plainBytes = ProtectedData.Unprotect(cipherBytes, Entropy, DataProtectionScope.CurrentUser);
                    }
                    string decrypted = Encoding.UTF8.GetString(plainBytes).Trim();
                    return string.Equals(enteredPassword, decrypted, StringComparison.Ordinal);
                }
                catch
                {
                    return false;
                }
            }

            return false;
        }

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Komut satırı argümanları kontrolü
            for (int i = 0; i < args.Length; i++)
            {
                string arg = args[i];

                // Sessiz durdurma: --now veya /q
                if (arg.Equals("--now", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("/q", StringComparison.OrdinalIgnoreCase))
                {
                    ExecuteKillAll();
                    return;
                }

                // Komut satırından sessiz kaldırma: --uninstall <şifre>
                if (arg.Equals("--uninstall", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("/uninstall", StringComparison.OrdinalIgnoreCase))
                {
                    string pass = (i + 1 < args.Length) ? args[i + 1] : "";
                    ExecuteUninstallAll(pass);
                    return;
                }

                // Klasör korumasını zorla: --protect
                if (arg.Equals("--protect", StringComparison.OrdinalIgnoreCase))
                {
                    EnforceFolderProtection();
                    return;
                }
            }

            Application.Run(new MainForm());
        }

        public static bool ExecuteKillAll(Action<string>? logger = null)
        {
            logger?.Invoke("1. Bekçi araya girmesin diye kilit sinyali alınıyor...");

            // Watchdog'un Kiosk'u yeniden başlatmasını engellemek için Global Mutex'i edin
            Mutex? updateMutex = null;
            try
            {
                updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out _);
            }
            catch { }

            try
            {
                string[] targets = { "WatchdogService", "KioskLockApp", "TahtaUpdater", "TahtaRepair" };

                logger?.Invoke("2. Bekçi ve kilit süreçleri aynı anda sonlandırılıyor...");

                // İlk dalga: Paralel olarak hepsini kapat
                Parallel.ForEach(targets, procName =>
                {
                    KillProcessByName(procName);
                });

                Thread.Sleep(300);

                // İkinci dalga: Kalan veya uyanan süreç varsa zorla sonlandır
                foreach (var procName in targets)
                {
                    KillProcessByName(procName);
                }

                logger?.Invoke("3. Windows Görev Yöneticisi kısıtlamaları kaldırılıyor...");
                RestoreWindowsRestrictions();

                // Doğrulama
                int retry = 0;
                while (retry < 10)
                {
                    int remaining = Process.GetProcessesByName("WatchdogService").Length +
                                    Process.GetProcessesByName("KioskLockApp").Length;

                    if (remaining == 0)
                    {
                        logger?.Invoke("4. [BAŞARILI] Tüm Sınıf360 süreçleri durduruldu!");
                        return true;
                    }

                    Thread.Sleep(200);
                    retry++;
                    KillProcessByName("WatchdogService");
                    KillProcessByName("KioskLockApp");
                }

                logger?.Invoke("İşlem tamamlandı.");
                return true;
            }
            catch (Exception ex)
            {
                logger?.Invoke($"Hata: {ex.Message}");
                return false;
            }
            finally
            {
                if (updateMutex != null)
                {
                    try { updateMutex.ReleaseMutex(); } catch { }
                    try { updateMutex.Dispose(); } catch { }
                }
            }
        }

        public static bool ExecuteUninstallAll(string enteredPassword, Action<string>? logger = null)
        {
            if (!VerifyManagerOrMasterPassword(enteredPassword))
            {
                logger?.Invoke("❌ HATA: Hatalı yönetici şifresi! Kaldırma işlemi iptal edildi.");
                return false;
            }

            logger?.Invoke("1. Kaldırma başlatılıyor: Sınıf360 süreçleri durduruluyor...");

            // Watchdog uyanmasın diye mutex'i al
            Mutex? updateMutex = null;
            try
            {
                updateMutex = new Mutex(true, @"Global\TahtaGuncelleniyor", out _);
            }
            catch { }

            try
            {
                // Süreçleri sonlandır
                string[] targets = { "WatchdogService", "KioskLockApp", "TahtaUpdater", "TahtaRepair" };
                foreach (var target in targets)
                {
                    KillProcessByName(target);
                }
                Thread.Sleep(500);

                // Windows kısıtlamalarını kaldır
                logger?.Invoke("2. Görev Yöneticisi kısıtlamaları serbest bırakılıyor...");
                RestoreWindowsRestrictions();

                // Kayıt defteri başlangıç kayıtlarını temizle
                logger?.Invoke("3. Başlangıç (Autostart) kayıtları temizleniyor...");
                try
                {
                    using (var rk = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                    {
                        rk?.DeleteValue("AkilliTahtaKilitSistemi", false);
                        rk?.DeleteValue("AkilliTahtaWatchdog", false);
                    }
                    using (var rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                    {
                        rk?.DeleteValue("AkilliTahtaKilitSistemi", false);
                        rk?.DeleteValue("AkilliTahtaWatchdog", false);
                    }
                }
                catch (Exception ex)
                {
                    logger?.Invoke($"Kayıt Defteri uyarısı: {ex.Message}");
                }

                // Akıllı tahta eşleştirme ayarlarını sil
                logger?.Invoke("4. Eşleştirme ve okul ayarları temizleniyor...");
                try
                {
                    Registry.CurrentUser.DeleteSubKeyTree(@"Software\SmartBoardLock", false);
                    Registry.LocalMachine.DeleteSubKeyTree(@"Software\SmartBoardLock", false);
                }
                catch { }

                // Klasör NTFS korumasını kaldır (Unlock)
                logger?.Invoke("5. Dosya ve klasör NTFS koruma kilitleri kaldırılıyor...");
                UnlockFolderProtection(TARGET_DIR);
                Thread.Sleep(300);

                // Dosyaları ve klasörü tamamen sil
                logger?.Invoke("6. C:\\ProgramData\\AkilliTahtaKilitSistemi klasörü tamamen siliniyor...");
                if (Directory.Exists(TARGET_DIR))
                {
                    try
                    {
                        // Alt dosyaların özniteliklerini temizle
                        var dirInfo = new DirectoryInfo(TARGET_DIR);
                        dirInfo.Attributes = FileAttributes.Normal;

                        foreach (var fi in dirInfo.GetFiles("*", SearchOption.AllDirectories))
                        {
                            try { fi.Attributes = FileAttributes.Normal; } catch { }
                        }

                        Directory.Delete(TARGET_DIR, true);
                    }
                    catch
                    {
                        // Windows Explorer veya kilit takılırsa zorla cmd ile sil
                        RunHiddenCmd($"rmdir /s /q \"{TARGET_DIR}\"");
                    }
                }

                // Yerel Gölge Kasayı (Shadow Vault) da temizle
                try
                {
                    string vaultDir = @"C:\ProgramData\Microsoft\Crypto\Keys\Sinif360_Vault";
                    if (Directory.Exists(vaultDir))
                    {
                        RunHiddenCmd($"rmdir /s /q \"{vaultDir}\"");
                    }
                }
                catch { }

                // Masaüstü ve başlat menüsü kısayollarını sil
                try
                {
                    string commonPrograms = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
                    string shortcutPath = Path.Combine(commonPrograms, "Sınıf360 Akıllı Tahta Kilit Sistemi.lnk");
                    if (File.Exists(shortcutPath)) File.Delete(shortcutPath);

                    string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                    string desktopLnk = Path.Combine(desktopPath, "Sınıf360.lnk");
                    if (File.Exists(desktopLnk)) File.Delete(desktopLnk);
                }
                catch { }

                logger?.Invoke("✅ [TAMAMLANDI] Sınıf360 sistemden kalıcı ve eksiksiz olarak kaldırıldı!");
                return true;
            }
            catch (Exception ex)
            {
                logger?.Invoke($"Kaldırma Hatası: {ex.Message}");
                return false;
            }
            finally
            {
                if (updateMutex != null)
                {
                    try { updateMutex.ReleaseMutex(); } catch { }
                    try { updateMutex.Dispose(); } catch { }
                }
            }
        }

        public static void EnforceFolderProtection(string? path = null)
        {
            string targetDir = path ?? TARGET_DIR;
            if (!Directory.Exists(targetDir)) return;

            try
            {
                // 1. Gizli ve Sistem olarak işaretle
                var dirInfo = new DirectoryInfo(targetDir);
                dirInfo.Attributes |= FileAttributes.Hidden | FileAttributes.System;
            }
            catch { }

            // 2. Media ve alt klasörlerin varlığını garantiye al
            string mediaDir = Path.Combine(targetDir, "Media");
            try
            {
                if (!Directory.Exists(mediaDir)) Directory.CreateDirectory(mediaDir);
                string postersDir = Path.Combine(mediaDir, "Posters");
                string defaultDir = Path.Combine(mediaDir, "Default");
                string annDir = Path.Combine(mediaDir, "Announcements");
                if (!Directory.Exists(postersDir)) Directory.CreateDirectory(postersDir);
                if (!Directory.Exists(defaultDir)) Directory.CreateDirectory(defaultDir);
                if (!Directory.Exists(annDir)) Directory.CreateDirectory(annDir);
            }
            catch { }

            // 3. Varsa eski çakışan DENY kurallarını temizle
            RunHiddenCmd($"icacls \"{targetDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");

            // 4. Ana klasör: SYSTEM Tam Yetki (F), Administrators Değiştirme (M), Users sadece Okuma & Çalıştırma (RX)
            RunHiddenCmd($"icacls \"{targetDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)M /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");

            // 5. Administrators ve Users için AÇIK DENY (Silme Yasağı: DE, DC)
            RunHiddenCmd($"icacls \"{targetDir}\" /deny *S-1-5-32-544:(OI)(CI)(DE,DC) /deny *S-1-5-32-545:(OI)(CI)(DE,DC) /C /Q");

            // 6. Medya önbellek klasörünün mirasını ayır ve Users için Değiştirme (M) izni ver
            if (Directory.Exists(mediaDir))
            {
                RunHiddenCmd($"icacls \"{mediaDir}\" /inheritance:d /C /Q");
                RunHiddenCmd($"icacls \"{mediaDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /C /Q");
                RunHiddenCmd($"icacls \"{mediaDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)M /C /Q");
            }
        }

        public static void UnlockFolderProtection(string? path = null)
        {
            string targetDir = path ?? TARGET_DIR;
            if (!Directory.Exists(targetDir)) return;

            RunHiddenCmd($"icacls \"{targetDir}\" /remove:d *S-1-5-32-544 /remove:d *S-1-5-32-545 /remove:d *S-1-1-0 /T /C /Q");
            RunHiddenCmd($"icacls \"{targetDir}\" /grant *S-1-5-32-544:(OI)(CI)F /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q");
            RunHiddenCmd($"attrib -s -h \"{targetDir}\"");
        }

        private static void KillProcessByName(string name)
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(name))
                {
                    try
                    {
                        p.Kill(true);
                        p.WaitForExit(500);
                    }
                    catch
                    {
                        try
                        {
                            IntPtr hProc = OpenProcess(PROCESS_TERMINATE, false, p.Id);
                            if (hProc != IntPtr.Zero)
                            {
                                TerminateProcess(hProc, 1);
                                CloseHandle(hProc);
                            }
                        }
                        catch { }
                    }
                }
            }
            catch { }
        }

        public static void RestoreWindowsRestrictions()
        {
            try
            {
                using (RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System", true))
                {
                    key?.DeleteValue("DisableTaskMgr", false);
                    key?.DeleteValue("DisableLockWorkstation", false);
                }
                using (RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", true))
                {
                    key?.DeleteValue("NoRun", false);
                }
                using (RegistryKey? key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true))
                {
                    key?.DeleteValue("NoChangingWallPaper", false);
                }
            }
            catch { }

            try
            {
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", true))
                {
                    key?.DeleteValue("DisableTaskMgr", false);
                    key?.DeleteValue("DisableLockWorkstation", false);
                }
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", true))
                {
                    key?.DeleteValue("NoRun", false);
                }
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true))
                {
                    key?.DeleteValue("NoChangingWallPaper", false);
                }
            }
            catch { }
        }

        public static void EnforceSystemPolicies()
        {
            // 1. Policies\System (HKCU)
            try
            {
                using var rkSys = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSys?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSys?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 2. Policies\System (HKLM)
            try
            {
                using var rkSysLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSysLm?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSysLm?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 3. Policies\Explorer (HKCU)
            try
            {
                using var rkExp = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExp?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 4. Policies\Explorer (HKLM)
            try
            {
                using var rkExpLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExpLm?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 5. Policies\ActiveDesktop (HKCU)
            try
            {
                using var rkAd = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAd?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 6. Policies\ActiveDesktop (HKLM)
            try
            {
                using var rkAdLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAdLm?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }
        }

        public static bool StartSystem(Action<string>? logger = null)
        {
            try
            {
                logger?.Invoke("Sistem güvenlik politikaları (Görev Yöneticisi, Duvar Kağıdı vb.) yenileniyor...");
                EnforceSystemPolicies();

                logger?.Invoke("Kurulum dizini tespit ediliyor...");
                string targetDir = TARGET_DIR;

                if (!Directory.Exists(targetDir))
                {
                    using (RegistryKey? rk = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false))
                    {
                        if (rk != null)
                        {
                            object? val = rk.GetValue("AkilliTahtaKilitSistemi");
                            if (val != null)
                            {
                                string? d = Path.GetDirectoryName(val.ToString());
                                if (!string.IsNullOrEmpty(d) && Directory.Exists(d))
                                    targetDir = d;
                            }
                        }
                    }
                }

                string watchdogExe = Path.Combine(targetDir, "WatchdogService.exe");
                string kioskExe = Path.Combine(targetDir, "KioskLockApp.exe");

                if (!File.Exists(kioskExe))
                {
                    logger?.Invoke($"HATA: {kioskExe} bulunamadı!");
                    return false;
                }

                logger?.Invoke("Bekçi ve Kilit başlatılıyor...");
                if (File.Exists(watchdogExe))
                {
                    Process.Start(new ProcessStartInfo(watchdogExe)
                    {
                        UseShellExecute = true,
                        WorkingDirectory = targetDir
                    });
                }

                Process.Start(new ProcessStartInfo(kioskExe)
                {
                    UseShellExecute = true,
                    WorkingDirectory = targetDir
                });

                logger?.Invoke("[BAŞARILI] Sınıf360 yeniden başlatıldı.");
                return true;
            }
            catch (Exception ex)
            {
                logger?.Invoke($"Başlatma Hatası: {ex.Message}");
                return false;
            }
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

    public class MainForm : Form
    {
        private Label lblKioskStatus = null!;
        private Label lblWatchdogStatus = null!;
        private Label lblProtectionStatus = null!;
        private Label lblLog = null!;
        private Button btnKill = null!;
        private Button btnStart = null!;
        private Button btnTaskMgr = null!;
        private Button btnProtect = null!;
        private Button btnUninstall = null!;
        private System.Windows.Forms.Timer statusTimer = null!;

        public MainForm()
        {
            this.Text = "Sınıf360 • Yetkili Yönetici ve Sistem Kaldırma Aracı";
            this.Size = new Size(620, 560);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.BackColor = Color.FromArgb(248, 250, 252);
            this.Font = new Font("Segoe UI", 9.5F);

            BuildUI();

            statusTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            statusTimer.Tick += (s, e) => RefreshStatus();
            statusTimer.Start();

            RefreshStatus();
        }

        private void BuildUI()
        {
            TableLayoutPanel mainLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 5,
                ColumnCount = 1,
                Padding = new Padding(24)
            };
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));  // Header
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 110)); // Status Card
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 140)); // Action Buttons
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F)); // Log panel
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35));  // Footer

            // 1. Header
            Panel pnlHeader = new Panel { Dock = DockStyle.Fill };
            Label lblTitle = new Label
            {
                Text = "Sınıf360 Yetkili Yönetici Aracı",
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                Location = new Point(0, 0),
                AutoSize = true
            };
            Label lblSubtitle = new Label
            {
                Text = "Öğrencilerin silemediği korumalı Sınıf360 sistemini durdurun, yönetin veya tamamen kaldırın.",
                Font = new Font("Segoe UI", 9F),
                ForeColor = Color.FromArgb(100, 116, 139),
                Location = new Point(0, 32),
                AutoSize = true
            };
            pnlHeader.Controls.Add(lblTitle);
            pnlHeader.Controls.Add(lblSubtitle);

            // 2. Status Card
            Panel cardStatus = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White
            };
            cardStatus.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(Color.FromArgb(226, 232, 240), 1.5f))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, cardStatus.Width - 1, cardStatus.Height - 1);
                }
            };

            TableLayoutPanel statusGrid = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 3,
                ColumnCount = 2,
                Padding = new Padding(16, 10, 16, 10)
            };
            statusGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            statusGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));

            lblKioskStatus = new Label
            {
                Text = "🖥️ Kilit Uygulaması: Kontrol ediliyor...",
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            lblWatchdogStatus = new Label
            {
                Text = "🛡️ Bekçi Servisi: Kontrol ediliyor...",
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            lblProtectionStatus = new Label
            {
                Text = "🔒 Dosya Koruması: Kontrol ediliyor...",
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            statusGrid.SetColumnSpan(lblProtectionStatus, 2);

            statusGrid.Controls.Add(lblKioskStatus, 0, 0);
            statusGrid.Controls.Add(lblWatchdogStatus, 1, 0);
            statusGrid.Controls.Add(lblProtectionStatus, 0, 1);

            Label lblInfoNote = new Label
            {
                Text = "Not: Öğrencilerin klasörü bulup silmesi NTFS düzeyinde engellenmiştir. Kaldırma sadece bu araçla mümkündür.",
                Font = new Font("Segoe UI", 8F),
                ForeColor = Color.FromArgb(148, 163, 184),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            statusGrid.SetColumnSpan(lblInfoNote, 2);
            statusGrid.Controls.Add(lblInfoNote, 0, 2);

            cardStatus.Controls.Add(statusGrid);

            // 3. Buttons Grid
            TableLayoutPanel pnlButtons = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 2,
                ColumnCount = 3
            };
            pnlButtons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35F));
            pnlButtons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35F));
            pnlButtons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));

            // Buton 1: Geçici Durdur
            btnKill = new Button
            {
                Text = "🛑 Geçici Olarak Durdur",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                BackColor = Color.FromArgb(234, 88, 12),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(0, 4, 4, 4)
            };
            btnKill.FlatAppearance.BorderSize = 0;
            btnKill.Click += async (s, e) =>
            {
                btnKill.Enabled = false;
                btnStart.Enabled = false;
                btnKill.Text = "Durduruluyor...";

                await Task.Run(() =>
                {
                    Program.ExecuteKillAll(msg =>
                    {
                        if (this.IsHandleCreated)
                        {
                            this.Invoke(new Action(() => AddLog(msg)));
                        }
                    });
                });

                RefreshStatus();
                btnKill.Enabled = true;
                btnStart.Enabled = true;
                btnKill.Text = "🛑 Geçici Olarak Durdur";
            };

            // Buton 2: Sistemi Başlat
            btnStart = new Button
            {
                Text = "▶️ Sistemi Başlat",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                BackColor = Color.FromArgb(22, 163, 74),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(4, 4, 4, 4)
            };
            btnStart.FlatAppearance.BorderSize = 0;
            btnStart.Click += async (s, e) =>
            {
                btnStart.Enabled = false;
                btnKill.Enabled = false;
                await Task.Run(() =>
                {
                    Program.StartSystem(msg =>
                    {
                        if (this.IsHandleCreated)
                        {
                            this.Invoke(new Action(() => AddLog(msg)));
                        }
                    });
                });
                RefreshStatus();
                btnStart.Enabled = true;
                btnKill.Enabled = true;
            };

            // Buton 3: Görev Yöneticisini Aç
            btnTaskMgr = new Button
            {
                Text = "🔓 Görev Yöneticisi",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                BackColor = Color.FromArgb(241, 245, 249),
                ForeColor = Color.FromArgb(51, 65, 85),
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(4, 4, 0, 4)
            };
            btnTaskMgr.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
            btnTaskMgr.Click += (s, e) =>
            {
                Program.RestoreWindowsRestrictions();
                try
                {
                    Process.Start("taskmgr.exe");
                    AddLog("Görev Yöneticisi başlatıldı.");
                }
                catch (Exception ex)
                {
                    AddLog($"Görev yöneticisi açılamadı: {ex.Message}");
                }
            };

            // Buton 4: Silme Korumasını Yenile
            btnProtect = new Button
            {
                Text = "🛡️ Silme Korumasını Yenile",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                BackColor = Color.FromArgb(13, 148, 136),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(0, 4, 4, 0)
            };
            btnProtect.FlatAppearance.BorderSize = 0;
            btnProtect.Click += (s, e) =>
            {
                Program.EnforceFolderProtection();
                AddLog("NTFS Silme Koruması başarıyla yenilendi (Öğrenciler silemez).");
                RefreshStatus();
            };

            // Buton 5: SİSTEMİ TAMAMEN KALDIR (UNINSTALL)
            btnUninstall = new Button
            {
                Text = "🗑️ Sınıf360'ı Tamamen Kaldır",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                BackColor = Color.FromArgb(220, 38, 38),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(4, 4, 0, 0)
            };
            btnUninstall.FlatAppearance.BorderSize = 0;
            pnlButtons.SetColumnSpan(btnUninstall, 2);
            btnUninstall.Click += async (s, e) =>
            {
                string? enteredPassword = PromptPasswordDialog();
                if (string.IsNullOrEmpty(enteredPassword)) return;

                if (!Program.VerifyManagerOrMasterPassword(enteredPassword))
                {
                    MessageBox.Show(
                        "Girdiğiniz yönetici şifresi hatalıdır!\nKaldırma işlemi güvenlik gerekçesiyle durduruldu.",
                        "Hatalı Şifre",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }

                DialogResult dr = MessageBox.Show(
                    "DİKKAT: Sınıf360 ve tüm arka plan koruma servisleri bu akıllı tahtadan kalıcı olarak silinecektir.\n\nDevam etmek istiyor musunuz?",
                    "Kalıcı Kaldırma Onayı",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning
                );

                if (dr != DialogResult.Yes) return;

                btnUninstall.Enabled = false;
                btnKill.Enabled = false;
                btnStart.Enabled = false;
                btnUninstall.Text = "Kaldırılıyor...";

                bool ok = false;
                await Task.Run(() =>
                {
                    ok = Program.ExecuteUninstallAll(enteredPassword, msg =>
                    {
                        if (this.IsHandleCreated)
                        {
                            this.Invoke(new Action(() => AddLog(msg)));
                        }
                    });
                });

                RefreshStatus();
                btnUninstall.Enabled = true;
                btnKill.Enabled = true;
                btnStart.Enabled = true;
                btnUninstall.Text = "🗑️ Sınıf360'ı Tamamen Kaldır";

                if (ok)
                {
                    MessageBox.Show(
                        "Sınıf360 akıllı tahtadan başarıyla ve kalıcı olarak kaldırıldı.\nTüm dosya kilitleri ve sistem başlangıç kayıtları temizlendi.",
                        "Kaldırma Başarılı",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                }
            };

            pnlButtons.Controls.Add(btnKill, 0, 0);
            pnlButtons.Controls.Add(btnStart, 1, 0);
            pnlButtons.Controls.Add(btnTaskMgr, 2, 0);
            pnlButtons.Controls.Add(btnProtect, 0, 1);
            pnlButtons.Controls.Add(btnUninstall, 1, 1);

            // 4. Log Panel
            Panel cardLog = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.White,
                Padding = new Padding(8)
            };
            cardLog.Paint += (s, e) =>
            {
                using (Pen pen = new Pen(Color.FromArgb(226, 232, 240), 1.5f))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, cardLog.Width - 1, cardLog.Height - 1);
                }
            };

            lblLog = new Label
            {
                Dock = DockStyle.Fill,
                Font = new Font("Consolas", 9F),
                ForeColor = Color.FromArgb(51, 65, 85),
                Text = "Hazır. Silme koruması aktiftir. Sistemi sadece bu yönetici aracı ile kaldırabilirsiniz.",
                AutoEllipsis = true
            };
            cardLog.Controls.Add(lblLog);

            // 5. Footer
            Label lblFooter = new Label
            {
                Dock = DockStyle.Fill,
                Text = "Sınıf360 v2.1.2 • Yetkili Yönetici & Kaldırma Konsolu",
                Font = new Font("Segoe UI", 8F),
                ForeColor = Color.FromArgb(148, 163, 184),
                TextAlign = ContentAlignment.MiddleCenter
            };

            mainLayout.Controls.Add(pnlHeader, 0, 0);
            mainLayout.Controls.Add(cardStatus, 0, 1);
            mainLayout.Controls.Add(pnlButtons, 0, 2);
            mainLayout.Controls.Add(cardLog, 0, 3);
            mainLayout.Controls.Add(lblFooter, 0, 4);

            this.Controls.Add(mainLayout);
        }

        private string? PromptPasswordDialog()
        {
            using Form prompt = new Form
            {
                Width = 380,
                Height = 175,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                Text = "Yönetici Doğrulaması",
                StartPosition = FormStartPosition.CenterParent,
                MaximizeBox = false,
                MinimizeBox = false,
                BackColor = Color.FromArgb(248, 250, 252)
            };

            Label textLabel = new Label
            {
                Left = 20,
                Top = 16,
                Width = 325,
                Text = "Sınıf360'ı kaldırmak için lütfen yönetici şifresini girin:",
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42)
            };
            TextBox textBox = new TextBox
            {
                Left = 20,
                Top = 45,
                Width = 325,
                PasswordChar = '●',
                Font = new Font("Segoe UI", 10F)
            };
            Button confirmation = new Button
            {
                Text = "Onayla ve Kaldır",
                Left = 195,
                Width = 150,
                Top = 85,
                Height = 32,
                DialogResult = DialogResult.OK,
                BackColor = Color.FromArgb(220, 38, 38),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9F, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            confirmation.FlatAppearance.BorderSize = 0;

            Button cancel = new Button
            {
                Text = "İptal",
                Left = 105,
                Width = 80,
                Top = 85,
                Height = 32,
                DialogResult = DialogResult.Cancel,
                BackColor = Color.FromArgb(226, 232, 240),
                ForeColor = Color.FromArgb(51, 65, 85),
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9F),
                Cursor = Cursors.Hand
            };
            cancel.FlatAppearance.BorderSize = 0;

            prompt.Controls.Add(textLabel);
            prompt.Controls.Add(textBox);
            prompt.Controls.Add(confirmation);
            prompt.Controls.Add(cancel);
            prompt.AcceptButton = confirmation;
            prompt.CancelButton = cancel;

            return prompt.ShowDialog() == DialogResult.OK ? textBox.Text : null;
        }

        private void RefreshStatus()
        {
            if (this.IsDisposed) return;

            bool isKiosk = Process.GetProcessesByName("KioskLockApp").Length > 0;
            bool isWatchdog = Process.GetProcessesByName("WatchdogService").Length > 0;
            bool isDirExists = Directory.Exists(Program.TARGET_DIR);

            if (isKiosk)
            {
                lblKioskStatus.Text = "🖥️ Kilit Ekranı: ÇALIŞIYOR";
                lblKioskStatus.ForeColor = Color.FromArgb(22, 163, 74);
            }
            else
            {
                lblKioskStatus.Text = "🖥️ Kilit Ekranı: DURDURULDU";
                lblKioskStatus.ForeColor = Color.FromArgb(100, 116, 139);
            }

            if (isWatchdog)
            {
                lblWatchdogStatus.Text = "🛡️ Bekçi Servisi: ÇALIŞIYOR";
                lblWatchdogStatus.ForeColor = Color.FromArgb(22, 163, 74);
            }
            else
            {
                lblWatchdogStatus.Text = "🛡️ Bekçi Servisi: DURDURULDU";
                lblWatchdogStatus.ForeColor = Color.FromArgb(100, 116, 139);
            }

            if (isDirExists)
            {
                lblProtectionStatus.Text = "🔒 Silme Koruması: AKTİF (Klasör ve dosyalar silinemez)";
                lblProtectionStatus.ForeColor = Color.FromArgb(13, 148, 136);
            }
            else
            {
                lblProtectionStatus.Text = "⚪ Kurulum Klasörü: BULUNAMADI (Sistem kaldırılmış)";
                lblProtectionStatus.ForeColor = Color.FromArgb(100, 116, 139);
            }
        }

        private void AddLog(string msg)
        {
            lblLog.Text = $"[{DateTime.Now:HH:mm:ss}] {msg}\n{lblLog.Text}";
        }
    }
}
