using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using KioskLockApp.Services;

namespace KioskLockApp.UI
{
    public partial class SecureRenderer
    {
        private readonly Color ColBg = Color.FromArgb(245, 247, 251);
        private readonly Color ColCard = Color.FromArgb(255, 255, 255);
        private readonly Color ColTextMain = Color.FromArgb(17, 24, 39);
        private readonly Color ColTextSec = Color.FromArgb(107, 114, 128);
        private readonly Color ColPrimary = Color.FromArgb(37, 99, 235);
        private readonly Color ColPrimaryHover = Color.FromArgb(29, 78, 216);
        private readonly Color ColBorder = Color.FromArgb(229, 231, 235);
        private readonly Color ColDanger = Color.FromArgb(220, 38, 38);

        // Header kontrolleri
        private Label lblBrand;
        private Label lblLicenseBadge;
        private string appVersion = "2.1.4";
        private Label lblTime;
        private Label lblDate;

        // Giriş kartı kontrolleri
        private Label lblLogo;
        private Label lblSchool;
        private Label lblBoard;
        private PictureBox pbQrCode;
        private Label lblQrTitle;
        private Label lblQrSub;
        private Label lblVersion;
        private Label lblPinTitle;
        private Label lblPinDisplay;
        private Label lblPinSub;

        // Afiş ve Duyuru Kontrolleri
        private Label lblAfisTitle;
        private Label lblAfisSub;
        private PictureBox pbPoster;
        private Label lblPosterCounter;

        private Label lblDuyuruTitle;
        private Label lblDuyuruSub;
        private FlowLayoutPanel pnlAnnouncementsList;
        private int currentPosterIndex = 0;
        private List<string> activePosterPaths = new List<string>();
        private int announcementPageIndex = 0;
        private List<MediaItem> cachedAnnouncements = new List<MediaItem>();

        // Layout Konteynerleri
        private TableLayoutPanel root;
        private TableLayoutPanel mainGrid;
        private TableLayoutPanel loginLayout;
        private TableLayoutPanel numpadWrapper;
        private TableLayoutPanel numpadGrid;
        private List<FluentButton> numpadButtons = new List<FluentButton>();
        private FluentButton btnPower;

        private float DpiScale => this.DeviceDpi / 96f;
        private int S(int px) => (int)Math.Round(px * DpiScale);

