using System;
using System.Drawing;
using System.Windows.Forms;

namespace KioskLockApp.UI
{
    public partial class PairingScreen
    {
        // Renk Paleti
        private readonly Color ColTextMain = Color.FromArgb(17, 24, 39);
        private readonly Color ColTextSec = Color.FromArgb(107, 114, 128);
        private readonly Color ColPrimary = Color.FromArgb(37, 99, 235);

        // Dinamik değişecek etiketler
        private Label lblCode;
        private Label lblStatus;

        private void BuildUI()
        {
            // Ekranı 3x3 bir ızgaraya bölüp kartı tam merkeze (1,1) oturtacağız
            TableLayoutPanel rootGrid = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 3,
                ColumnCount = 3,
                BackColor = Color.Transparent
            };

            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            rootGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));

            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            rootGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
            this.Controls.Add(rootGrid);

            // --- MERKEZ KART ---
            FluentCard centerCard = new FluentCard(20)
            {
                Size = new Size(700, 450),
                BackColor = Color.White,
                Margin = new Padding(20)
            };

            TableLayoutPanel cardContent = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 5,
                ColumnCount = 1,
                Padding = new Padding(40)
            };
            cardContent.RowStyles.Add(new RowStyle(SizeType.AutoSize)); // Logo/Marka
            cardContent.RowStyles.Add(new RowStyle(SizeType.AutoSize)); // Başlık ve Açıklama
            cardContent.RowStyles.Add(new RowStyle(SizeType.Percent, 100F)); // Dev Eşleşme Kodu
            cardContent.RowStyles.Add(new RowStyle(SizeType.Absolute, 20F)); // Ayraç
            cardContent.RowStyles.Add(new RowStyle(SizeType.AutoSize)); // Durum Bilgisi
            centerCard.Controls.Add(cardContent);

            // 1. Marka İkonu
            Label lblLogo = new Label
            {
                Text = "⚙️",
                Font = new Font("Segoe UI", 36),
                AutoSize = true,
                Anchor = AnchorStyles.None,
                Margin = new Padding(0, 0, 0, 10)
            };
            cardContent.Controls.Add(lblLogo, 0, 0);

            // 2. Başlık ve Açıklama
            FlowLayoutPanel pnlTitles = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, AutoSize = true, Anchor = AnchorStyles.None };
            Label lblTitle = new Label { Text = "Sınıf360 Kurulumu", Font = new Font("Segoe UI", 24, FontStyle.Bold), ForeColor = ColTextMain, AutoSize = true, TextAlign = ContentAlignment.MiddleCenter, Anchor = AnchorStyles.None };
            Label lblInstruction = new Label { Text = "Mobil uygulamadan 'Tahta Ekle' menüsüne girerek\naşağıdaki 6 haneli eşleşme kodunu yazın.", Font = new Font("Segoe UI", 14), ForeColor = ColTextSec, AutoSize = true, TextAlign = ContentAlignment.MiddleCenter, Margin = new Padding(0, 10, 0, 0) };
            pnlTitles.Controls.Add(lblTitle);
            pnlTitles.Controls.Add(lblInstruction);
            cardContent.Controls.Add(pnlTitles, 0, 1);

            // 3. Eşleşme Kodu (Dev Punto)
            lblCode = new Label
            {
                Text = "YÜKLENİYOR...",
                Font = new Font("Segoe UI Variable Display", 64, FontStyle.Bold),
                ForeColor = ColPrimary,
                AutoSize = true,
                Anchor = AnchorStyles.None,
                TextAlign = ContentAlignment.MiddleCenter
            };
            cardContent.Controls.Add(lblCode, 0, 2);

            // 4. Ayraç (İnce Çizgi)
            Panel separator = new Panel { Dock = DockStyle.Fill };
            separator.Paint += (s, e) => { e.Graphics.DrawLine(new Pen(Color.FromArgb(229, 231, 235)), 40, 10, ((Panel)s).Width - 40, 10); };
            cardContent.Controls.Add(separator, 0, 3);

            // 5. Alt Durum Çubuğu
            lblStatus = new Label
            {
                Text = "Bağlantı hazırlanıyor...",
                Font = new Font("Segoe UI", 12, FontStyle.Bold),
                ForeColor = ColTextSec,
                AutoSize = true,
                Anchor = AnchorStyles.None,
                Margin = new Padding(0, 10, 0, 0)
            };
            cardContent.Controls.Add(lblStatus, 0, 4);

            rootGrid.Controls.Add(centerCard, 1, 1);

            // --- ÇIKIŞ / KAPAT BUTONU (Sağ Alt Köşe) ---
            FluentButton btnExit = new FluentButton(8)
            {
                Text = "❌ Çıkış Yap",
                Font = new Font("Segoe UI", 11, FontStyle.Bold),
                Size = new Size(160, 45),
                DefaultBackColor = Color.Transparent,
                HoverBackColor = Color.FromArgb(254, 226, 226), // Açık Kırmızı Hover
                ForeColor = ColTextSec,
                HoverForeColor = Color.FromArgb(220, 38, 38), // Koyu Kırmızı Metin
                Anchor = AnchorStyles.Bottom | AnchorStyles.Right,
                Margin = new Padding(0, 0, 40, 40), // Sağdan ve alttan boşluk
                Cursor = Cursors.Hand
            };

            // Butona tıklandığında uygulamayı tamamen kapatan olay (Event)
            btnExit.Click += (s, e) => {
                Application.Exit();
                Environment.Exit(0);
            };

            rootGrid.Controls.Add(btnExit, 2, 2);
        }
    }
}