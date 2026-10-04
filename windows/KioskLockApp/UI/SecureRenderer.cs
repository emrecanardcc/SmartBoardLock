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

        private FloatingLockButtonForm floatingLockBtn;
        private string enteredPin = "";
        private bool isOfflineUnlocked = false;
        private string lastQrTime = "";
        private List<Form> secondaryScreens = new List<Form>();
        private string currentChallengeCode = "";

        private Supabase.Client realtimeClient;
        private RealtimeChannel boardChannel;

        private readonly string[] BlacklistedProcesses = { "taskmgr", "cmd", "powershell", "regedit", "mmc", "sethc", "utilman", "osk" };

        public SecureRenderer()
        {
            DeepWindowsHooks.InitializeHooks();
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251);
            this.TopMost = true;
            this.ShowInTaskbar = false;
            this.FormClosing += SecureRenderer_FormClosing;

            BuildUI();

            floatingLockBtn = new FloatingLockButtonForm();
            floatingLockBtn.OnLockRequested = async () => {
                isOfflineUnlocked = false;
                LockScreen();
                await SecureSupabase.ForceUpdateLockStateAsync(false);
            };

            currentChallengeCode = OfflineTotpEngine.GenerateChallengeCode();
            UpdateChallengeDisplay();

            clockTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            clockTimer.Tick += (s, e) => {
                lblTime.Text = DateTime.Now.ToString("HH:mm");
                lblDate.Text = DateTime.Now.ToString("dd MMMM yyyy, dddd");
                RefreshQrCode();
                EnsureWatchdogIsAlive();
            };
            clockTimer.Start();

            watchdogTimer = new System.Windows.Forms.Timer { Interval = 300000 };
            watchdogTimer.Tick += async (s, e) => await CheckStatusAsync();
            watchdogTimer.Start();

            aggressiveSecurityTimer = new System.Windows.Forms.Timer { Interval = 100 };
            aggressiveSecurityTimer.Tick += AggressiveSecurityTimer_Tick;
            aggressiveSecurityTimer.Start();

            NetworkChange.NetworkAvailabilityChanged += async (s, e) => {
                if (e.IsAvailable)
                {
                    await SecureSupabase.SyncOfflineStatusAsync();
                    _ = InitializeRealtimeListenerAsync();
                    await CheckStatusAsync();
                }
            };

            CoverOtherScreens();
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
            var (state, currentName, isActive) = await SecureSupabase.GetBoardStateSingleQueryAsync();

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

                string url = "https://clkasnbpmhddhstoixdz.supabase.co";
                string key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

                var options = new Supabase.SupabaseOptions { AutoConnectRealtime = true };
                realtimeClient = new Supabase.Client(url, key, options);
                await realtimeClient.InitializeAsync();

                boardChannel = realtimeClient.Realtime.Channel("realtime", "public", "boards");

                boardChannel.AddPostgresChangeHandler(
                    Supabase.Realtime.PostgresChanges.PostgresChangesOptions.ListenType.Updates,
                    (sender, change) =>
                    {
                        var record = change.Model<BoardRealtimeModel>();
                        if (record != null && record.Id == boardId)
                        {
                            this.Invoke(new Action(() => {
                                if (lblBoard != null && lblBoard.Text != record.Name && !string.IsNullOrEmpty(record.Name))
                                {
                                    lblBoard.Text = record.Name;
                                    SecureSupabase.SetRegistryValue("BoardName", record.Name);
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
                    });

                await boardChannel.Subscribe();
            }
            catch { }
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
            UpdateLabelTextRecursive(this, $"Çevrimdışı Kilit Açma Kodu: {currentChallengeCode}");
        }

        private void UpdateLabelTextRecursive(Control parent, string newText)
        {
            foreach (Control c in parent.Controls)
            {
                if (c is Label lbl && (lbl.Text.Contains("Çevrimdışı") || lbl.Text.Contains("İnternet yoksa") || lbl.Text.Contains("Açma Kodu")))
                {
                    lbl.Text = newText;
                    lbl.Font = new Font("Segoe UI", 10, FontStyle.Bold);
                    lbl.ForeColor = Color.FromArgb(37, 99, 235);
                    return;
                }
                if (c.HasChildren) UpdateLabelTextRecursive(c, newText);
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
            DeepWindowsHooks.IsLocked = false;
            RemoveSecondaryScreens();

            Application.Restart();
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
    }
}