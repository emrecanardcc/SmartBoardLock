using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using KioskLockApp.Hooks;
using KioskLockApp.Services;
using QRCoder;

namespace KioskLockApp.UI
{
    public class SecureRenderer : Form
    {
        private Label lblInfo;
        private Label lblPinDisplay;
        private Label lblCurrentPinCheat;
        private PictureBox pbQrCode;
        private System.Windows.Forms.Timer watchdogTimer;

        private string enteredPin = "";
        private bool isOfflineUnlocked = false;
        private string lastQrTime = "";

        public SecureRenderer()
        {
            DeepWindowsHooks.InitializeHooks();

            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.BackColor = Color.Black;
            this.TopMost = true;
            this.ShowInTaskbar = false;
            this.FormClosing += SecureRenderer_FormClosing;

            BuildUI();

            watchdogTimer = new System.Windows.Forms.Timer();
            watchdogTimer.Interval = 3000;
            watchdogTimer.Tick += WatchdogTimer_Tick;
            watchdogTimer.Start();

            CheckStatus(); // EKSİK OLAN METOT ÇAĞRISI BURADA
        }

        private void BuildUI()
        {
            // --- SOL TARAF: ÇEVRİMDIŞI TUŞ TAKIMI ---
            lblInfo = new Label() { Text = "AKILLI TAHTA KİLİTLİ", ForeColor = Color.White, Font = new Font("Arial", 24, FontStyle.Bold), AutoSize = true, Location = new Point(100, 100) };
            this.Controls.Add(lblInfo);

            lblCurrentPinCheat = new Label() { ForeColor = Color.Gray, Font = new Font("Arial", 16), AutoSize = true, Location = new Point(100, 150) };
            this.Controls.Add(lblCurrentPinCheat);

            lblPinDisplay = new Label() { Text = "- - - - - -", ForeColor = Color.Yellow, Font = new Font("Arial", 36, FontStyle.Bold), AutoSize = true, Location = new Point(100, 220) };
            this.Controls.Add(lblPinDisplay);

            int startX = 100;
            int startY = 300;
            int btnSize = 90;
            int padding = 10;

            for (int i = 1; i <= 9; i++)
            {
                Button btn = new Button() { Text = i.ToString(), Size = new Size(btnSize, btnSize), Font = new Font("Arial", 28, FontStyle.Bold), BackColor = Color.FromArgb(40, 40, 40), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
                btn.Location = new Point(startX + ((i - 1) % 3) * (btnSize + padding), startY + ((i - 1) / 3) * (btnSize + padding));
                btn.Click += Numpad_Click;
                this.Controls.Add(btn);
            }

            Button btn0 = new Button() { Text = "0", Size = new Size(btnSize, btnSize), Font = new Font("Arial", 28, FontStyle.Bold), BackColor = Color.FromArgb(40, 40, 40), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Location = new Point(startX + (btnSize + padding), startY + 3 * (btnSize + padding)) };
            btn0.Click += Numpad_Click;
            this.Controls.Add(btn0);

            Button btnClear = new Button() { Text = "C", Size = new Size(btnSize, btnSize), Font = new Font("Arial", 28, FontStyle.Bold), BackColor = Color.IndianRed, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Location = new Point(startX + 2 * (btnSize + padding), startY + 3 * (btnSize + padding)) };
            btnClear.Click += (s, e) => { enteredPin = ""; UpdatePinDisplay(); };
            this.Controls.Add(btnClear);

            // --- SAĞ TARAF: DİNAMİK QR KOD ---
            pbQrCode = new PictureBox()
            {
                Size = new Size(400, 400),
                Location = new Point(700, 300),
                SizeMode = PictureBoxSizeMode.StretchImage,
                BackColor = Color.White
            };
            this.Controls.Add(pbQrCode);

            Label lblQrInfo = new Label() { Text = "Mobil Uygulama İle Okutun", ForeColor = Color.White, Font = new Font("Arial", 18, FontStyle.Bold), AutoSize = true, Location = new Point(740, 250) };
            this.Controls.Add(lblQrInfo);

            RefreshQrCode();
        }

        private void RefreshQrCode()
        {
            string currentMinute = DateTime.UtcNow.ToString("yyyyMMddHHmm");
            if (currentMinute == lastQrTime) return;

            string payload = DynamicQrEngine.GenerateQrPayload();

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
                Button clickedBtn = sender as Button;
                enteredPin += clickedBtn.Text;
                UpdatePinDisplay();

                if (enteredPin.Length == 6)
                {
                    if (OfflineTotpEngine.VerifyPin(enteredPin))
                    {
                        isOfflineUnlocked = true;
                        UnlockScreen();
                        enteredPin = "";
                    }
                    else
                    {
                        lblPinDisplay.Text = "HATALI!";
                        lblPinDisplay.ForeColor = Color.Red;
                        enteredPin = "";
                        System.Threading.Tasks.Task.Delay(1000).ContinueWith(t => { this.Invoke(new Action(() => UpdatePinDisplay())); });
                    }
                }
            }
        }

        private void UpdatePinDisplay()
        {
            lblPinDisplay.ForeColor = Color.Yellow;
            string paddedPin = enteredPin.PadRight(6, '-');
            lblPinDisplay.Text = string.Join(" ", paddedPin.ToCharArray());
        }

        private async void WatchdogTimer_Tick(object sender, EventArgs e)
        {
            lblCurrentPinCheat.Text = "(Test Kopya PIN: " + OfflineTotpEngine.GetCurrentPin() + ")";
            RefreshQrCode();
            await CheckStatusAsync();
        }

        // EKLENEN ARA METOT BURASI
        private async void CheckStatus()
        {
            await CheckStatusAsync();
        }

        private async System.Threading.Tasks.Task CheckStatusAsync()
        {
            EnsureWatchdogIsAlive();

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

        private void UnlockScreen()
        {
            DeepWindowsHooks.IsLocked = false;
            this.Hide();
        }

        private void LockScreen()
        {
            DeepWindowsHooks.IsLocked = true;
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