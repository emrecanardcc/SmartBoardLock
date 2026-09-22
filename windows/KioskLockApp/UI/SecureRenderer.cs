using KioskLockApp.Hooks;
using KioskLockApp.Services;
using Microsoft.Win32;
using Postgrest.Attributes; // DÜZELTME: Supabase. öneki silindi
using Postgrest.Models; // DÜZELTME: Supabase. öneki silindi
using QRCoder;
using Supabase.Realtime;
using Supabase.Realtime.PostgresChanges; // YENİ: ListenType için eklendi
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace KioskLockApp.UI
{
    public partial class SecureRenderer : Form
    {
        private System.Windows.Forms.Timer watchdogTimer;
        private System.Windows.Forms.Timer clockTimer;

        private string enteredPin = "";
        private bool isOfflineUnlocked = false;
        private string lastQrTime = "";

        private List<Form> secondaryScreens = new List<Form>();
        private string currentChallengeCode = "";

        private Supabase.Client realtimeClient;
        private RealtimeChannel boardChannel;

        public SecureRenderer()
        {
            DeepWindowsHooks.InitializeHooks();
            DisableTouchSwipes();

            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251);
            this.TopMost = true;
            this.ShowInTaskbar = false;

            this.Deactivate += SecureRenderer_Deactivate;
            this.FormClosing += SecureRenderer_FormClosing;

            BuildUI();

            currentChallengeCode = OfflineTotpEngine.GenerateChallengeCode();
            UpdateChallengeDisplay();

            clockTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            clockTimer.Tick += ClockTimer_Tick;
            clockTimer.Start();
            ClockTimer_Tick(null, null);

            watchdogTimer = new System.Windows.Forms.Timer { Interval = 60000 };
            watchdogTimer.Tick += WatchdogTimer_Tick;
            watchdogTimer.Start();

            CoverOtherScreens();
            _ = UpdateManager.CheckAndApplyUpdatesAsync();
            CheckStatus();

            _ = InitializeRealtimeListenerAsync();
        }

        private async System.Threading.Tasks.Task InitializeRealtimeListenerAsync()
        {
            try
            {
                string boardId = SecureSupabase.GetRegistryValue("BoardId");
                if (string.IsNullOrEmpty(boardId)) return;

                string url = "https://clkasnbpmhddhstoixdz.supabase.co";
                string key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsa2FzbmJwbWhkZGhzdG9peGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5ODc4ODQsImV4cCI6MjA5ODU2Mzg4NH0.KpwOZoWwOu2DfwOec0y5LSvS6MRGGy4Uqot-Q1G0_x8";

                var options = new Supabase.SupabaseOptions { AutoConnectRealtime = true };
                realtimeClient = new Supabase.Client(url, key, options);
                await realtimeClient.InitializeAsync();

                boardChannel = realtimeClient.Realtime.Channel("realtime", "public", "boards");

                // TAM YOL DÜZELTMESİ BURADA:
                boardChannel.AddPostgresChangeHandler(
                    Supabase.Realtime.PostgresChanges.PostgresChangesOptions.ListenType.Updates,
                    (sender, change) =>
                    {
                        // Gelen JSON verisini doğrudan Model'imize çeviriyoruz
                        var record = change.Model<BoardRealtimeModel>();

                        // Değişiklik bizim tahtamızın ID'sine mi ait?
                        if (record != null && record.Id == boardId)
                        {
                            this.Invoke(new Action(() => {
                                if (record.IsUnlocked)
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
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("Realtime hatası: " + ex.Message);
            }
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

        private void SecureRenderer_Deactivate(object sender, EventArgs e)
        {
            if (DeepWindowsHooks.IsLocked)
            {
                this.Activate();
                this.Focus();
                this.TopMost = true;
            }
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
                if (screen != null && !screen.IsDisposed)
                {
                    screen.Close();
                }
            }
            secondaryScreens.Clear();
        }

        private void DisableTouchSwipes()
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows\EdgeUI"))
                {
                    key.SetValue("AllowEdgeSwipe", 0, RegistryValueKind.DWord);
                }
            }
            catch { }
        }

        private string GetSavedSchoolName()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    if (key != null)
                    {
                        object val = key.GetValue("SchoolName");
                        if (val != null) return val.ToString().Trim();
                    }
                }
            }
            catch { }
            return "Balakgazi Anadolu Lisesi";
        }

        private string GetSavedBoardName()
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock"))
                {
                    if (key != null)
                    {
                        object val = key.GetValue("BoardName");
                        if (val != null) return val.ToString().Trim();
                    }
                }
            }
            catch { }
            return "11 - A Sınıfı";
        }

       private void ClockTimer_Tick(object sender, EventArgs e)
{
    if (lblTime != null) lblTime.Text = DateTime.Now.ToString("HH:mm");
    if (lblDate != null) lblDate.Text = DateTime.Now.ToString("dd MMMM yyyy, dddd");
    
    // Karekodu buraya taşıyoruz. İlk açılışta anında ekrana gelir.
    RefreshQrCode(); 
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

        private void Numpad_Click(object sender, EventArgs e)
        {
            if (enteredPin.Length < 6)
            {
                FluentButton clickedBtn = sender as FluentButton;
                if (clickedBtn != null)
                {
                    enteredPin += clickedBtn.Text;
                    UpdatePinDisplay();

                    if (enteredPin.Length == 6)
                    {
                        VerifyPinLogic();
                    }
                }
            }
        }

        private void VerifyPinLogic()
        {
            if (OfflineTotpEngine.VerifyPin(enteredPin, currentChallengeCode))
            {
                isOfflineUnlocked = true;
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
                if (c.HasChildren)
                {
                    UpdateLabelTextRecursive(c, newText);
                }
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
                for (int i = 0; i < 6; i++)
                {
                    if (i < enteredPin.Length) display += "●  ";
                    else display += "○  ";
                }
                lblPinDisplay.Text = display.Trim();
            }
        }

        private async void WatchdogTimer_Tick(object sender, EventArgs e)
        {
            await CheckStatusAsync();
        }

        private async void CheckStatus()
        {
            await CheckStatusAsync();
        }

        private async System.Threading.Tasks.Task CheckStatusAsync()
        {
            EnsureWatchdogIsAlive();

            bool isDeleted = await SecureSupabase.IsBoardDeletedAsync();
            if (isDeleted)
            {
                ResetToPairingMode();
                return;
            }

            bool? isUnlocked = await SecureSupabase.CheckIfUnlockedAsync();

            if (isUnlocked == true)
            {
                isOfflineUnlocked = false;
                UnlockScreen();
            }
            else if (isUnlocked == false)
            {
                isOfflineUnlocked = false;
                LockScreen();
            }
            else if (isUnlocked == null)
            {
                if (isOfflineUnlocked) UnlockScreen();
                else LockScreen();
            }
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

            DeepWindowsHooks.IsLocked = false;
            RemoveSecondaryScreens();

            Application.Restart();
            Environment.Exit(0);
        }

        private void UnlockScreen()
        {
            DeepWindowsHooks.IsLocked = false;
            RemoveSecondaryScreens();
            this.Hide();
        }

        private void LockScreen()
        {
            DeepWindowsHooks.IsLocked = true;
            if (secondaryScreens.Count == 0 && Screen.AllScreens.Length > 1) CoverOtherScreens();
            this.Show();
        }

        private void EnsureWatchdogIsAlive()
        {
            try
            {
                Process[] processes = Process.GetProcessesByName("WatchdogService");
                if (processes.Length == 0)
                {
                    string watchdogPath = Path.Combine(Application.StartupPath, "WatchdogService.exe");
                    if (File.Exists(watchdogPath))
                    {
                        ProcessStartInfo startInfo = new ProcessStartInfo(watchdogPath) { UseShellExecute = true, WorkingDirectory = Application.StartupPath };
                        Process.Start(startInfo);
                    }
                }
            }
            catch { }
        }

        private void SecureRenderer_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing) e.Cancel = true;
        }
    }

    [Table("boards")]
    public class BoardRealtimeModel : BaseModel
    {
        [Column("id")]
        public string Id { get; set; }

        [Column("is_unlocked")]
        public bool IsUnlocked { get; set; }
    }
}