using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
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

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Sessiz / Anında kapatma parametresi kontrolü
            foreach (var arg in args)
            {
                if (arg.Equals("--now", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("/q", StringComparison.OrdinalIgnoreCase))
                {
                    ExecuteKillAll();
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

        private static void KillProcessByName(string name)
        {
            try
            {
                foreach (var p in Process.GetProcessesByName(name))
                {
                    try
                    {
                        // Standart .NET Kill (ağaçla birlikte)
                        p.Kill(true);
                        p.WaitForExit(500);
                    }
                    catch
                    {
                        // Yetki / erişim takılırsa doğrudan Win32 TerminateProcess API çağrısı
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
                }
            }
            catch { }

            try
            {
                using (RegistryKey? key = Registry.LocalMachine.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System", true))
                {
                    key?.DeleteValue("DisableTaskMgr", false);
                }
            }
            catch { }
        }

        public static bool StartSystem(Action<string>? logger = null)
        {
            try
            {
                logger?.Invoke("Kurulum dizini tespit ediliyor...");
                string targetDir = @"C:\ProgramData\AkilliTahtaKilitSistemi";

                if (!Directory.Exists(targetDir))
                {
                    // Registry'den kontrol et
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
    }

    public class MainForm : Form
    {
        private Label lblKioskStatus = null!;
        private Label lblWatchdogStatus = null!;
        private Label lblLog = null!;
        private Button btnKill = null!;
        private Button btnStart = null!;
        private Button btnTaskMgr = null!;
        private System.Windows.Forms.Timer statusTimer = null!;

        public MainForm()
        {
            this.Text = "Sınıf360 • Sistem Kapatma ve Kontrol Aracı";
            this.Size = new Size(580, 460);
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
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 70)); // Header
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 90)); // Status Card
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 110)); // Action Buttons
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F)); // Log panel
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 35)); // Footer

            // 1. Header
            Panel pnlHeader = new Panel { Dock = DockStyle.Fill };
            Label lblTitle = new Label
            {
                Text = "Sınıf360 Sistem Kontrol Aracı",
                Font = new Font("Segoe UI", 16, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                Location = new Point(0, 0),
                AutoSize = true
            };
            Label lblSubtitle = new Label
            {
                Text = "Akıllı tahta kilit ekranı ve arka plan bekçi servisini güvenle durdurun.",
                Font = new Font("Segoe UI", 9.5F),
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
                RowCount = 2,
                ColumnCount = 2,
                Padding = new Padding(16, 12, 16, 12)
            };
            statusGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            statusGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));

            lblKioskStatus = new Label
            {
                Text = "🖥️ Kilit Uygulaması (Kiosk): Kontrol ediliyor...",
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            lblWatchdogStatus = new Label
            {
                Text = "🛡️ Bekçi Servisi (Watchdog): Kontrol ediliyor...",
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };

            statusGrid.Controls.Add(lblKioskStatus, 0, 0);
            statusGrid.Controls.Add(lblWatchdogStatus, 1, 0);

            Label lblInfoNote = new Label
            {
                Text = "Not: Bekçi servisi ve kilit birbirini kollayarak yeniden başlatır. Kapat butonu ikisini aynı anda durdurur.",
                Font = new Font("Segoe UI", 8.5F),
                ForeColor = Color.FromArgb(148, 163, 184),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            statusGrid.SetColumnSpan(lblInfoNote, 2);
            statusGrid.Controls.Add(lblInfoNote, 0, 1);

            cardStatus.Controls.Add(statusGrid);

            // 3. Buttons Grid
            TableLayoutPanel pnlButtons = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 2,
                ColumnCount = 2
            };
            pnlButtons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 60F));
            pnlButtons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 40F));

            btnKill = new Button
            {
                Text = "🛑 Sınıf360'ı Tamamen Kapat",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                BackColor = Color.FromArgb(220, 38, 38),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(0, 4, 8, 4)
            };
            btnKill.FlatAppearance.BorderSize = 0;
            btnKill.Click += async (s, e) =>
            {
                btnKill.Enabled = false;
                btnStart.Enabled = false;
                btnKill.Text = "Kapatılıyor...";

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
                btnKill.Text = "🛑 Sınıf360'ı Tamamen Kapat";
            };

            btnStart = new Button
            {
                Text = "▶️ Sistemi Başlat",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                BackColor = Color.FromArgb(22, 163, 74),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(0, 4, 0, 4)
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

            btnTaskMgr = new Button
            {
                Text = "🔓 Görev Yöneticisini Aç (TaskMgr)",
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                BackColor = Color.FromArgb(241, 245, 249),
                ForeColor = Color.FromArgb(51, 65, 85),
                FlatStyle = FlatStyle.Flat,
                Cursor = Cursors.Hand,
                Margin = new Padding(0, 4, 8, 4)
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

            pnlButtons.Controls.Add(btnKill, 0, 0);
            pnlButtons.Controls.Add(btnStart, 1, 0);
            pnlButtons.Controls.Add(btnTaskMgr, 0, 1);

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
                Text = "Hazır. 'Sınıf360'ı Tamamen Kapat' butonuna basarak kilit ve bekçiyi durdurabilirsiniz.",
                AutoEllipsis = true
            };
            cardLog.Controls.Add(lblLog);

            // 5. Footer
            Label lblFooter = new Label
            {
                Dock = DockStyle.Fill,
                Text = "Sınıf360 v2.1.2 • Yönetici Yetkileri ile Çalışıyor",
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

        private void RefreshStatus()
        {
            if (this.IsDisposed) return;

            bool isKiosk = Process.GetProcessesByName("KioskLockApp").Length > 0;
            bool isWatchdog = Process.GetProcessesByName("WatchdogService").Length > 0;

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
        }

        private void AddLog(string msg)
        {
            lblLog.Text = $"[{DateTime.Now:HH:mm:ss}] {msg}\n{lblLog.Text}";
        }
    }
}
