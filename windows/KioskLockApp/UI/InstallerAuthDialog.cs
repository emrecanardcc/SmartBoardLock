using System;
using System.Drawing;
using System.Windows.Forms;
using KioskLockApp.Services;

namespace KioskLockApp.UI
{
    /// <summary>
    /// Kurulum veya kaldırma işlemleri başlatıldığında müdür güvenlik şifresini soran modal arayüz.
    /// Yanlış girilirse veya iptal edilirse işlem TerminateProcess ile sonlandırılır.
    /// </summary>
    public class InstallerAuthDialog : Form
    {
        private readonly string _processName;
        private readonly int _processId;
        private TextBox _txtPassword = null!;
        private CheckBox _chkRemember = null!;
        private Label _lblError = null!;
        private Button _btnConfirm = null!;
        private Button _btnCancel = null!;
        private int _failedAttempts = 0;

        public bool IsAuthorized { get; private set; } = false;
        public bool RememberSession => _chkRemember?.Checked ?? false;

        public InstallerAuthDialog(string processName, int processId)
        {
            _processName = processName;
            _processId = processId;

            InitializeCustomComponents();
        }

        private void InitializeCustomComponents()
        {
            this.Text = "Sınıf360 - Kurulum & Kaldırma Koruması";
            this.Size = new Size(500, 310);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.TopMost = true;
            this.ShowInTaskbar = true;
            this.BackColor = Color.White;
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            // Başlık Paneli
            Panel headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 65,
                BackColor = Color.FromArgb(248, 250, 252),
                Padding = new Padding(18, 12, 18, 12)
            };

            Label lblTitle = new Label
            {
                Text = "Müdür Güvenlik Şifresi Gerekli",
                Font = new Font("Segoe UI", 12f, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                AutoSize = true,
                Location = new Point(16, 12)
            };

            Label lblSubtitle = new Label
            {
                Text = "Bu bilgisayarda yetkisiz program kurmak ve kaldırmak yasaklanmıştır.",
                Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(100, 116, 139),
                AutoSize = true,
                Location = new Point(17, 36)
            };

            headerPanel.Controls.Add(lblTitle);
            headerPanel.Controls.Add(lblSubtitle);

            // Açıklama
            Label lblDesc = new Label
            {
                Text = $"Hedef Süreç: {_processName} (PID: {_processId})\nİşleme devam etmek için okul müdürünüzün belirlediği şifreyi giriniz:",
                Location = new Point(20, 80),
                Size = new Size(445, 40),
                ForeColor = Color.FromArgb(30, 41, 59),
                Font = new Font("Segoe UI", 9f, FontStyle.Regular)
            };

            // Şifre Kutusu
            _txtPassword = new TextBox
            {
                Location = new Point(20, 125),
                Size = new Size(445, 28),
                Font = new Font("Segoe UI", 11f, FontStyle.Bold),
                PasswordChar = '●',
                UseSystemPasswordChar = true
            };
            _txtPassword.KeyDown += (s, e) =>
            {
                if (e.KeyCode == Keys.Enter)
                {
                    e.SuppressKeyPress = true;
                    _btnConfirm.PerformClick();
                }
            };

            // Hata Etiketi
            _lblError = new Label
            {
                Location = new Point(20, 158),
                Size = new Size(445, 20),
                ForeColor = Color.FromArgb(220, 38, 38),
                Font = new Font("Segoe UI", 8.5f, FontStyle.Bold),
                Text = ""
            };

            // Hatırla Kutusu
            _chkRemember = new CheckBox
            {
                Text = "5 dakika boyunca yeni kurulumlara izin ver (Önerilen)",
                Location = new Point(20, 182),
                Size = new Size(445, 24),
                Checked = true,
                Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
                ForeColor = Color.FromArgb(71, 85, 105)
            };

            // Alt Butonlar
            _btnCancel = new Button
            {
                Text = "Engelle / İptal",
                Size = new Size(125, 36),
                Location = new Point(205, 218),
                BackColor = Color.FromArgb(241, 245, 249),
                ForeColor = Color.FromArgb(51, 65, 85),
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9f, FontStyle.Regular),
                Cursor = Cursors.Hand
            };
            _btnCancel.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
            _btnCancel.Click += (s, e) =>
            {
                IsAuthorized = false;
                this.DialogResult = DialogResult.Cancel;
                this.Close();
            };

            _btnConfirm = new Button
            {
                Text = "Onayla ve İzin Ver",
                Size = new Size(130, 36),
                Location = new Point(335, 218),
                BackColor = Color.FromArgb(79, 70, 229),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            _btnConfirm.FlatAppearance.BorderSize = 0;
            _btnConfirm.Click += OnConfirmClick;

            this.Controls.Add(headerPanel);
            this.Controls.Add(lblDesc);
            this.Controls.Add(_txtPassword);
            this.Controls.Add(_lblError);
            this.Controls.Add(_chkRemember);
            this.Controls.Add(_btnCancel);
            this.Controls.Add(_btnConfirm);

            this.AcceptButton = _btnConfirm;
            this.CancelButton = _btnCancel;

            this.Shown += (s, e) =>
            {
                _txtPassword.Focus();
            };
        }

        private void OnConfirmClick(object? sender, EventArgs e)
        {
            string entered = _txtPassword.Text.Trim();
            if (string.IsNullOrEmpty(entered))
            {
                _lblError.Text = "Lütfen müdür şifresini giriniz.";
                _txtPassword.Focus();
                return;
            }

            if (BoardSecurityStore.VerifyPassword(entered))
            {
                IsAuthorized = true;
                if (RememberSession)
                {
                    BoardSecurityStore.SetAuthorizedSession(TimeSpan.FromMinutes(5));
                }
                this.DialogResult = DialogResult.OK;
                this.Close();
            }
            else
            {
                _failedAttempts++;
                _txtPassword.SelectAll();
                _txtPassword.Focus();

                if (_failedAttempts >= 3)
                {
                    _lblError.Text = "3 kez hatalı şifre girildi. Kurulum süreci engelleniyor!";
                    _btnConfirm.Enabled = false;
                    _btnCancel.Enabled = false;
                    var timer = new System.Windows.Forms.Timer { Interval = 1200 };
                    timer.Tick += (ts, te) =>
                    {
                        timer.Stop();
                        timer.Dispose();
                        IsAuthorized = false;
                        this.DialogResult = DialogResult.Cancel;
                        this.Close();
                    };
                    timer.Start();
                }
                else
                {
                    _lblError.Text = $"Hatalı müdür şifresi! ({_failedAttempts}/3 deneme)";
                }
            }
        }
    }
}
