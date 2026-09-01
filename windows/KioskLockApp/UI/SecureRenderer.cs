using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using KioskLockApp.Hooks;
using KioskLockApp.Services;
using QRCoder;
using Microsoft.Win32;

namespace KioskLockApp.UI
{
    public class SecureRenderer : Form
    {
        private Label lblBoardName;
        private Label lblSchoolName;
        private Label lblPinDisplay;
        private Label lblCurrentPinCheat;
        private PictureBox pbQrCode;
        private System.Windows.Forms.Timer watchdogTimer;

        // --- SAAT İÇİN EKLENEN DEĞİŞKENLER ---
        private Label lblClock;
        private System.Windows.Forms.Timer clockTimer;

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

            // --- SAAT ZAMANLAYICISI ---
            clockTimer = new System.Windows.Forms.Timer();
            clockTimer.Interval = 1000;
            clockTimer.Tick += ClockTimer_Tick;
            clockTimer.Start();

            watchdogTimer = new System.Windows.Forms.Timer();
            watchdogTimer.Interval = 3000;
            watchdogTimer.Tick += WatchdogTimer_Tick;
            watchdogTimer.Start();

            // ==========================================
            // YENİ: SESSİZ GÜNCELLEME KONTROLÜNÜ BAŞLAT
            // ==========================================
            _ = UpdateManager.CheckAndApplyUpdatesAsync();

            CheckStatus();
        }