        private void BuildUI()
        {
            this.DoubleBuffered = true;
            this.SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
            this.UpdateStyles();

            root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            root.GetType().GetProperty("DoubleBuffered", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)?.SetValue(root, true);
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 8F));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 82F));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 10F));
            this.Controls.Add(root);

            // ==================== HEADER ====================
            TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(30), 0, S(30), 0) };
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));

            lblBrand = new Label
            {
                Text = "Sınıf360",
                Font = new Font("Segoe UI", 22, FontStyle.Bold),
                ForeColor = ColPrimary,
                AutoSize = false,
                AutoEllipsis = true,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleLeft
            };
            header.Controls.Add(lblBrand, 0, 0);

            lblLicenseBadge = new Label
            {
                Text = "⛔ LİSANS SÜRESİ DOLDU - TAHTA KİLİTLİDİR",
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                ForeColor = Color.White,
                BackColor = ColDanger,
                AutoSize = false,
                AutoEllipsis = true,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleCenter,
                Visible = false,
                Margin = new Padding(S(10), S(6), S(10), S(6))
            };
            header.Controls.Add(lblLicenseBadge, 1, 0);

            root.Controls.Add(header, 0, 0);

            // ==================== MAIN GRID ====================
            mainGrid = new TableLayoutPanel { Name = "mainGrid", Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(15), 0, S(15), 0) };
            mainGrid.GetType().GetProperty("DoubleBuffered", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)?.SetValue(mainGrid, true);
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38F));
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 32F));
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
            mainGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            root.Controls.Add(mainGrid, 0, 1);

            mainGrid.Controls.Add(BuildAfisPanel(), 0, 0);
            mainGrid.Controls.Add(BuildDuyuruPanel(), 1, 0);

            // ==================== LOGIN CARD ====================
            FluentCard cardLogin = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };
            loginLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 5, ColumnCount = 1, Padding = new Padding(S(6)) };
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 14F)); // Okul / Tahta
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 38F)); // QR Kodu
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 1.5F)); // Ayırıcı çizgi
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 13.5F)); // PIN Başlık / Noktalar
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 33F)); // Numpad
            cardLogin.Controls.Add(loginLayout);

            // --- Okul Bilgisi ---
            TableLayoutPanel pnlSchoolInfo = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 38F));
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 38F));
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 24F));

            lblLogo = new Label { Text = "🏫", Font = new Font("Segoe UI", 22), AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter, ForeColor = ColPrimary };
            lblSchool = new Label { Text = GetSavedSchoolName().ToUpper(), Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };
            lblBoard = new Label { Text = GetSavedBoardName(), Font = new Font("Segoe UI", 11, FontStyle.Bold), ForeColor = ColPrimary, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };

            pnlSchoolInfo.Controls.Add(lblLogo, 0, 0);
            pnlSchoolInfo.Controls.Add(lblSchool, 0, 1);
            pnlSchoolInfo.Controls.Add(lblBoard, 0, 2);
            loginLayout.Controls.Add(pnlSchoolInfo, 0, 0);

            // --- QR Alanı ---
            TableLayoutPanel pnlQrArea = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 14F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 58F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 14F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 14F));

            lblQrTitle = new Label { Text = "Mobil uygulamaya bağlan", Font = new Font("Segoe UI", 10.5f, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter };
            pbQrCode = new PictureBox { SizeMode = PictureBoxSizeMode.Zoom, Dock = DockStyle.Fill, Margin = new Padding(S(4)) };
            lblQrSub = new Label { Text = "Uygulamadaki 'Karekod Okut' butonunu kullanın", Font = new Font("Segoe UI", 8.5f), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };

            try
            {
                var ver = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
                if (ver != null) appVersion = $"{ver.Major}.{ver.Minor}.{ver.Build}";
            }
            catch { }

            lblVersion = new Label { Text = "v" + appVersion, Font = new Font("Segoe UI", 7.5f, FontStyle.Regular), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };

            pnlQrArea.Controls.Add(lblQrTitle, 0, 0);
            pnlQrArea.Controls.Add(pbQrCode, 0, 1);
            pnlQrArea.Controls.Add(lblQrSub, 0, 2);
            pnlQrArea.Controls.Add(lblVersion, 0, 3);
            loginLayout.Controls.Add(pnlQrArea, 0, 1);

            // --- Ayırıcı Çizgi ---
            Panel separator = new Panel { Dock = DockStyle.Fill };
            separator.Paint += (s, e) =>
            {
                int pad = Math.Max(10, S(30));
                e.Graphics.DrawLine(new Pen(ColBorder), pad, separator.Height / 2, separator.Width - pad, separator.Height / 2);
            };
            loginLayout.Controls.Add(separator, 0, 2);

            // --- PIN Gösterge Alanı ---
            TableLayoutPanel pnlPinTop = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));

            lblPinTitle = new Label { Text = "PIN GİRİŞİ", Font = new Font("Segoe UI", 9.5f, FontStyle.Bold), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter };
            lblPinDisplay = new Label { Text = "○  ○  ○  ○  ○  ○", Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };
            lblPinSub = new Label { Text = "İnternet yoksa 'Çevrimdışı Şifre' alabilirsiniz", Font = new Font("Segoe UI", 8), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };

            pnlPinTop.Controls.Add(lblPinTitle, 0, 0);
            pnlPinTop.Controls.Add(lblPinDisplay, 0, 1);
            pnlPinTop.Controls.Add(lblPinSub, 0, 2);
            loginLayout.Controls.Add(pnlPinTop, 0, 3);

            // --- Numpad Wrapper & Grid ---
            numpadWrapper = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3 };
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 8F));
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 84F));
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 8F));

            numpadGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 3 };
            for (int i = 0; i < 3; i++) numpadGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            for (int i = 0; i < 4; i++) numpadGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));

            numpadButtons.Clear();
            for (int i = 1; i <= 9; i++)
            {
                var btn = CreateNumpadButton(i.ToString());
                numpadButtons.Add(btn);
                numpadGrid.Controls.Add(btn, (i - 1) % 3, (i - 1) / 3);
            }

            FluentButton btnClear = CreateNumpadButton("⌫");
            btnClear.Click -= Numpad_Click;
            btnClear.Click += (s, e) => { enteredPin = ""; UpdatePinDisplay(); };
            numpadButtons.Add(btnClear);

            FluentButton btnZero = CreateNumpadButton("0");
            numpadButtons.Add(btnZero);

            FluentButton btnEnter = CreateNumpadButton("✓");
            btnEnter.DefaultBackColor = ColPrimary;
            btnEnter.HoverBackColor = ColPrimaryHover;
            btnEnter.ForeColor = Color.White;
            btnEnter.HoverForeColor = Color.White;
            btnEnter.Click -= Numpad_Click;
            btnEnter.Click += (s, e) => VerifyPinLogic();
            numpadButtons.Add(btnEnter);

            numpadGrid.Controls.Add(btnClear, 0, 3);
            numpadGrid.Controls.Add(btnZero, 1, 3);
            numpadGrid.Controls.Add(btnEnter, 2, 3);

            numpadWrapper.Controls.Add(numpadGrid, 1, 0);
            loginLayout.Controls.Add(numpadWrapper, 0, 4);

            mainGrid.Controls.Add(cardLogin, 2, 0);

            // ==================== FOOTER ====================
            TableLayoutPanel footer = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(30), 0, S(30), S(10)) };
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));

            footer.Controls.Add(new Panel { Dock = DockStyle.Fill }, 0, 0);

            Panel pnlPowerWrapper = new Panel { Dock = DockStyle.Fill };
            btnPower = new FluentButton(S(8))
            {
                Text = "⏻ Sistemi Kapat",
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                Size = new Size(S(150), S(34)),
                DefaultBackColor = Color.Transparent,
                HoverBackColor = Color.FromArgb(254, 226, 226),
                ForeColor = ColTextSec,
                HoverForeColor = ColDanger,
            };
            pnlPowerWrapper.Resize += (s, e) =>
            {
                btnPower.Location = new Point(
                    Math.Max(0, (pnlPowerWrapper.ClientSize.Width - btnPower.Width) / 2),
                    Math.Max(0, (pnlPowerWrapper.ClientSize.Height - btnPower.Height) / 2)
                );
            };
            btnPower.Click += (s, e) => Process.Start("shutdown", "/s /f /t 0");
            pnlPowerWrapper.Controls.Add(btnPower);
            footer.Controls.Add(pnlPowerWrapper, 1, 0);

            root.Controls.Add(footer, 0, 2);

            // Dinamik Boyutlandırma ve Düzen Olayları
            this.Resize += (s, e) => ApplyDynamicSizing();
            this.SizeChanged += (s, e) => ApplyDynamicSizing();
        }

        private Control BuildAfisPanel()
        {
            FluentCard card = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };
            TableLayoutPanel layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1, Padding = new Padding(S(14)) };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, S(56)));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));

            TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 2 };
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 80F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 20F));
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 60F));
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 40F));

            lblAfisTitle = new Label { Text = "AFİŞLER", Font = new Font("Segoe UI", 17, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomLeft };
            lblAfisSub = new Label { Text = "Etkinlikler ve Bilgilendirme", Font = new Font("Segoe UI", 10.5f), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopLeft };

            header.Controls.Add(lblAfisTitle, 0, 0);
            header.Controls.Add(lblAfisSub, 0, 1);

            lblPosterCounter = new Label { Text = "0/0", Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = ColPrimary, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleRight };
            header.Controls.Add(lblPosterCounter, 1, 0);

            layout.Controls.Add(header, 0, 0);

            pbPoster = new AspectFillPictureBox
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(241, 245, 249),
                Margin = new Padding(0, S(6), 0, 0)
            };
            layout.Controls.Add(pbPoster, 0, 1);

            card.Controls.Add(layout);
            return card;
        }

        private Control BuildDuyuruPanel()
        {
            FluentCard card = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };
            TableLayoutPanel layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1, Padding = new Padding(S(14)) };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, S(88)));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));

            TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 2 };
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 58F));
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 42F));

            lblDuyuruTitle = new Label { Text = "DUYURULAR", Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomLeft };
            lblDuyuruSub = new Label { Text = "Güncel Okul Duyuruları", Font = new Font("Segoe UI", 11f), ForeColor = ColTextSec, AutoSize = false, AutoEllipsis = true, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopLeft };
            header.Controls.Add(lblDuyuruTitle, 0, 0);
            header.Controls.Add(lblDuyuruSub, 0, 1);

            lblTime = new Label
            {
                Font = new Font("Segoe UI", 24, FontStyle.Bold),
                ForeColor = ColTextMain,
                AutoSize = false,
                AutoEllipsis = true,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.BottomRight,
                Text = DateTime.Now.ToString("HH:mm")
            };
            lblDate = new Label
            {
                Font = new Font("Segoe UI", 11, FontStyle.Regular),
                ForeColor = ColTextSec,
                AutoSize = false,
                AutoEllipsis = true,
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.TopRight,
                Text = DateTime.Now.ToString("dd MMMM yyyy, dddd")
            };
            header.Controls.Add(lblTime, 1, 0);
            header.Controls.Add(lblDate, 1, 1);

            layout.Controls.Add(header, 0, 0);

            pnlAnnouncementsList = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoScroll = false, // KESİNLİKLE scrollbar / slidebar olmayacak
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                Padding = new Padding(0, S(4), 0, 0),
                BackColor = Color.Transparent
            };
            pnlAnnouncementsList.Resize += (s, e) => RenderAnnouncementCards();
            layout.Controls.Add(pnlAnnouncementsList, 0, 1);

            card.Controls.Add(layout);
            return card;
        }

        public void ApplyDynamicSizing(int simulatedWidth = 0, int simulatedHeight = 0)
        {
            int w = simulatedWidth > 0 ? simulatedWidth : this.ClientSize.Width;
            int h = simulatedHeight > 0 ? simulatedHeight : this.ClientSize.Height;
            if (w <= 100 || h <= 100) return;

            float scaleH = Math.Max(0.65f, Math.Min(1.8f, h / 1080f));
            float scaleW = Math.Max(0.65f, Math.Min(1.8f, w / 1920f));
            float uniformScale = Math.Min(scaleW, scaleH);
            float aspect = (float)w / Math.Max(1, h);

            // 1. Ana Grid Sütun Oranları (Aspect Ratio ve Genişlik Uyarlaması)
            if (mainGrid != null)
            {
                mainGrid.SuspendLayout();
                if (aspect < 1.45f) // 4:3, 5:4 veya dar ekranlar
                {
                    mainGrid.ColumnStyles[0].Width = 34F;
                    mainGrid.ColumnStyles[1].Width = 31F;
                    mainGrid.ColumnStyles[2].Width = 35F; // Giriş kartı sıkışmasın
                    if (numpadWrapper != null)
                    {
                        numpadWrapper.ColumnStyles[0].Width = 3F;
                        numpadWrapper.ColumnStyles[1].Width = 94F;
                        numpadWrapper.ColumnStyles[2].Width = 3F;
                    }
                }
                else // Standart 16:9 / 16:10 geniş ekranlar
                {
                    mainGrid.ColumnStyles[0].Width = 38F;
                    mainGrid.ColumnStyles[1].Width = 32F;
                    mainGrid.ColumnStyles[2].Width = 30F;
                    if (numpadWrapper != null)
                    {
                        numpadWrapper.ColumnStyles[0].Width = 8F;
                        numpadWrapper.ColumnStyles[1].Width = 84F;
                        numpadWrapper.ColumnStyles[2].Width = 8F;
                    }
                }
                mainGrid.ResumeLayout();
            }

            // 2. Dikey Oranlar (LoginLayout)
            if (loginLayout != null)
            {
                loginLayout.SuspendLayout();
                if (h < 800) // Düşük dikey alan (768p, 720p veya %125-150 ölçek)
                {
                    loginLayout.RowStyles[0].Height = 13F; // Okul bilgisi
                    loginLayout.RowStyles[1].Height = 35F; // QR Alanı
                    loginLayout.RowStyles[2].Height = 1F;  // Ayırıcı çizgi
                    loginLayout.RowStyles[3].Height = 14F; // PIN gösterge
                    loginLayout.RowStyles[4].Height = 37F; // Numpad
                }
                else
                {
                    loginLayout.RowStyles[0].Height = 14F;
                    loginLayout.RowStyles[1].Height = 38F;
                    loginLayout.RowStyles[2].Height = 1.5F;
                    loginLayout.RowStyles[3].Height = 13.5F;
                    loginLayout.RowStyles[4].Height = 33F;
                }
                loginLayout.ResumeLayout();
            }

            // 3. Fontların Dinamik ve Güvenli Güncellenmesi
            if (lblBrand != null) lblBrand.Font = new Font("Segoe UI", Math.Max(13f, 22f * uniformScale), FontStyle.Bold);
            if (lblLicenseBadge != null) lblLicenseBadge.Font = new Font("Segoe UI", Math.Max(8.5f, 10.5f * uniformScale), FontStyle.Bold);
            if (lblTime != null) lblTime.Font = new Font("Segoe UI", Math.Max(15f, 24f * uniformScale), FontStyle.Bold);
            if (lblDate != null) lblDate.Font = new Font("Segoe UI", Math.Max(8f, 11f * uniformScale), FontStyle.Regular);

            if (lblLogo != null) lblLogo.Font = new Font("Segoe UI", Math.Max(13f, 22f * uniformScale));
            if (lblSchool != null) lblSchool.Font = new Font("Segoe UI", Math.Max(9f, 14f * uniformScale), FontStyle.Bold);
            if (lblBoard != null) lblBoard.Font = new Font("Segoe UI", Math.Max(8f, 11f * uniformScale), FontStyle.Bold);

            if (lblQrTitle != null) lblQrTitle.Font = new Font("Segoe UI", Math.Max(8f, 10.5f * uniformScale), FontStyle.Bold);
            if (lblQrSub != null) lblQrSub.Font = new Font("Segoe UI", Math.Max(7f, 8.5f * uniformScale), FontStyle.Regular);
            if (lblVersion != null) lblVersion.Font = new Font("Segoe UI", Math.Max(6.5f, 7.5f * uniformScale), FontStyle.Regular);

            if (lblPinTitle != null) lblPinTitle.Font = new Font("Segoe UI", Math.Max(7.5f, 9.5f * uniformScale), FontStyle.Bold);
            if (lblPinDisplay != null) lblPinDisplay.Font = new Font("Segoe UI", Math.Max(12f, 18f * uniformScale), FontStyle.Bold);
            if (lblPinSub != null)
            {
                if (lblPinSub.Text.Contains("Çevrimdışı") || lblPinSub.Text.Contains("Kod:"))
                    lblPinSub.Font = new Font("Segoe UI", Math.Max(7.5f, 9f * uniformScale), FontStyle.Bold);
                else
                    lblPinSub.Font = new Font("Segoe UI", Math.Max(7f, 8f * uniformScale), FontStyle.Regular);
            }

            if (lblAfisTitle != null) lblAfisTitle.Font = new Font("Segoe UI", Math.Max(11f, 17f * uniformScale), FontStyle.Bold);
            if (lblAfisSub != null) lblAfisSub.Font = new Font("Segoe UI", Math.Max(8f, 10.5f * uniformScale), FontStyle.Regular);
            if (lblPosterCounter != null) lblPosterCounter.Font = new Font("Segoe UI", Math.Max(8f, 10f * uniformScale), FontStyle.Bold);

            if (lblDuyuruTitle != null) lblDuyuruTitle.Font = new Font("Segoe UI", Math.Max(14f, 20f * uniformScale), FontStyle.Bold);
            if (lblDuyuruSub != null) lblDuyuruSub.Font = new Font("Segoe UI", Math.Max(9.5f, 12f * uniformScale), FontStyle.Regular);

            // 4. Numpad Buton Fontları
            if (numpadButtons != null && numpadButtons.Count > 0)
            {
                int sampleBtnH = numpadButtons[0].Height;
                float btnFontSize = Math.Max(10f, Math.Min(19f, (sampleBtnH > 10 ? sampleBtnH : 40) * 0.40f));
                foreach (var btn in numpadButtons)
                {
                    btn.Font = new Font("Segoe UI Variable Display", btnFontSize, FontStyle.Bold);
                }
            }

            // 5. Duyuru kartları boyutlandırma
            float col1Percent = (mainGrid != null && mainGrid.ColumnStyles.Count > 1) ? mainGrid.ColumnStyles[1].Width / 100f : 0.32f;
            int simColWidth = (int)(w * col1Percent) - S(25);
            int simColHeight = (int)(h * 0.82f) - S(112);
            RenderAnnouncementCards(simColWidth, simColHeight, uniformScale);
        }

        public int GetVisibleAnnouncementCount(int simulatedHeight = 0)
        {
            int h = simulatedHeight > 0 
                ? simulatedHeight 
                : (pnlAnnouncementsList != null && pnlAnnouncementsList.ClientSize.Height > 50 
                    ? pnlAnnouncementsList.ClientSize.Height 
                    : (int)(this.ClientSize.Height * 0.65f));

            if (h < 500) return 2;
            if (h < 950) return 2;
            if (h < 1500) return 3;
            return 4;
        }

        public void RotateAnnouncementsIfNeeded()
        {
            if (pnlAnnouncementsList == null || pnlAnnouncementsList.IsDisposed) return;
            if (cachedAnnouncements == null || cachedAnnouncements.Count == 0) return;

            int visibleCount = GetVisibleAnnouncementCount();
            if (cachedAnnouncements.Count <= visibleCount) return;

            int totalPages = (int)Math.Ceiling((double)cachedAnnouncements.Count / visibleCount);
            announcementPageIndex = (announcementPageIndex + 1) % totalPages;
            RenderAnnouncementCards();
        }

        public void AdjustAnnouncementCardSizes(int simulatedParentWidth = 0)
        {
            RenderAnnouncementCards(simulatedParentWidth);
        }

        public void RenderAnnouncementCards(int simulatedParentWidth = 0, int simulatedParentHeight = 0, float? customScale = null)
        {
            if (pnlAnnouncementsList == null || pnlAnnouncementsList.IsDisposed) return;

            int w = simulatedParentWidth > 0 ? simulatedParentWidth : pnlAnnouncementsList.ClientSize.Width;
            if (w <= 50 && mainGrid != null && this.ClientSize.Width > 100)
            {
                float colPercent = mainGrid.ColumnStyles.Count > 1 ? mainGrid.ColumnStyles[1].Width / 100f : 0.32f;
                w = (int)(this.ClientSize.Width * colPercent) - S(25);
            }
            int targetWidth = Math.Max(50, w - S(10));

            int h = simulatedParentHeight > 0 
                ? simulatedParentHeight 
                : (pnlAnnouncementsList.ClientSize.Height > 50 
                    ? pnlAnnouncementsList.ClientSize.Height 
                    : (int)(this.ClientSize.Height * 0.65f));

            float scaleH = Math.Max(0.65f, Math.Min(1.8f, this.ClientSize.Height / 1080f));
            float scaleW = Math.Max(0.65f, Math.Min(1.8f, this.ClientSize.Width / 1920f));
            float uniformScale = customScale ?? Math.Min(scaleW, scaleH);

            pnlAnnouncementsList.SuspendLayout();
            pnlAnnouncementsList.Controls.Clear();

            if (cachedAnnouncements == null || cachedAnnouncements.Count == 0)
            {
                FluentCard emptyCard = new FluentCard(S(12))
                {
                    Width = targetWidth,
                    Height = Math.Min(Math.Max(S(90), h - S(10)), S(180)),
                    Margin = new Padding(0, 0, 0, S(10)),
                    BackColor = Color.White
                };
                TableLayoutPanel emptyLayout = new TableLayoutPanel
                {
                    Dock = DockStyle.Fill,
                    RowCount = 2,
                    ColumnCount = 1,
                    Padding = new Padding(S(16))
                };
                emptyLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 40F));
                emptyLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 60F));

                Label lblEmptyTitle = new Label
                {
                    Text = "📢 Aktif Okul Duyurusu Yok",
                    Font = new Font("Segoe UI", Math.Max(13f, 17f * uniformScale), FontStyle.Bold),
                    ForeColor = ColTextMain,
                    Dock = DockStyle.Fill,
                    TextAlign = ContentAlignment.MiddleLeft
                };
                Label lblEmptySub = new Label
                {
                    Text = "Yönetim tarafından yayınlanan genel bilgilendirmeler ve duyurular bu ekranda otomatik olarak görüntülenecektir.",
                    Font = new Font("Segoe UI", Math.Max(11f, 14f * uniformScale), FontStyle.Regular),
                    ForeColor = Color.FromArgb(51, 65, 85),
                    Dock = DockStyle.Fill,
                    AutoEllipsis = true
                };
                emptyLayout.Controls.Add(lblEmptyTitle, 0, 0);
                emptyLayout.Controls.Add(lblEmptySub, 0, 1);
                emptyCard.Controls.Add(emptyLayout);
                pnlAnnouncementsList.Controls.Add(emptyCard);

                if (lblDuyuruSub != null) lblDuyuruSub.Text = "Yayında Duyuru Yok";
                pnlAnnouncementsList.ResumeLayout();
                return;
            }

            int visibleCount = GetVisibleAnnouncementCount(h);
            int totalPages = (int)Math.Ceiling((double)cachedAnnouncements.Count / visibleCount);
            if (announcementPageIndex >= totalPages) announcementPageIndex = 0;

            var pageItems = new List<MediaItem>();
            int startIndex = announcementPageIndex * visibleCount;
            for (int i = startIndex; i < Math.Min(startIndex + visibleCount, cachedAnnouncements.Count); i++)
            {
                pageItems.Add(cachedAnnouncements[i]);
            }

            if (lblDuyuruSub != null)
            {
                if (totalPages > 1)
                {
                    lblDuyuruSub.Text = $"Sayfa {announcementPageIndex + 1}/{totalPages} • {cachedAnnouncements.Count} Aktif Duyuru";
                }
                else
                {
                    lblDuyuruSub.Text = "Güncel Okul Duyuruları";
                }
            }

            int totalGap = (pageItems.Count - 1) * S(12);
            int cardH = Math.Max(S(90), (h - totalGap - S(8)) / Math.Max(1, pageItems.Count));
            int maxTextW = Math.Max(50, targetWidth - S(32));

            foreach (var ann in pageItems)
            {
                FluentCard card = new FluentCard(S(12))
                {
                    Width = targetWidth,
                    Height = cardH,
                    Margin = new Padding(0, 0, 0, S(12)),
                    BackColor = Color.White
                };

                TableLayoutPanel cardLayout = new TableLayoutPanel
                {
                    Dock = DockStyle.Fill,
                    RowCount = 3,
                    ColumnCount = 1,
                    Padding = new Padding(S(16), S(10), S(16), S(10))
                };
                cardLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, S(28)));
                cardLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 35F));
                cardLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 65F));

                Panel badgePanel = new Panel { Dock = DockStyle.Fill, Margin = new Padding(0), BackColor = Color.Transparent };
                Label lblBadge = new Label
                {
                    Text = ann.Id.StartsWith("default") ? "📢 GENEL BİLGİLENDİRME" : "📌 OKUL DUYURUSU",
                    Font = new Font("Segoe UI", Math.Max(8.5f, 10f * uniformScale), FontStyle.Bold),
                    ForeColor = Color.FromArgb(37, 99, 235),
                    BackColor = Color.FromArgb(239, 246, 255),
                    AutoSize = true,
                    Padding = new Padding(S(8), S(2), S(8), S(2)),
                    Location = new Point(0, 0)
                };
                badgePanel.Controls.Add(lblBadge);

                Label lblTitle = new Label
                {
                    Text = ann.Title,
                    Font = new Font("Segoe UI", Math.Max(13.5f, 17.5f * uniformScale), FontStyle.Bold),
                    ForeColor = Color.FromArgb(15, 23, 42),
                    Dock = DockStyle.Fill,
                    AutoEllipsis = true,
                    MaximumSize = new Size(maxTextW, 0),
                    TextAlign = ContentAlignment.MiddleLeft,
                    Margin = new Padding(0, S(2), 0, S(2))
                };

                Label lblContent = new Label
                {
                    Text = ann.Content,
                    Font = new Font("Segoe UI", Math.Max(11.5f, 14.5f * uniformScale), FontStyle.Regular),
                    ForeColor = Color.FromArgb(30, 41, 59),
                    Dock = DockStyle.Fill,
                    AutoEllipsis = true,
                    MaximumSize = new Size(maxTextW, 0),
                    TextAlign = ContentAlignment.TopLeft,
                    Margin = new Padding(0)
                };

                cardLayout.Controls.Add(badgePanel, 0, 0);
                cardLayout.Controls.Add(lblTitle, 0, 1);
                cardLayout.Controls.Add(lblContent, 0, 2);

                card.Controls.Add(cardLayout);
                pnlAnnouncementsList.Controls.Add(card);
            }

            pnlAnnouncementsList.ResumeLayout();
        }

        private FluentButton CreateNumpadButton(string text)
        {
            FluentButton btn = new FluentButton(S(8))
            {
                Text = text,
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI Variable Display", 16, FontStyle.Bold),
                DefaultBackColor = ColBg,
                HoverBackColor = ColBorder,
                ForeColor = ColTextMain,
                HoverForeColor = ColTextMain,
                Margin = new Padding(S(3)),
                Cursor = Cursors.Hand
            };
            btn.Click += Numpad_Click;
            return btn;
        }

        public void RefreshMediaDisplays()
        {
            try
            {
                // 1. Afişleri güncelle
                activePosterPaths = MediaManager.GetActivePosterFilePaths();
                currentPosterIndex = 0;
                int rotSec = MediaManager.GetRotationIntervalSeconds();
                if (posterSlideshowTimer != null)
                {
                    posterSlideshowTimer.Interval = Math.Max(3, rotSec) * 1000;
                }
                RefreshPosterImageOnly();

                // 2. Duyuruları güncelle
                cachedAnnouncements = MediaManager.GetActiveAnnouncements();
                announcementPageIndex = 0;
                RenderAnnouncementCards();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"RefreshMediaDisplays error: {ex.Message}");
            }
        }

        public void RefreshPosterImageOnly()
        {
            try
            {
                if (pbPoster == null) return;
                if (activePosterPaths != null && activePosterPaths.Count > 0)
                {
                    if (currentPosterIndex >= activePosterPaths.Count) currentPosterIndex = 0;
                    string path = activePosterPaths[currentPosterIndex];
                    if (System.IO.File.Exists(path))
                    {
                        byte[] bytes = System.IO.File.ReadAllBytes(path);
                        using (var ms = new System.IO.MemoryStream(bytes))
                        using (var src = Image.FromStream(ms))
                        {
                            var newBmp = new Bitmap(src);
                            var oldImg = pbPoster.Image;
                            pbPoster.Image = newBmp;
                            oldImg?.Dispose();
                        }
                    }
                    if (lblPosterCounter != null)
                    {
                        lblPosterCounter.Text = $"{currentPosterIndex + 1}/{activePosterPaths.Count}";
                    }
                }
                else
                {
                    pbPoster.Image = null;
                    if (lblPosterCounter != null) lblPosterCounter.Text = "0/0";
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"RefreshPosterImageOnly error: {ex.Message}");
            }
        }
    }

    public class FluentCard : Panel
    {
        private int radius;
        private GraphicsPath? cachedPath;
        private Size lastSize;

        public FluentCard(int radius)
        {
            this.radius = radius;
            this.DoubleBuffered = true;
            this.SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            this.BackColor = Color.White;
        }

        private void EnsurePath()
        {
            if (cachedPath == null || lastSize != this.ClientSize)
            {
                cachedPath?.Dispose();
                lastSize = this.ClientSize;
                cachedPath = GetPath(this.ClientRectangle, radius);
                this.Region?.Dispose();
                this.Region = new Region(cachedPath);
            }
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            cachedPath?.Dispose();
            cachedPath = null;
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            EnsurePath();
            if (cachedPath == null) return;

            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            e.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;

            // Arka plan boyama
            using (SolidBrush bgBrush = new SolidBrush(this.BackColor))
                e.Graphics.FillPath(bgBrush, cachedPath);

            // İnce zarif kenarlık boyama
            using (Pen pen = new Pen(Color.FromArgb(229, 231, 235), 1f))
                e.Graphics.DrawPath(pen, cachedPath);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                cachedPath?.Dispose();
                cachedPath = null;
            }
            base.Dispose(disposing);
        }

        private GraphicsPath GetPath(Rectangle rc, int r)
        {
            GraphicsPath path = new GraphicsPath();
            if (rc.Width <= 0 || rc.Height <= 0) return path;

            int safeR = Math.Min(r, Math.Min(rc.Width, rc.Height) / 2);
            int d = safeR * 2;

            if (d <= 0)
            {
                path.AddRectangle(rc);
                return path;
            }

            path.AddArc(rc.X, rc.Y, d, d, 180, 90);
            path.AddArc(rc.Right - d - 1, rc.Y, d, d, 270, 90);
            path.AddArc(rc.Right - d - 1, rc.Bottom - d - 1, d, d, 0, 90);
            path.AddArc(rc.X, rc.Bottom - d - 1, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    public class FluentButton : Control
    {
        private int radius;
        private bool isHovered = false;
        private bool isPressed = false;

        public Color DefaultBackColor { get; set; } = Color.FromArgb(245, 247, 251);
        public Color HoverBackColor { get; set; } = Color.FromArgb(229, 231, 235);
        public Color HoverForeColor { get; set; } = Color.FromArgb(17, 24, 39);

        public FluentButton(int radius)
        {
            this.radius = radius;
            this.DoubleBuffered = true;
            this.SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            this.Cursor = Cursors.Hand;
        }

        protected override void OnMouseEnter(EventArgs e) { isHovered = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHovered = false; isPressed = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { isPressed = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { isPressed = false; Invalidate(); base.OnMouseUp(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            e.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;

            Color currentBg = isPressed ? ControlPaint.Dark(HoverBackColor, 0.05f) : (isHovered ? HoverBackColor : DefaultBackColor);
            Color currentFg = isHovered ? HoverForeColor : ForeColor;

            Rectangle rect = this.ClientRectangle;
            if (rect.Width <= 2 || rect.Height <= 2) return;

            if (isPressed) { rect.Y += 1; rect.Height -= 1; }

            int safeR = Math.Min(radius, Math.Min(rect.Width, rect.Height) / 2);
            int d = safeR * 2;

            using (GraphicsPath path = new GraphicsPath())
            {
                if (d > 0)
                {
                    path.AddArc(rect.X, rect.Y, d, d, 180, 90);
                    path.AddArc(rect.Right - d - 1, rect.Y, d, d, 270, 90);
                    path.AddArc(rect.Right - d - 1, rect.Bottom - d - 1, d, d, 0, 90);
                    path.AddArc(rect.X, rect.Bottom - d - 1, d, d, 90, 90);
                    path.CloseFigure();
                }
                else
                {
                    path.AddRectangle(rect);
                }

                using (SolidBrush brush = new SolidBrush(currentBg))
                    e.Graphics.FillPath(brush, path);
            }

            TextRenderer.DrawText(e.Graphics, this.Text, this.Font, rect, currentFg, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoClipping);
        }
    }

    /// <summary>
    /// Afişleri ve resimleri en-boy oranını bozmadan (Aspect-Fill / Center-Crop)
    /// kutunun tamamını dolduracak şekilde profesyonelce ölçekleyip merkezden kırpan PictureBox bileşeni.
    /// </summary>
    public class AspectFillPictureBox : PictureBox
    {
        public AspectFillPictureBox()
        {
            this.DoubleBuffered = true;
            this.SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs pe)
        {
            pe.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            pe.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            pe.Graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;

            using (var brush = new SolidBrush(this.BackColor))
            {
                pe.Graphics.FillRectangle(brush, this.ClientRectangle);
            }

            try
            {
                var img = this.Image;
                if (img != null)
                {
                    int imgW = img.Width;
                    int imgH = img.Height;
                    int boxW = this.ClientSize.Width;
                    int boxH = this.ClientSize.Height;

                    if (imgW > 0 && imgH > 0 && boxW > 0 && boxH > 0)
                    {
                        float scale = Math.Max((float)boxW / imgW, (float)boxH / imgH);
                        float visibleW = boxW / scale;
                        float visibleH = boxH / scale;
                        float srcX = (imgW - visibleW) / 2f;
                        float srcY = (imgH - visibleH) / 2f;

                        RectangleF srcRect = new RectangleF(srcX, srcY, visibleW, visibleH);
                        RectangleF dstRect = new RectangleF(0, 0, boxW, boxH);
                        pe.Graphics.DrawImage(img, dstRect, srcRect, GraphicsUnit.Pixel);
                    }
                }
            }
            catch
            {
                // Resim rotasyonu veya arka plan güncellemelerinde oluşabilecek olası GDI+ istisnalarını güvenle yut
            }
        }
    }
}