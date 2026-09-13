using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Diagnostics;

namespace KioskLockApp.UI
{
    public partial class SecureRenderer
    {
        // Renk Paleti (Design System)
        private readonly Color ColBg = Color.FromArgb(245, 247, 251);
        private readonly Color ColCard = Color.FromArgb(255, 255, 255);
        private readonly Color ColTextMain = Color.FromArgb(17, 24, 39);
        private readonly Color ColTextSec = Color.FromArgb(107, 114, 128);
        private readonly Color ColPrimary = Color.FromArgb(37, 99, 235);
        private readonly Color ColPrimaryHover = Color.FromArgb(29, 78, 216);
        private readonly Color ColBorder = Color.FromArgb(229, 231, 235);
        private readonly Color ColDanger = Color.FromArgb(220, 38, 38);

        // UI Elementleri
        private Label lblTime;
        private Label lblDate;
        private Label lblPinDisplay;
        private PictureBox pbQrCode;

        // DPI ölçek çarpanı: 96 = Windows'un "standart" (%100) DPI değeridir.
        private float DpiScale => this.DeviceDpi / 96f;

        // Kısayol: bir pixel değerini DPI'a göre ölçekler
        private int S(int px) => (int)Math.Round(px * DpiScale);

        private void BuildUI()
        {
            // 1. ANA IZGARA (Üst %8, Orta %82, Alt %10)
            TableLayoutPanel root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 8F));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 82F));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 10F));
            this.Controls.Add(root);

            // --- HEADER ---
            TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(30), 0, S(30), 0) };
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));

            // Marka
            Label lblBrand = new Label { Text = "Sınıf360", Font = new Font("Segoe UI", 22, FontStyle.Bold), ForeColor = ColPrimary, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
            header.Controls.Add(lblBrand, 0, 0);

            // Saat ve Tarih
            TableLayoutPanel pnlDateTime = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
            pnlDateTime.RowStyles.Add(new RowStyle(SizeType.Percent, 65F));
            pnlDateTime.RowStyles.Add(new RowStyle(SizeType.Percent, 35F));
            lblTime = new Label { Font = new Font("Segoe UI", 24, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter };
            lblDate = new Label { Font = new Font("Segoe UI", 11, FontStyle.Regular), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };
            pnlDateTime.Controls.Add(lblTime, 0, 0);
            pnlDateTime.Controls.Add(lblDate, 0, 1);
            header.Controls.Add(pnlDateTime, 1, 0);

            root.Controls.Add(header, 0, 0);

            // --- MAIN CONTENT (35% - 35% - 30%) ---
            TableLayoutPanel mainGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(15), 0, S(15), 0) };
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35F));
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35F));
            mainGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
            root.Controls.Add(mainGrid, 0, 1);

            // SOL KART: AFİŞLER
            FluentCard cardAfis = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };
            cardAfis.Controls.Add(CreateHeaderAndEmptyState("AFİŞLER", "Etkinlikler ve bilgilendirme", "🖼️", "Henüz afiş bulunmuyor", "Yeni afişler yayınlandığında\nburada görüntülenecektir."));
            mainGrid.Controls.Add(cardAfis, 0, 0);

            // ORTA KART: DUYURULAR
            FluentCard cardDuyuru = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };
            cardDuyuru.Controls.Add(CreateHeaderAndEmptyState("DUYURULAR", "Güncel okul duyuruları", "📢", "Henüz duyuru bulunmuyor", "Yeni bir duyuru eklendiğinde\nburada listelenecektir."));
            mainGrid.Controls.Add(cardDuyuru, 1, 0);

            // SAĞ KART: LOGIN / QR
            FluentCard cardLogin = new FluentCard(S(16)) { Dock = DockStyle.Fill, Margin = new Padding(S(10)) };

            // Taşmaları tamamen önleyen yüzdelik dikey grid
            TableLayoutPanel loginLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 5, ColumnCount = 1, Padding = new Padding(S(5)) };
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 15F)); // Okul / Sınıf
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 40F)); // QR Kod + Versiyon
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 2F));  // Ayraç
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 13F)); // PIN
            loginLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 30F)); // Numpad
            cardLogin.Controls.Add(loginLayout);

            // 1. Okul & Sınıf Başlıkları 
            TableLayoutPanel pnlSchoolInfo = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 40F));
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 35F));
            pnlSchoolInfo.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));
            Label lblLogo = new Label { Text = "🏫", Font = new Font("Segoe UI", 24), AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter, ForeColor = ColPrimary };
            Label lblSchool = new Label { Text = GetSavedSchoolName().ToUpper(), Font = new Font("Segoe UI", 16, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };
            Label lblBoard = new Label { Text = GetSavedBoardName(), Font = new Font("Segoe UI", 12, FontStyle.Bold), ForeColor = ColPrimary, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };
            pnlSchoolInfo.Controls.Add(lblLogo, 0, 0);
            pnlSchoolInfo.Controls.Add(lblSchool, 0, 1);
            pnlSchoolInfo.Controls.Add(lblBoard, 0, 2);
            loginLayout.Controls.Add(pnlSchoolInfo, 0, 0);

            // 2. QR Kod Alanı ve Hemen Altında Sürüm (Version) Bilgisi
            TableLayoutPanel pnlQrArea = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 15F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 55F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 15F));
            pnlQrArea.RowStyles.Add(new RowStyle(SizeType.Percent, 15F)); // Versiyon için yeni satır

            Label lblQrTitle = new Label { Text = "Mobil uygulamaya bağlan", Font = new Font("Segoe UI", 11, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter };
            pbQrCode = new PictureBox { SizeMode = PictureBoxSizeMode.Zoom, Dock = DockStyle.Fill, Margin = new Padding(S(5)) };
            Label lblQrSub = new Label { Text = "Uygulamadaki 'Karekod Okut' butonunu kullanın", Font = new Font("Segoe UI", 9), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };

            // Versiyon numarasını otomatik çeken yapı
            string appVersion = "1.0.0";
            try
            {
                appVersion = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString();
                if (appVersion.EndsWith(".0")) appVersion = appVersion.Substring(0, appVersion.Length - 2);
            }
            catch { }

            Label lblVersion = new Label { Text = "v" + appVersion, Font = new Font("Segoe UI", 8, FontStyle.Regular), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };

            pnlQrArea.Controls.Add(lblQrTitle, 0, 0);
            pnlQrArea.Controls.Add(pbQrCode, 0, 1);
            pnlQrArea.Controls.Add(lblQrSub, 0, 2);
            pnlQrArea.Controls.Add(lblVersion, 0, 3); // QR altına iliştirildi
            loginLayout.Controls.Add(pnlQrArea, 0, 1);

            // 3. Ayraç Çizgisi
            Panel separator = new Panel { Dock = DockStyle.Fill };
            separator.Paint += (s, e) => { e.Graphics.DrawLine(new Pen(ColBorder), S(40), separator.Height / 2, separator.Width - S(40), separator.Height / 2); };
            loginLayout.Controls.Add(separator, 0, 2);

            // 4. PIN Girişi
            TableLayoutPanel pnlPinTop = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            pnlPinTop.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));
            Label lblPinTitle = new Label { Text = "PIN GİRİŞİ", Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter };
            lblPinDisplay = new Label { Text = "○  ○  ○  ○  ○  ○", Font = new Font("Segoe UI", 20, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter };
            Label lblPinSub = new Label { Text = "İnternet yoksa 'Çevrimdışı Şifre' alabilirsiniz", Font = new Font("Segoe UI", 8), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter };
            pnlPinTop.Controls.Add(lblPinTitle, 0, 0);
            pnlPinTop.Controls.Add(lblPinDisplay, 0, 1);
            pnlPinTop.Controls.Add(lblPinSub, 0, 2);
            loginLayout.Controls.Add(pnlPinTop, 0, 3);

            // 5. Numpad
            TableLayoutPanel numpadWrapper = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3 };
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 15F));
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 70F));
            numpadWrapper.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 15F));

            TableLayoutPanel numpadGrid = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 3 };
            for (int i = 0; i < 3; i++) numpadGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            for (int i = 0; i < 4; i++) numpadGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 25F));

            for (int i = 1; i <= 9; i++) numpadGrid.Controls.Add(CreateNumpadButton(i.ToString()), (i - 1) % 3, (i - 1) / 3);

            FluentButton btnClear = CreateNumpadButton("⌫");
            btnClear.Click -= Numpad_Click;
            btnClear.Click += (s, e) => { enteredPin = ""; UpdatePinDisplay(); };

            FluentButton btnZero = CreateNumpadButton("0");

            FluentButton btnEnter = CreateNumpadButton("✓");
            btnEnter.DefaultBackColor = ColPrimary;
            btnEnter.HoverBackColor = ColPrimaryHover;
            btnEnter.ForeColor = Color.White;
            btnEnter.HoverForeColor = Color.White;
            btnEnter.Click -= Numpad_Click;

            numpadGrid.Controls.Add(btnClear, 0, 3);
            numpadGrid.Controls.Add(btnZero, 1, 3);
            numpadGrid.Controls.Add(btnEnter, 2, 3);

            numpadWrapper.Controls.Add(numpadGrid, 1, 0);
            loginLayout.Controls.Add(numpadWrapper, 0, 4);

            mainGrid.Controls.Add(cardLogin, 2, 0);

            // --- FOOTER ---
            TableLayoutPanel footer = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3, Padding = new Padding(S(30), 0, S(30), S(10)) };
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.33F));

            // Sol taraftaki eski versiyon etiketi temizlendi (çünkü artık QR altında)
            footer.Controls.Add(new Panel { Dock = DockStyle.Fill }, 0, 0);

            Panel pnlPowerWrapper = new Panel { Dock = DockStyle.Fill };
            FluentButton btnPower = new FluentButton(S(8))
            {
                Text = "⏻ Sistemi Kapat",
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                Size = new Size(S(160), S(36)),
                DefaultBackColor = Color.Transparent,
                HoverBackColor = Color.FromArgb(254, 226, 226),
                ForeColor = ColTextSec,
                HoverForeColor = ColDanger,
                Anchor = AnchorStyles.None
            };
            pnlPowerWrapper.Resize += (s, e) => { btnPower.Left = (pnlPowerWrapper.Width - btnPower.Width) / 2; btnPower.Top = (pnlPowerWrapper.Height - btnPower.Height) / 2; };
            btnPower.Click += (s, e) => Process.Start("shutdown", "/s /f /t 0");
            pnlPowerWrapper.Controls.Add(btnPower);
            footer.Controls.Add(pnlPowerWrapper, 1, 0);

            root.Controls.Add(footer, 0, 2);
        }

        private Panel CreateHeaderAndEmptyState(string title, string subtitle, string icon, string emptyTitle, string emptyDesc)
        {
            TableLayoutPanel pnl = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1, Padding = new Padding(S(15)) };
            pnl.RowStyles.Add(new RowStyle(SizeType.Percent, 15F));
            pnl.RowStyles.Add(new RowStyle(SizeType.Absolute, S(10)));
            pnl.RowStyles.Add(new RowStyle(SizeType.Percent, 85F));

            TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 60F));
            header.RowStyles.Add(new RowStyle(SizeType.Percent, 40F));
            header.Controls.Add(new Label { Text = title, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomLeft }, 0, 0);
            header.Controls.Add(new Label { Text = subtitle, Font = new Font("Segoe UI", 11), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopLeft }, 0, 1);
            pnl.Controls.Add(header, 0, 0);

            TableLayoutPanel emptyState = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
            emptyState.RowStyles.Add(new RowStyle(SizeType.Percent, 35F));
            emptyState.RowStyles.Add(new RowStyle(SizeType.Percent, 20F));
            emptyState.RowStyles.Add(new RowStyle(SizeType.Percent, 45F));

            emptyState.Controls.Add(new Label { Text = icon, Font = new Font("Segoe UI", 42), AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.BottomCenter }, 0, 0);
            emptyState.Controls.Add(new Label { Text = emptyTitle, Font = new Font("Segoe UI", 14, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter }, 0, 1);
            emptyState.Controls.Add(new Label { Text = emptyDesc, Font = new Font("Segoe UI", 11), ForeColor = ColTextSec, AutoSize = false, Dock = DockStyle.Fill, TextAlign = ContentAlignment.TopCenter }, 0, 2);

            pnl.Controls.Add(emptyState, 0, 2);
            return pnl;
        }

        private FluentButton CreateNumpadButton(string text)
        {
            FluentButton btn = new FluentButton(S(8))
            {
                Text = text,
                Dock = DockStyle.Fill,
                Font = new Font("Segoe UI Variable Display", 18, FontStyle.Bold),
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
    }

    // --- FLUENT DESIGN BİLEŞENLERİ ---
    public class FluentCard : Panel
    {
        private int radius;
        public FluentCard(int radius) { this.radius = radius; this.DoubleBuffered = true; this.BackColor = Color.White; }
        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (GraphicsPath path = GetPath(this.ClientRectangle, radius))
            {
                this.Region = new Region(path);
                using (Pen pen = new Pen(Color.FromArgb(229, 231, 235), 1.5f))
                    e.Graphics.DrawPath(pen, path);
            }
        }
        private GraphicsPath GetPath(Rectangle rc, int r)
        {
            GraphicsPath path = new GraphicsPath();
            path.AddArc(rc.X, rc.Y, r, r, 180, 90);
            path.AddArc(rc.Width - r - 1, rc.Y, r, r, 270, 90);
            path.AddArc(rc.Width - r - 1, rc.Height - r - 1, r, r, 0, 90);
            path.AddArc(rc.X, rc.Height - r - 1, r, r, 90, 90);
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
            this.Cursor = Cursors.Hand;
        }

        protected override void OnMouseEnter(EventArgs e) { isHovered = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHovered = false; isPressed = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { isPressed = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { isPressed = false; Invalidate(); base.OnMouseUp(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;

            Color currentBg = isPressed ? ControlPaint.Dark(HoverBackColor, 0.05f) : (isHovered ? HoverBackColor : DefaultBackColor);
            Color currentFg = isHovered ? HoverForeColor : ForeColor;

            Rectangle rect = this.ClientRectangle;
            if (isPressed) { rect.Y += 1; rect.Height -= 1; }

            using (GraphicsPath path = new GraphicsPath())
            {
                path.AddArc(rect.X, rect.Y, radius, radius, 180, 90);
                path.AddArc(rect.Width - radius - 1, rect.Y, radius, radius, 270, 90);
                path.AddArc(rect.Width - radius - 1, rect.Height - radius - 1, radius, radius, 0, 90);
                path.AddArc(rect.X, rect.Height - radius - 1, radius, radius, 90, 90);
                path.CloseFigure();

                using (SolidBrush brush = new SolidBrush(currentBg))
                    e.Graphics.FillPath(brush, path);
            }

            TextRenderer.DrawText(e.Graphics, this.Text, this.Font, rect, currentFg, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }
}