using KioskLockApp.Hooks;
using KioskLockApp.Services;
using Microsoft.Win32;
using Postgrest.Attributes;
using Postgrest.Models;
using QRCoder;
using Supabase.Realtime;
using Supabase.Realtime.PostgresChanges;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace KioskLockApp.UI
{
    public partial class SecureRenderer : Form
    {
        [DllImport("user32.dll")] private static extern IntPtr FindWindow(string className, string windowText);
        [DllImport("user32.dll")] private static extern int ShowWindow(IntPtr hwnd, int command);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        private const int SW_HIDE = 0;
        private const int SW_SHOW = 5;

        private System.Windows.Forms.Timer watchdogTimer;
        private System.Windows.Forms.Timer clockTimer;
        private System.Windows.Forms.Timer aggressiveSecurityTimer;
        private System.Windows.Forms.Timer heartbeatTimer;
        private System.Windows.Forms.Timer posterSlideshowTimer;

        private FloatingLockButtonForm floatingLockBtn;
        private string enteredPin = "";
        private bool isOfflineUnlocked = false;
        private string lastQrTime = "";
        private List<Form> secondaryScreens = new List<Form>();
        private string currentChallengeCode = "";

        private Supabase.Client? realtimeClient;
        private RealtimeChannel? boardChannel;
        private Supabase.Client? fallbackRealtimeClient;
        private RealtimeChannel? fallbackBoardChannel;

        private readonly string[] BlacklistedProcesses = { "taskmgr", "cmd", "powershell", "regedit", "mmc", "sethc", "utilman", "osk" };

        private bool isDesignOrTestMode = false;

        public SecureRenderer(bool isDesignOrTestMode = false)
        {
            this.isDesignOrTestMode = isDesignOrTestMode;
            if (!isDesignOrTestMode) DeepWindowsHooks.InitializeHooks();
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = isDesignOrTestMode ? FormWindowState.Normal : FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251);
            this.TopMost = !isDesignOrTestMode;
            this.ShowInTaskbar = isDesignOrTestMode;
            this.FormClosing += SecureRenderer_FormClosing;

            BuildUI();
            this.Shown += (s, e) => ApplyDynamicSizing();
            this.DpiChanged += (s, e) => ApplyDynamicSizing();

            currentChallengeCode = OfflineTotpEngine.GenerateChallengeCode();
            UpdateChallengeDisplay();
            RefreshMediaDisplays();

            if (isDesignOrTestMode)
            {
                return;
            }

            floatingLockBtn = new FloatingLockButtonForm();
            floatingLockBtn.OnLockRequested = async () => {
                isOfflineUnlocked = false;
                LockScreen();
                await SecureSupabase.ForceUpdateLockStateAsync(false);
            };
            _ = SecureSupabase.ReportActiveMediaIdAsync(MediaManager.GetActiveMediaId());

            posterSlideshowTimer = new System.Windows.Forms.Timer { Interval = 15000 };
            posterSlideshowTimer.Tick += (s, e) => {
                if (activePosterPaths.Count > 1)
                {
                    currentPosterIndex = (currentPosterIndex + 1) % activePosterPaths.Count;
                    RefreshPosterImageOnly();
                }
                RotateAnnouncementsIfNeeded();
            };
            posterSlideshowTimer.Start();

            clockTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            clockTimer.Tick += (s, e) => {
                lblTime.Text = DateTime.Now.ToString("HH:mm");
                lblDate.Text = DateTime.Now.ToString("dd MMMM yyyy, dddd");
                RefreshQrCode();
                EnsureWatchdogIsAlive();

                if (DateTime.Now.Second == 0)
                {
                    RefreshMediaDisplays();
                }
            };
            clockTimer.Start();

            watchdogTimer = new System.Windows.Forms.Timer { Interval = 2000 };
            watchdogTimer.Tick += async (s, e) => await CheckStatusAsync();
            watchdogTimer.Start();

            aggressiveSecurityTimer = new System.Windows.Forms.Timer { Interval = 100 };
            aggressiveSecurityTimer.Tick += AggressiveSecurityTimer_Tick;
            aggressiveSecurityTimer.Start();

            // Hafif ping ve Lisans Kontrolü: Her 3 dakikada bir (180 sn) ping atar ve lisans durumunu doğrular
            heartbeatTimer = new System.Windows.Forms.Timer { Interval = 180000 };
            heartbeatTimer.Tick += async (s, e) => {
                await SecureSupabase.SendHeartbeatAsync();
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId))
                {
                    bool isLicensed = await SecureSupabase.CheckLicenseStatusAsync(bId);
                    if (!isLicensed)
                    {
                        SilentExitOnUnlicensed();
                    }
                }
            };
            heartbeatTimer.Start();

            NetworkChange.NetworkAvailabilityChanged += async (s, e) => {
                if (e.IsAvailable)
                {
                    _ = SecureSupabase.ReportStartupAndVersionAsync();
                    await SecureSupabase.SyncOfflineStatusAsync();
                    _ = InitializeRealtimeListenerAsync();
                    await CheckStatusAsync();
                }
            };

            CoverOtherScreens();
            // Açılışta 1 KEZ sürüm ve ilk ping raporlanır
            _ = SecureSupabase.ReportStartupAndVersionAsync();
            CheckStatusAsync();
            _ = InitializeRealtimeListenerAsync();
            _ = UpdateManager.CheckAndApplyUpdatesAsync();
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x80;
                return cp;
            }
        }

        private void AggressiveSecurityTimer_Tick(object sender, EventArgs e)
        {
            if (DeepWindowsHooks.IsLocked)
            {
                IntPtr currentActiveWindow = GetForegroundWindow();
                if (currentActiveWindow != this.Handle)
                {
                    SetForegroundWindow(this.Handle);
                }

                foreach (string badProc in BlacklistedProcesses)
                {
                    foreach (Process p in Process.GetProcessesByName(badProc))
                    {
                        try { p.Kill(); } catch { }
                    }
                }
            }
        }

        private async System.Threading.Tasks.Task CheckStatusAsync()
        {
            var (state, currentName, isActive, remoteCommand) = await SecureSupabase.GetBoardStateSingleQueryAsync();

            if (!string.IsNullOrEmpty(remoteCommand) && remoteCommand.ToUpper().StartsWith("REPAIR_INTEGRITY"))
            {
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId)) _ = SecureSupabase.ClearRemoteCommandAsync(bId);
                LaunchRepairAndExit();
                return;
            }

            if (!string.IsNullOrEmpty(remoteCommand) && remoteCommand.ToUpper() == "SHUTDOWN")
            {
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId)) _ = SecureSupabase.ClearRemoteCommandAsync(bId);
                SecureSupabase.ExecuteShutdown();
                return;
            }

            if (!string.IsNullOrEmpty(remoteCommand) && remoteCommand.StartsWith("MEDIA_DISPATCH:"))
            {
                string payload = remoteCommand.Substring("MEDIA_DISPATCH:".Length);
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId)) _ = SecureSupabase.ClearRemoteCommandAsync(bId);
                _ = System.Threading.Tasks.Task.Run(async () => {
                    bool ok = await MediaManager.ProcessDispatchAsync(payload);
                    if (ok)
                    {
                        await SecureSupabase.ReportActiveMediaIdAsync(MediaManager.GetActiveMediaId());
                        this.Invoke(new Action(() => RefreshMediaDisplays()));
                    }
                });
            }
            else if (!string.IsNullOrEmpty(remoteCommand) && remoteCommand.StartsWith("MEDIA_UPDATE_DURATION:"))
            {
                string payload = remoteCommand.Substring("MEDIA_UPDATE_DURATION:".Length);
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId)) _ = SecureSupabase.ClearRemoteCommandAsync(bId);
                MediaManager.UpdateDuration(payload);
                RefreshMediaDisplays();
            }
            else if (!string.IsNullOrEmpty(remoteCommand) && (remoteCommand == "MEDIA_RESET" || remoteCommand == "RESET_MEDIA"))
            {
                string bId = SecureSupabase.GetRegistryValue("BoardId");
                if (!string.IsNullOrEmpty(bId)) _ = SecureSupabase.ClearRemoteCommandAsync(bId);
                MediaManager.ResetToDefault();
                _ = SecureSupabase.ReportActiveMediaIdAsync("DEFAULT");
                RefreshMediaDisplays();
            }

            if (lblBoard != null && lblBoard.Text != currentName)
            {
                lblBoard.Text = currentName;
            }

            if (state == "DELETED")
            {
                ResetToPairingMode();
                return;
            }
            else if (state == "UNLOCKED")
            {
                isOfflineUnlocked = false;
                UnlockScreen();
            }
            else if (state == "LOCKED")
            {
                isOfflineUnlocked = false;
                LockScreen();
            }
            else
            {
                bool lastKnownActive = SecureSupabase.GetRegistryValue("LastKnownIsActive", "true") == "true";
                if (isOfflineUnlocked || !lastKnownActive) UnlockScreen();
                else LockScreen();
            }
        }

        private async System.Threading.Tasks.Task InitializeRealtimeListenerAsync()
        {
            try
            {
                string boardId = SecureSupabase.GetRegistryValue("BoardId");
                if (string.IsNullOrEmpty(boardId)) return;

                if (realtimeClient != null)
                {
                    try { boardChannel?.Unsubscribe(); realtimeClient.Realtime.Disconnect(); } catch { }
                }
                if (fallbackRealtimeClient != null)
                {
                    try { fallbackBoardChannel?.Unsubscribe(); fallbackRealtimeClient.Realtime.Disconnect(); } catch { }
                }

                // 1. Birincil Realtime Bağlantısı (Oracle Cloud Supabase)
                try
                {
                    string url = SecureSupabase.SUPABASE_URL;
                    string key = SecureSupabase.SUPABASE_KEY;
                    var options = new Supabase.SupabaseOptions { AutoConnectRealtime = true };
                    realtimeClient = new Supabase.Client(url, key, options);
                    await realtimeClient.InitializeAsync();

                    boardChannel = realtimeClient.Realtime.Channel("realtime", "public", "boards");
                    boardChannel.AddPostgresChangeHandler(
                        Supabase.Realtime.PostgresChanges.PostgresChangesOptions.ListenType.Updates,
                        (sender, change) => {
                            var rec = change.Model<BoardRealtimeModel>();
                            if (rec != null) HandleRealtimeRecord(rec, boardId);
                        }
                    );
                    await boardChannel.Subscribe();
                }
                catch { }

                // 2. İkincil / Canlı Güvenlik Ağı Realtime Bağlantısı (Cloud Supabase)
                try
                {
                    string fallbackUrl = SecureSupabase.FALLBACK_URL;
                    string fallbackKey = SecureSupabase.FALLBACK_KEY;
                    var fallbackOptions = new Supabase.SupabaseOptions { AutoConnectRealtime = true };
                    fallbackRealtimeClient = new Supabase.Client(fallbackUrl, fallbackKey, fallbackOptions);
                    await fallbackRealtimeClient.InitializeAsync();

                    fallbackBoardChannel = fallbackRealtimeClient.Realtime.Channel("realtime_fallback", "public", "boards");
                    fallbackBoardChannel.AddPostgresChangeHandler(
                        Supabase.Realtime.PostgresChanges.PostgresChangesOptions.ListenType.Updates,
                        (sender, change) => {
                            var rec = change.Model<BoardRealtimeModel>();
                            if (rec != null) HandleRealtimeRecord(rec, boardId);
                        }
                    );
                    await fallbackBoardChannel.Subscribe();
                }
                catch { }
            }
            catch { }
        }

        private void HandleRealtimeRecord(BoardRealtimeModel record, string boardId)
        {
            if (record != null && record.Id == boardId)
            {
                this.Invoke(new Action(() => {
                    if (!string.IsNullOrEmpty(record.RemoteCommand) && record.RemoteCommand.ToUpper().StartsWith("REPAIR_INTEGRITY"))
                    {
                        _ = SecureSupabase.ClearRemoteCommandAsync(boardId);
                        LaunchRepairAndExit();
                        return;
                    }

                    if (!string.IsNullOrEmpty(record.RemoteCommand) && record.RemoteCommand.ToUpper() == "SHUTDOWN")
                    {
                        _ = SecureSupabase.ClearRemoteCommandAsync(boardId);
                        SecureSupabase.ExecuteShutdown();
                        return;
                    }

                    if (!string.IsNullOrEmpty(record.RemoteCommand) && record.RemoteCommand.StartsWith("MEDIA_DISPATCH:"))
                    {
                        string payload = record.RemoteCommand.Substring("MEDIA_DISPATCH:".Length);
                        _ = SecureSupabase.ClearRemoteCommandAsync(boardId);
                        _ = System.Threading.Tasks.Task.Run(async () => {
                            bool ok = await MediaManager.ProcessDispatchAsync(payload);
                            if (ok)
                            {
                                await SecureSupabase.ReportActiveMediaIdAsync(MediaManager.GetActiveMediaId());
                                this.Invoke(new Action(() => RefreshMediaDisplays()));
                            }
                        });
                    }
                    else if (!string.IsNullOrEmpty(record.RemoteCommand) && record.RemoteCommand.StartsWith("MEDIA_UPDATE_DURATION:"))
                    {
                        string payload = record.RemoteCommand.Substring("MEDIA_UPDATE_DURATION:".Length);
                        _ = SecureSupabase.ClearRemoteCommandAsync(boardId);
                        MediaManager.UpdateDuration(payload);
                        RefreshMediaDisplays();
                    }
                    else if (!string.IsNullOrEmpty(record.RemoteCommand) && (record.RemoteCommand == "MEDIA_RESET" || record.RemoteCommand == "RESET_MEDIA"))
                    {
                        _ = SecureSupabase.ClearRemoteCommandAsync(boardId);
                        MediaManager.ResetToDefault();
                        _ = SecureSupabase.ReportActiveMediaIdAsync("DEFAULT");
                        RefreshMediaDisplays();
                    }

                    if (lblBoard != null && lblBoard.Text != record.Name && !string.IsNullOrEmpty(record.Name))
                    {
                        lblBoard.Text = record.Name;
                        SecureSupabase.SetRegistryValue("BoardName", record.Name);
                        _ = SecureSupabase.SyncBoardNameAsync(boardId, record.Name);
                    }

                    SecureSupabase.SetRegistryValue("LastKnownIsActive", record.IsActive ? "true" : "false");

                    if (!record.IsActive || record.IsUnlocked)
                    {
                        isOfflineUnlocked = false;
                        UnlockScreen();
                    }
                    else
                    {
                        isOfflineUnlocked = false;
                        LockScreen();
                    }
                }));
            }
        }

        private void Numpad_Click(object sender, EventArgs e)
        {
            if (enteredPin.Length < 6)
            {
                FluentButton clickedBtn = sender as FluentButton;
                if (clickedBtn != null)
                {
                    enteredPin += clickedBtn.Text;
                    UpdatePinDisplay();

                    if (enteredPin.Length == 6) VerifyPinLogic();
                }
            }
        }

        private void VerifyPinLogic()
        {
            if (OfflineTotpEngine.VerifyPin(enteredPin, currentChallengeCode))
            {
                isOfflineUnlocked = true;
                SecureSupabase.SetRegistryValue("PendingOfflineSync", "UNLOCK");
                _ = SecureSupabase.SyncOfflineStatusAsync();

                UnlockScreen();
                enteredPin = "";
                currentChallengeCode = OfflineTotpEngine.GenerateChallengeCode();
                UpdateChallengeDisplay();
            }
            else
            {
                lblPinDisplay.Text = "HATALI PIN";
                lblPinDisplay.ForeColor = Color.FromArgb(220, 38, 38);
                enteredPin = "";
                currentChallengeCode = OfflineTotpEngine.GenerateChallengeCode();
                UpdateChallengeDisplay();
                System.Threading.Tasks.Task.Delay(1000).ContinueWith(t => { this.Invoke(new Action(() => UpdatePinDisplay())); });
            }
        }

        private void UpdateChallengeDisplay()
        {
            if (lblPinSub != null)
            {
                lblPinSub.Text = $"Çevrimdışı Kod: {currentChallengeCode}";
                float uniformScale = Math.Min(Math.Max(0.65f, this.ClientSize.Width / 1920f), Math.Max(0.65f, this.ClientSize.Height / 1080f));
                lblPinSub.Font = new Font("Segoe UI", Math.Max(7.5f, 9f * uniformScale), FontStyle.Bold);
                lblPinSub.ForeColor = ColPrimary;
            }
        }

        private void UpdatePinDisplay()
        {
            lblPinDisplay.ForeColor = Color.FromArgb(17, 24, 39);
            if (string.IsNullOrEmpty(enteredPin))
            {
                lblPinDisplay.Text = "○  ○  ○  ○  ○  ○";
            }
            else
            {
                string display = "";
                for (int i = 0; i < 6; i++) display += (i < enteredPin.Length) ? "●  " : "○  ";
                lblPinDisplay.Text = display.Trim();
            }
        }

        private void RefreshQrCode()
        {
            string currentMinute = DateTime.UtcNow.ToString("yyyyMMddHHmm");
            if (currentMinute == lastQrTime) return;

            string payload = DynamicQrEngine.GenerateQrPayload();
            if (payload == "ERR_NO_CONFIG") return;

            using (QRCodeGenerator qrGenerator = new QRCodeGenerator())
            {
                QRCodeData qrCodeData = qrGenerator.CreateQrCode(payload, QRCodeGenerator.ECCLevel.Q);
                using (QRCode qrCode = new QRCode(qrCodeData))
                {
                    pbQrCode.Image?.Dispose();
                    pbQrCode.Image = qrCode.GetGraphic(10);
                }
            }
            lastQrTime = currentMinute;
        }

        private void UnlockScreen()
        {
            DeepWindowsHooks.IsLocked = false;
            IntPtr taskbar = FindWindow("Shell_TrayWnd", null);
            if (taskbar != IntPtr.Zero) ShowWindow(taskbar, SW_SHOW);

            // YENİ: WPF için Visibility kullanılır
            if (floatingLockBtn.Visibility != System.Windows.Visibility.Visible)
                floatingLockBtn.Visibility = System.Windows.Visibility.Visible;

            if (watchdogTimer != null) watchdogTimer.Interval = 10000; // Açıkken 10 saniyede bir hafif kontrol

            RemoveSecondaryScreens();
            this.Hide();
        }

        private void LockScreen()
        {
            DeepWindowsHooks.IsLocked = true;
            IntPtr taskbar = FindWindow("Shell_TrayWnd", null);
            if (taskbar != IntPtr.Zero) ShowWindow(taskbar, SW_HIDE);

            // YENİ: WPF için Visibility kullanılır
            if (floatingLockBtn.Visibility == System.Windows.Visibility.Visible)
                floatingLockBtn.Visibility = System.Windows.Visibility.Hidden;

            if (watchdogTimer != null) watchdogTimer.Interval = 2000; // Kilitliyken 2 saniyede bir hızlı kontrol (Hızlı açılma)

            if (secondaryScreens.Count == 0 && Screen.AllScreens.Length > 1) CoverOtherScreens();
            this.Show();
            SetForegroundWindow(this.Handle);
        }

        private void CoverOtherScreens()
        {
            foreach (var screen in Screen.AllScreens)
            {
                if (screen.Primary) continue;
                Form blackScreen = new Form
                {
                    BackColor = Color.Black,
                    FormBorderStyle = FormBorderStyle.None,
                    StartPosition = FormStartPosition.Manual,
                    Bounds = screen.Bounds,
                    TopMost = true,
                    ShowInTaskbar = false
                };
                blackScreen.Show();
                secondaryScreens.Add(blackScreen);
            }
        }

        private void RemoveSecondaryScreens()
        {
            foreach (var screen in secondaryScreens)
            {
                if (screen != null && !screen.IsDisposed) screen.Close();
            }
            secondaryScreens.Clear();
        }

        private void EnsureWatchdogIsAlive()
        {
            try
            {
                Process[] processes = Process.GetProcessesByName("WatchdogService");
                if (processes.Length == 0)
                {
                    string watchdogPath = System.IO.Path.Combine(Application.StartupPath, "WatchdogService.exe");
                    if (System.IO.File.Exists(watchdogPath))
                    {
                        Process.Start(new ProcessStartInfo(watchdogPath) { UseShellExecute = true, WorkingDirectory = Application.StartupPath });
                    }
                }
            }
            catch { }
        }

        private void SecureRenderer_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing) e.Cancel = true;
        }

        private void ResetToPairingMode()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock", true))
                {
                    if (key != null)
                    {
                        key.DeleteValue("BoardId", false);
                        key.DeleteValue("OfflineSecret", false);
                        key.DeleteValue("BoardName", false);
                        key.DeleteValue("SchoolName", false);
                    }
                }
            }
            catch { }

            watchdogTimer?.Stop();
            clockTimer?.Stop();
            aggressiveSecurityTimer?.Stop();
            heartbeatTimer?.Stop();
            DeepWindowsHooks.IsLocked = false;
            RemoveSecondaryScreens();

            Application.Restart();
            Environment.Exit(0);
        }

        private void LaunchRepairAndExit()
        {
            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string repairExe = System.IO.Path.Combine(baseDir, "TahtaRepair.exe");
                if (!System.IO.File.Exists(repairExe))
                {
                    repairExe = @"C:\ProgramData\AkilliTahtaKilitSistemi\TahtaRepair.exe";
                }

                if (System.IO.File.Exists(repairExe))
                {
                    ProcessStartInfo psi = new ProcessStartInfo(repairExe, "--remote")
                    {
                        UseShellExecute = true,
                        WorkingDirectory = System.IO.Path.GetDirectoryName(repairExe)
                    };
                    Process.Start(psi);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error launching TahtaRepair: {ex.Message}");
            }
            finally
            {
                watchdogTimer?.Stop();
                clockTimer?.Stop();
                aggressiveSecurityTimer?.Stop();
                heartbeatTimer?.Stop();
                DeepWindowsHooks.IsLocked = false;
                Environment.Exit(0);
            }
        }

        private void SilentExitOnUnlicensed()
        {
            try
            {
                watchdogTimer?.Stop();
                clockTimer?.Stop();
                aggressiveSecurityTimer?.Stop();
                heartbeatTimer?.Stop();
                DeepWindowsHooks.IsLocked = false;
                RemoveSecondaryScreens();
            }
            catch { }
            Environment.Exit(0);
        }

        private string GetSavedSchoolName() => SecureSupabase.GetRegistryValue("SchoolName", "Bilinmeyen Okul");
        private string GetSavedBoardName() => SecureSupabase.GetRegistryValue("BoardName", "İsimsiz Tahta");
    }

    [Table("boards")]
    public class BoardRealtimeModel : BaseModel
    {
        [Column("id")] public string Id { get; set; }
        [Column("is_unlocked")] public bool IsUnlocked { get; set; }
        [Column("is_active")] public bool IsActive { get; set; }
        [Column("name")] public string Name { get; set; }
        [Column("remote_command")] public string? RemoteCommand { get; set; }
    }
}