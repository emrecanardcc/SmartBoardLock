using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using System.Collections.Generic;
using KioskLockApp.Hooks;
using KioskLockApp.Services;
using QRCoder;
using Microsoft.Win32;

namespace KioskLockApp.UI
{
    public partial class SecureRenderer : Form
    {
        private System.Windows.Forms.Timer watchdogTimer;
        private System.Windows.Forms.Timer clockTimer;

        private string enteredPin = "";
        private bool isOfflineUnlocked = false;
        private string lastQrTime = "";

        // İkinci ve üçüncü ekranları kilitlemek için tutulan form listesi
        private List<Form> secondaryScreens = new List<Form>();

        public SecureRenderer()
        {
            DeepWindowsHooks.InitializeHooks();
            DisableTouchSwipes(); // Dokunmatik ekran kaydırmalarını kapat

            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.FromArgb(245, 247, 251);
            this.TopMost = true;
            this.ShowInTaskbar = false;

            // Odak kaybında kendini zorla öne alma tetikleyicisi
            this.Deactivate += SecureRenderer_Deactivate;
            this.FormClosing += SecureRenderer_FormClosing;

            BuildUI();

            clockTimer = new System.Windows.Forms.Timer { Interval = 1000 };
            clockTimer.Tick += ClockTimer_Tick;
            clockTimer.Start();
            ClockTimer_Tick(null, null);

            watchdogTimer = new System.Windows.Forms.Timer { Interval = 3000 };
            watchdogTimer.Tick += WatchdogTimer_Tick;
            watchdogTimer.Start();

            CoverOtherScreens(); // İkinci ekranları kilitle
            _ = UpdateManager.CheckAndApplyUpdatesAsync();
            CheckStatus();
        }

        // ==========================================
        // 1. YENİ MASAÜSTÜ / GÖREV GÖRÜNÜMÜNDEN GİZLEME
        // ==========================================
        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                // WS_EX_TOOLWINDOW: Formu Alt+Tab, Win+Tab ve Görev Görünümünden gizler
                cp.ExStyle |= 0x80;
                return cp;
            }
        }

        // ==========================================
        // 2. ODAK (FOCUS) KAYBINDA ZORLA ÖNE ALMA
        // ==========================================
        private void SecureRenderer_Deactivate(object sender, EventArgs e)
        {
            if (DeepWindowsHooks.IsLocked)
            {
                this.Activate();
                this.Focus();
                this.TopMost = true;
            }
        }

        // ==========================================
        // 3. İKİNCİL EKRANLARI (PROJEKSİYON) KİLİTLEME
        // ==========================================
        private void CoverOtherScreens()
        {
            foreach (var screen in Screen.AllScreens)
            {
                if (screen.Primary) continue; // Ana ekrana dokunma

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

        // ==========================================
        // 4. DOKUNMATİK KAYDIRMALARI (EDGE SWIPE) KAPATMA
        // ==========================================
        private void DisableTouchSwipes()
        {
            try
            {
                using (RegistryKey key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows\EdgeUI"))
                {
                    key.SetValue("AllowEdgeSwipe", 0, RegistryValueKind.DWord);
                }
            }
            catch { /* Yetki yoksa sessizce geç (Uygulama Administrator olarak başlatılmalı) */ }
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
            if (OfflineTotpEngine.VerifyPin(enteredPin))
            {
                isOfflineUnlocked = true;
                UnlockScreen();
                enteredPin = "";
            }
            else
            {
                lblPinDisplay.Text = "HATALI PIN";
                lblPinDisplay.ForeColor = Color.FromArgb(220, 38, 38);
                enteredPin = "";
                System.Threading.Tasks.Task.Delay(1000).ContinueWith(t => { this.Invoke(new Action(() => UpdatePinDisplay())); });
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
            RefreshQrCode();
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
            RemoveSecondaryScreens(); // Kilit açılınca diğer ekranları da serbest bırak
            this.Hide();
        }

        private void LockScreen()
        {
            DeepWindowsHooks.IsLocked = true;
            if (secondaryScreens.Count == 0 && Screen.AllScreens.Length > 1) CoverOtherScreens(); // Kilitlendiğinde ekran varsa kapat
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
}