        // --- REGISTRY'DEN OKUL ADINI OKU ---
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
            return "İSİMSİZ OKUL";
        }

        // --- REGISTRY'DEN TAHTA ADINI OKU ---
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
            return "İSİMSİZ TAHTA";
        }

        private void BuildUI()
        {
            int screenWidth = Screen.PrimaryScreen.Bounds.Width;
            int screenHeight = Screen.PrimaryScreen.Bounds.Height;

            // --- SAĞ %40'LIK PANEL HESAPLAMASI ---
            int panelWidth = (int)(screenWidth * 0.40);
            int panelX = screenWidth - panelWidth;
            int centerX = panelX + (panelWidth / 2);

            // 1. OKUL İSMİ (En Üstte)
            lblSchoolName = new Label()
            {
                Text = GetSavedSchoolName().ToUpper(),
                ForeColor = Color.White,
                Font = new Font("Arial", 28, FontStyle.Bold),
                AutoSize = false,
                Size = new Size(panelWidth, 50),
                Location = new Point(panelX, 60),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(lblSchoolName);

            // 2. SINIF / TAHTA İSMİ (Okulun Altında)
            lblBoardName = new Label()
            {
                Text = GetSavedBoardName(),
                ForeColor = Color.Cyan,
                Font = new Font("Arial", 20, FontStyle.Bold),
                AutoSize = false,
                Size = new Size(panelWidth, 40),
                Location = new Point(panelX, 120),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(lblBoardName);

            // 3. QR KOD (Tahta isminin altında)
            int qrSize = 220; // Dikeyde sığması için optimize edildi
            pbQrCode = new PictureBox()
            {
                Size = new Size(qrSize, qrSize),
                Location = new Point(centerX - (qrSize / 2), 190),
                SizeMode = PictureBoxSizeMode.StretchImage,
                BackColor = Color.White
            };
            this.Controls.Add(pbQrCode);

            Label lblQrInfo = new Label()
            {
                Text = "Mobil Uygulama İle Okutun",
                ForeColor = Color.LightGray,
                Font = new Font("Arial", 14, FontStyle.Bold),
                AutoSize = false,
                Size = new Size(panelWidth, 30),
                Location = new Point(panelX, 420),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(lblQrInfo);

            // 4. GİRİLEN PIN GÖSTERGESİ
            lblPinDisplay = new Label()
            {
                Text = "- - - - - -",
                ForeColor = Color.Yellow,
                Font = new Font("Arial", 32, FontStyle.Bold),
                AutoSize = false,
                Size = new Size(panelWidth, 50),
                Location = new Point(panelX, 480),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(lblPinDisplay);

            // 5. TUŞ TAKIMI (NUMPAD) (Pin göstergesinin altında)
            int btnSize = 75;
            int padding = 12;
            int numpadWidth = (3 * btnSize) + (2 * padding);
            int startX = centerX - (numpadWidth / 2);
            int startY = 550; // Numpad'in dikeydeki başlangıç noktası

            for (int i = 1; i <= 9; i++)
            {
                Button btn = new Button() { Text = i.ToString(), Size = new Size(btnSize, btnSize), Font = new Font("Arial", 24, FontStyle.Bold), BackColor = Color.FromArgb(40, 40, 40), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
                btn.Location = new Point(startX + ((i - 1) % 3) * (btnSize + padding), startY + ((i - 1) / 3) * (btnSize + padding));
                btn.Click += Numpad_Click;
                this.Controls.Add(btn);
            }

            Button btn0 = new Button() { Text = "0", Size = new Size(btnSize, btnSize), Font = new Font("Arial", 24, FontStyle.Bold), BackColor = Color.FromArgb(40, 40, 40), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Location = new Point(startX + (btnSize + padding), startY + 3 * (btnSize + padding)) };
            btn0.Click += Numpad_Click;
            this.Controls.Add(btn0);

            Button btnClear = new Button() { Text = "C", Size = new Size(btnSize, btnSize), Font = new Font("Arial", 24, FontStyle.Bold), BackColor = Color.IndianRed, ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Location = new Point(startX + 2 * (btnSize + padding), startY + 3 * (btnSize + padding)) };
            btnClear.Click += (s, e) => { enteredPin = ""; UpdatePinDisplay(); };
            this.Controls.Add(btnClear);

            // 6. BİLGİSAYARI KAPAT BUTONU (Tuş takımının en altında)
            Button btnKapat = new Button();
            btnKapat.Text = "Bilgisayarı Kapat";
            btnKapat.Size = new Size(220, 50);
            btnKapat.BackColor = Color.DarkRed;
            btnKapat.ForeColor = Color.White;
            btnKapat.Font = new Font("Arial", 12, FontStyle.Bold);
            btnKapat.FlatStyle = FlatStyle.Flat;
            btnKapat.Cursor = Cursors.Hand;
            btnKapat.Location = new Point(centerX - (btnKapat.Width / 2), startY + 4 * (btnSize + padding) + 20);
            btnKapat.Click += (sender, e) => { System.Diagnostics.Process.Start("shutdown", "/s /f /t 0"); };
            this.Controls.Add(btnKapat);

            // GİZLİ TEST KOPYA PIN (Ekranın en alt sağ köşesine saklandı)
            lblCurrentPinCheat = new Label() { ForeColor = Color.FromArgb(30, 30, 30), Font = new Font("Arial", 8), AutoSize = true, Location = new Point(screenWidth - 150, screenHeight - 30) };
            this.Controls.Add(lblCurrentPinCheat);

            // --- SAAT TASARIMI (Ekranın sol üst köşesine alındı) ---
            lblClock = new Label()
            {
                AutoSize = true,
                Font = new Font("Segoe UI", 36F, FontStyle.Bold),
                ForeColor = Color.White,
                BackColor = Color.Transparent,
                TextAlign = ContentAlignment.TopLeft
            };
            this.Controls.Add(lblClock);

            // ==========================================
            // YENİ: UYGULAMA SÜRÜMÜNÜ EKRANA YAZDIR (Sol Alt Köşe)
            // ==========================================
            try
            {
                string currentVersion = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString();

                // "1.0.0.0" ise son sıfırı atıp "1.0.0" göstermesi için
                if (currentVersion.EndsWith(".0"))
                {
                    currentVersion = currentVersion.Substring(0, currentVersion.Length - 2);
                }

                Label lblVersion = new Label()
                {
                    Text = "v" + currentVersion,
                    ForeColor = Color.Gray, // Siyah ekranda net görünen ama göz yormayan gri
                    Font = new Font("Arial", 11, FontStyle.Bold),
                    AutoSize = true,
                    Location = new Point(30, screenHeight - 50), // Sol alt köşe
                    BackColor = Color.Transparent
                };
                this.Controls.Add(lblVersion);
            }
            catch { }

            RefreshQrCode();
        }

        // --- SAAT GÜNCELLEME METODU ---
        private void ClockTimer_Tick(object sender, EventArgs e)
        {
            lblClock.Text = DateTime.Now.ToString("HH:mm:ss\ndd MMMM yyyy dddd");
            // Saati sol üst köşede boşluğa sabitliyoruz
            lblClock.Location = new Point(50, 50);
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
            lblCurrentPinCheat.Text = "(Test: " + OfflineTotpEngine.GetCurrentPin() + ")";
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
            catch (Exception)
            {
            }
        }

        private void SecureRenderer_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing) e.Cancel = true;
        }
    }
}