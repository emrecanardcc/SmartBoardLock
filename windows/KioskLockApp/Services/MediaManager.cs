using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace KioskLockApp.Services
{
    public class MediaItem
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("type")]
        public string Type { get; set; } = "poster"; // "poster" or "announcement"

        [JsonPropertyName("title")]
        public string Title { get; set; } = "";

        [JsonPropertyName("content")]
        public string Content { get; set; } = "";

        [JsonPropertyName("image_url")]
        public string ImageUrl { get; set; } = "";

        [JsonPropertyName("local_path")]
        public string LocalPath { get; set; } = "";

        [JsonPropertyName("valid_from")]
        public DateTime ValidFrom { get; set; } = DateTime.MinValue;

        [JsonPropertyName("valid_to")]
        public DateTime ValidTo { get; set; } = DateTime.MaxValue;
    }

    public class MediaManifest
    {
        [JsonPropertyName("active_media_id")]
        public string ActiveMediaId { get; set; } = "DEFAULT";

        [JsonPropertyName("package_title")]
        public string PackageTitle { get; set; } = "";

        [JsonPropertyName("package_version")]
        public string PackageVersion { get; set; } = "v1.0";

        [JsonPropertyName("valid_from")]
        public DateTime ValidFrom { get; set; } = DateTime.MinValue;

        [JsonPropertyName("valid_to")]
        public DateTime ValidTo { get; set; } = DateTime.MaxValue;

        [JsonPropertyName("last_updated")]
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

        [JsonPropertyName("items")]
        public List<MediaItem> Items { get; set; } = new List<MediaItem>();
    }

    /// <summary>
    /// Akıllı Tahta Duyuru ve Afiş Motoru.
    /// Tüm medya dosyalarını C:\ProgramData\AkilliTahtaKilitSistemi\Media klasöründe yerel (offline) saklar.
    /// Veritabanını şişirmez, süresi dolduğunda otomatik olarak varsayılan (DEFAULT) afiş ve duyurulara döner.
    /// </summary>
    public static class MediaManager
    {
        private static readonly string BaseDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AkilliTahtaKilitSistemi",
            "Media"
        );

        private static readonly string PostersDir = Path.Combine(BaseDir, "Posters");
        private static readonly string AnnouncementsDir = Path.Combine(BaseDir, "Announcements");
        private static readonly string DefaultDir = Path.Combine(BaseDir, "Default");
        private static readonly string ManifestPath = Path.Combine(BaseDir, "manifest.json");

        private static MediaManifest currentManifest = new MediaManifest();
        private static readonly object syncLock = new object();
        private static readonly HttpClient downloadClient = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };

        static MediaManager()
        {
            EnsureDirectories();
            LoadManifest();
            EnsureDefaultAssets();
        }

        private static void EnsureDirectories()
        {
            try
            {
                // Eski geçici Sinif360\Media klasörü varsa temizle
                try
                {
                    string oldDir = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                        "Sinif360",
                        "Media"
                    );
                    if (Directory.Exists(oldDir)) Directory.Delete(oldDir, true);
                }
                catch { }

                if (!Directory.Exists(BaseDir)) Directory.CreateDirectory(BaseDir);
                if (!Directory.Exists(PostersDir)) Directory.CreateDirectory(PostersDir);
                if (!Directory.Exists(AnnouncementsDir)) Directory.CreateDirectory(AnnouncementsDir);
                if (!Directory.Exists(DefaultDir)) Directory.CreateDirectory(DefaultDir);
            }
            catch { }
        }

        private static void LoadManifest()
        {
            lock (syncLock)
            {
                try
                {
                    if (File.Exists(ManifestPath))
                    {
                        string json = File.ReadAllText(ManifestPath);
                        var loaded = JsonSerializer.Deserialize<MediaManifest>(json);
                        if (loaded != null)
                        {
                            currentManifest = loaded;
                            return;
                        }
                    }
                }
                catch { }

                currentManifest = new MediaManifest();
            }
        }

        private static void SaveManifest()
        {
            lock (syncLock)
            {
                try
                {
                    currentManifest.LastUpdated = DateTime.UtcNow;
                    string json = JsonSerializer.Serialize(currentManifest, new JsonSerializerOptions { WriteIndented = true });
                    File.WriteAllText(ManifestPath, json);
                }
                catch { }
            }
        }

        /// <summary>
        /// İlk kurulumda veya varsayılan klasör boşsa yüksek çözünürlüklü şık eğitim afişleri üretir.
        /// İnternet bağlantısı veya veritabanı olmadan tahta her zaman estetik ve dolu görünür.
        /// </summary>
        /// <summary>
        /// İlk kurulumda veya varsayılan klasör boşsa yüksek çözünürlüklü şık eğitim afişleri üretir.
        /// İnternet bağlantısı veya veritabanı olmadan tahta her zaman estetik ve dolu görünür.
        /// </summary>
        private static void EnsureDefaultAssets()
        {
            try
            {
                string v2Flag = Path.Combine(DefaultDir, ".v2_pro_assets");
                string poster1 = Path.Combine(DefaultDir, "default_poster_1.jpg");
                string poster2 = Path.Combine(DefaultDir, "default_poster_2.jpg");

                // Eğer v2 bayrağı yoksa eski basit emojili posterleri temizle ve yenilerini üret
                if (!File.Exists(v2Flag))
                {
                    try { if (File.Exists(poster1)) File.Delete(poster1); } catch { }
                    try { if (File.Exists(poster2)) File.Delete(poster2); } catch { }
                }

                // ─────────────────────────────────────────────────────────────
                // AFİŞ 1: GAZİ MUSTAFA KEMAL ATATÜRK & MİLLÎ EĞİTİM VİZYONU
                // ─────────────────────────────────────────────────────────────
                if (!File.Exists(poster1))
                {
                    using (Bitmap bmp = new Bitmap(1080, 1440))
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                        // Gece Mavisi - Koyu Lacivert Gradyan Arka Plan
                        using (LinearGradientBrush bg = new LinearGradientBrush(
                            new Rectangle(0, 0, 1080, 1440),
                            Color.FromArgb(10, 18, 38),
                            Color.FromArgb(24, 48, 98),
                            LinearGradientMode.Vertical))
                        {
                            g.FillRectangle(bg, 0, 0, 1080, 1440);
                        }

                        // Üst Kurumsal Rozet & Başlık
                        using (Font fontMeb = new Font("Segoe UI", 16, FontStyle.Bold))
                        using (Brush brushSky = new SolidBrush(Color.FromArgb(147, 197, 253)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("T.C. MİLLÎ EĞİTİM BAKANLIĞI", fontMeb, brushSky, new RectangleF(0, 80, 1080, 40), sfCenter);
                        }

                        using (Font fontLogo = new Font("Segoe UI", 42, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("SINIF 360", fontLogo, brushWhite, new RectangleF(0, 125, 1080, 65), sfCenter);
                        }

                        using (Font fontSub = new Font("Segoe UI", 17, FontStyle.Regular))
                        using (Brush brushLight = new SolidBrush(Color.FromArgb(191, 219, 254)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Akıllı Tahta Güvenlik ve Millî Eğitim Teknolojileri Altyapısı", fontSub, brushLight, new RectangleF(0, 195, 1080, 40), sfCenter);
                        }

                        // Üst Ayırıcı Çizgi
                        using (Pen penGold = new Pen(Color.FromArgb(120, 253, 224, 71), 2))
                        {
                            g.DrawLine(penGold, 300, 245, 780, 245);
                        }

                        // Ortadaki Buzlu Cam (Glassmorphism) Kart
                        Rectangle cardRect = new Rectangle(90, 290, 900, 840);
                        using (Brush cardBg = new SolidBrush(Color.FromArgb(32, 255, 255, 255)))
                        using (Pen cardBorder = new Pen(Color.FromArgb(70, 255, 255, 255), 2))
                        {
                            g.FillRectangle(cardBg, cardRect);
                            g.DrawRectangle(cardBorder, cardRect);
                        }

                        // Dekoratif İlim & Başarı Amblemi (Vector Çizim)
                        DrawEmblemVector(g, 540, 390, Color.FromArgb(253, 224, 71));

                        // Başlık: İLİM VE FEN VİZYONU
                        using (Font fontEmblem = new Font("Segoe UI", 15, FontStyle.Bold))
                        using (Brush brushGold = new SolidBrush(Color.FromArgb(253, 224, 71)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("TÜRKİYE YÜZYILI EĞİTİM VİZYONU", fontEmblem, brushGold, new RectangleF(90, 465, 900, 35), sfCenter);
                        }

                        // Büyük Tırnak İşareti
                        using (Font fontQuoteMark = new Font("Georgia", 64, FontStyle.Bold))
                        using (Brush brushGold = new SolidBrush(Color.FromArgb(160, 253, 224, 71)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("“", fontQuoteMark, brushGold, new RectangleF(90, 520, 900, 70), sfCenter);
                        }

                        // Ana Vecize
                        using (Font fontQuote = new Font("Segoe UI", 30, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Hayatta en hakiki mürşit ilimdir, fendir.", fontQuote, brushWhite, new RectangleF(130, 600, 820, 100), sfCenter);
                        }

                        // Alt Açıklama
                        using (Font fontDesc = new Font("Segoe UI", 18, FontStyle.Regular))
                        using (Brush brushMuted = new SolidBrush(Color.FromArgb(224, 231, 255)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("İlim ve fennin dışında kılavuz aramak gaflettir, cehalettir, doğru yoldan sapmaktır.", fontDesc, brushMuted, new RectangleF(140, 710, 800, 80), sfCenter);
                        }

                        // Ayırıcı Küçük Çizgi
                        using (Pen penWhite = new Pen(Color.FromArgb(80, 255, 255, 255), 1))
                        {
                            g.DrawLine(penWhite, 420, 810, 660, 810);
                        }

                        // İmza
                        using (Font fontAuthor = new Font("Segoe UI", 24, FontStyle.Bold | FontStyle.Italic))
                        using (Brush brushGold = new SolidBrush(Color.FromArgb(253, 224, 71)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Gazi Mustafa Kemal ATATÜRK", fontAuthor, brushGold, new RectangleF(90, 835, 900, 50), sfCenter);
                        }

                        using (Font fontFounder = new Font("Segoe UI", 15, FontStyle.Regular))
                        using (Brush brushSky = new SolidBrush(Color.FromArgb(191, 219, 254)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Türkiye Cumhuriyeti'nin Kurucusu ve Başöğretmen", fontFounder, brushSky, new RectangleF(90, 890, 900, 35), sfCenter);
                        }

                        // Alt Bilgilendirme
                        using (Font fontFooter = new Font("Segoe UI", 16, FontStyle.Regular))
                        using (Brush brushGray = new SolidBrush(Color.FromArgb(203, 213, 225)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Tüm öğretmen ve öğrencilerimize başarılı, verimli ve aydınlık bir ders dileriz.", fontFooter, brushGray, new RectangleF(60, 1260, 960, 60), sfCenter);
                        }

                        bmp.Save(poster1, ImageFormat.Jpeg);
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // AFİŞ 2: ŞANLI TÜRK BAYRAĞI & SINIF VE TAHTA KULLANIM KURALLARI
                // ─────────────────────────────────────────────────────────────
                if (!File.Exists(poster2))
                {
                    using (Bitmap bmp = new Bitmap(1080, 1440))
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                        // Asil Türk Bayrağı Kırmızısı Gradyan Arka Plan
                        using (LinearGradientBrush bg = new LinearGradientBrush(
                            new Rectangle(0, 0, 1080, 1440),
                            Color.FromArgb(195, 20, 20),
                            Color.FromArgb(125, 12, 12),
                            LinearGradientMode.Vertical))
                        {
                            g.FillRectangle(bg, 0, 0, 1080, 1440);
                        }

                        // Kusursuz Vektörel Ay-Yıldız Çizimi (Hilal ve 5 Köşeli Yıldız)
                        DrawTurkishFlagVector(g, 540, 160, 1.4f);

                        // Başlık
                        using (Font fontTitle = new Font("Segoe UI", 36, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("TÜRKİYE YÜZYILI", fontTitle, brushWhite, new RectangleF(0, 275, 1080, 65), sfCenter);
                        }

                        using (Font fontSub = new Font("Segoe UI", 18, FontStyle.Regular))
                        using (Brush brushLight = new SolidBrush(Color.FromArgb(254, 202, 202)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Eğitimde, Bilimde ve Teknolojide Geleceğe!", fontSub, brushLight, new RectangleF(0, 340, 1080, 40), sfCenter);
                        }

                        // Kural Kartı (Frosted Glass)
                        Rectangle tipRect = new Rectangle(90, 405, 900, 830);
                        using (Brush cardBg = new SolidBrush(Color.FromArgb(45, 0, 0, 0)))
                        using (Pen cardBorder = new Pen(Color.FromArgb(70, 255, 255, 255), 2))
                        {
                            g.FillRectangle(cardBg, tipRect);
                            g.DrawRectangle(cardBorder, tipRect);
                        }

                        // Kural Kartı Başlığı
                        using (Font fontRuleTitle = new Font("Segoe UI", 24, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("AKILLI TAHTA & SINIF KULLANIM KURALLARI", fontRuleTitle, brushWhite, new RectangleF(90, 435, 900, 50), sfCenter);
                        }

                        using (Pen penUnderline = new Pen(Color.FromArgb(253, 224, 71), 2))
                        {
                            g.DrawLine(penUnderline, 320, 495, 760, 495);
                        }

                        // 4 Temel Kural Maddesi
                        DrawRuleRow(g, 130, 530, "1", "Ders Zili ve Hazırlık",
                            "Ders zili çaldığında sınıfta yerimizi alalım, ders araç ve gereçlerimizi eksiksiz hazırlayalım.");

                        DrawRuleRow(g, 130, 675, "2", "Özenli ve Temiz Kullanım",
                            "Akıllı tahtayı sadece ders ve eğitim amaçlı kullanalım; ekrana sivri veya sert cisimlerle dokunmayalım.");

                        DrawRuleRow(g, 130, 820, "3", "Güvenlik ve Yetkilendirme",
                            "Tahta kilidini yalnızca ders öğretmenimiz açabilir; teneffüslerde ve ders bitiminde kilitli kalmasına dikkat edelim.");

                        DrawRuleRow(g, 130, 965, "4", "Ortak Teknoloji Bilinci",
                            "Sınıfımızdaki tüm teknolojik donanımları koruyarak temiz, sağlam ve çalışır halde gelecek nesillere aktaralım.");

                        // Kural Kartı Altı Güvence Notu
                        using (Font fontFooter = new Font("Segoe UI", 15, FontStyle.Regular))
                        using (Brush brushPink = new SolidBrush(Color.FromArgb(254, 226, 226)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Sınıf360 Akıllı Tahta Güvenlik ve Yönetim Sistemi okul ağınızda aktiftir.", fontFooter, brushPink, new RectangleF(60, 1265, 960, 50), sfCenter);
                        }

                        bmp.Save(poster2, ImageFormat.Jpeg);
                    }
                }

                // Başarılı v2 bayrağını oluştur
                try { File.WriteAllText(v2Flag, DateTime.UtcNow.ToString("o")); } catch { }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"EnsureDefaultAssets error: {ex.Message}");
            }
        }

        private static void DrawEmblemVector(Graphics g, float cx, float cy, Color color)
        {
            using (Pen pen = new Pen(color, 3))
            {
                g.DrawEllipse(pen, cx - 45, cy - 45, 90, 90);
                using (Pen penDotted = new Pen(Color.FromArgb(160, color), 1.5f) { DashStyle = DashStyle.Dash })
                {
                    g.DrawEllipse(penDotted, cx - 38, cy - 38, 76, 76);
                }
            }
            // Ortada 8 köşeli yıldız sembolü
            PointF[] starPoints = new PointF[16];
            for (int i = 0; i < 16; i++)
            {
                float r = (i % 2 == 0) ? 26 : 12;
                double angle = (i * 22.5 - 90) * Math.PI / 180.0;
                starPoints[i] = new PointF(cx + (float)(r * Math.Cos(angle)), cy + (float)(r * Math.Sin(angle)));
            }
            using (SolidBrush brush = new SolidBrush(color))
            {
                g.FillPolygon(brush, starPoints);
            }
        }

        private static void DrawTurkishFlagVector(Graphics g, float cx, float cy, float scale)
        {
            // Hilal (Crescent)
            float outerR = 52 * scale;
            float innerR = 41.6f * scale;
            float shift = 13 * scale;

            using (GraphicsPath outerPath = new GraphicsPath())
            {
                outerPath.AddEllipse(cx - outerR - 15 * scale, cy - outerR, outerR * 2, outerR * 2);
                using (GraphicsPath innerPath = new GraphicsPath())
                {
                    innerPath.AddEllipse(cx - innerR - 15 * scale + shift, cy - innerR, innerR * 2, innerR * 2);
                    using (Region reg = new Region(outerPath))
                    {
                        reg.Exclude(innerPath);
                        using (SolidBrush brushWhite = new SolidBrush(Color.White))
                        {
                            g.FillRegion(brushWhite, reg);
                        }
                    }
                }
            }

            // 5 Köşeli Yıldız
            float starCx = cx + 38 * scale;
            float starCy = cy;
            float rOuter = 21 * scale;
            float rInner = 8.5f * scale;
            PointF[] star = new PointF[10];
            for (int i = 0; i < 10; i++)
            {
                float r = (i % 2 == 0) ? rOuter : rInner;
                double angle = (i * 36 - 90) * Math.PI / 180.0;
                star[i] = new PointF(starCx + (float)(r * Math.Cos(angle)), starCy + (float)(r * Math.Sin(angle)));
            }
            using (SolidBrush brushWhite = new SolidBrush(Color.White))
            {
                g.FillPolygon(brushWhite, star);
            }
        }

        private static void DrawRuleRow(Graphics g, float x, float y, string num, string title, string text)
        {
            // Numara Rozeti (Daire)
            using (Brush badgeBg = new SolidBrush(Color.FromArgb(253, 224, 71)))
            using (Font fontNum = new Font("Segoe UI", 16, FontStyle.Bold))
            using (Brush brushDark = new SolidBrush(Color.FromArgb(15, 23, 42)))
            using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
            {
                g.FillEllipse(badgeBg, x, y, 42, 42);
                g.DrawString(num, fontNum, brushDark, new RectangleF(x, y, 42, 42), sfCenter);
            }

            // Başlık
            using (Font fontRuleTitle = new Font("Segoe UI", 18, FontStyle.Bold))
            using (Brush brushWhite = new SolidBrush(Color.White))
            {
                g.DrawString(title, fontRuleTitle, brushWhite, new PointF(x + 56, y));
            }

            // Metin
            using (Font fontRuleText = new Font("Segoe UI", 15, FontStyle.Regular))
            using (Brush brushLight = new SolidBrush(Color.FromArgb(254, 226, 226)))
            {
                g.DrawString(text, fontRuleText, brushLight, new RectangleF(x + 56, y + 30, 760, 75));
            }
        }

        /// <summary>
        /// Yönetici panelinden gelen gerçek zamanlı medya yükleme komutunu işler.
        /// Çoklu afiş ve çoklu duyuru içeren paketleri indirir, manifest'i günceller.
        /// </summary>
        public static async Task<bool> ProcessDispatchAsync(string jsonPayload)
        {
            try
            {
                using (JsonDocument doc = JsonDocument.Parse(jsonPayload))
                {
                    var root = doc.RootElement;
                    string id = root.TryGetProperty("package_id", out var pId) ? (pId.GetString() ?? "") : "";
                    if (string.IsNullOrEmpty(id))
                    {
                        id = root.TryGetProperty("id", out var pLegacyId) ? (pLegacyId.GetString() ?? "") : Guid.NewGuid().ToString("N");
                    }

                    string packageTitle = root.TryGetProperty("package_title", out var pt) ? (pt.GetString() ?? "") : "";
                    if (string.IsNullOrEmpty(packageTitle))
                    {
                        packageTitle = root.TryGetProperty("title", out var pt2) ? (pt2.GetString() ?? "") : "Yayın Paketi";
                    }

                    string packageVersion = root.TryGetProperty("package_version", out var pv) ? (pv.GetString() ?? "v1.0") : "v1.0";

                    DateTime validFrom = DateTime.MinValue;
                    if (root.TryGetProperty("valid_from", out var propFrom))
                    {
                        string sFrom = propFrom.GetString() ?? "";
                        if (DateTimeOffset.TryParse(sFrom, out var dtoFrom)) validFrom = dtoFrom.LocalDateTime;
                        else if (DateTime.TryParse(sFrom, out var dtFrom)) validFrom = dtFrom;
                    }

                    DateTime validTo = DateTime.MaxValue;
                    if (root.TryGetProperty("valid_to", out var propTo))
                    {
                        string sTo = propTo.GetString() ?? "";
                        if (DateTimeOffset.TryParse(sTo, out var dtoTo)) validTo = dtoTo.LocalDateTime;
                        else if (DateTime.TryParse(sTo, out var dtTo)) validTo = dtTo;
                    }

                    List<MediaItem> newItems = new List<MediaItem>();

                    // 1. Çoklu item desteği (Yeni Paket Formatı)
                    if (root.TryGetProperty("items", out var propItems) && propItems.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var el in propItems.EnumerateArray())
                        {
                            string itemId = el.TryGetProperty("id", out var piId) ? (piId.GetString() ?? Guid.NewGuid().ToString("N")) : Guid.NewGuid().ToString("N");
                            string itemType = el.TryGetProperty("type", out var piType) ? (piType.GetString() ?? "poster") : "poster";
                            string itemTitle = el.TryGetProperty("title", out var piTitle) ? (piTitle.GetString() ?? "") : "";
                            string itemContent = el.TryGetProperty("content", out var piContent) ? (piContent.GetString() ?? "") : "";
                            string itemImageUrl = el.TryGetProperty("image_url", out var piUrl) ? (piUrl.GetString() ?? "") : "";

                            string localPath = "";
                            if (!string.IsNullOrEmpty(itemImageUrl))
                            {
                                string ext = Path.GetExtension(itemImageUrl);
                                if (string.IsNullOrEmpty(ext) || ext.Length > 5) ext = ".jpg";
                                string fileName = $"{itemId}{ext}";
                                localPath = Path.Combine(PostersDir, fileName);

                                if (!File.Exists(localPath))
                                {
                                    try
                                    {
                                        byte[] bytes = await downloadClient.GetByteArrayAsync(itemImageUrl);
                                        await File.WriteAllBytesAsync(localPath, bytes);
                                    }
                                    catch { }
                                }
                            }

                            newItems.Add(new MediaItem
                            {
                                Id = itemId,
                                Type = itemType,
                                Title = itemTitle,
                                Content = itemContent,
                                ImageUrl = itemImageUrl,
                                LocalPath = localPath,
                                ValidFrom = validFrom,
                                ValidTo = validTo
                            });
                        }
                    }
                    else
                    {
                        // Tekil format (Geriye uyumluluk)
                        string type = root.TryGetProperty("type", out var propType) ? propType.GetString() ?? "poster" : "poster";
                        string title = root.TryGetProperty("title", out var propTitle) ? propTitle.GetString() ?? "" : "";
                        string content = root.TryGetProperty("content", out var propContent) ? propContent.GetString() ?? "" : "";
                        string imageUrl = root.TryGetProperty("image_url", out var propUrl) ? propUrl.GetString() ?? "" : "";

                        string localPath = "";
                        if (!string.IsNullOrEmpty(imageUrl))
                        {
                            string ext = Path.GetExtension(imageUrl);
                            if (string.IsNullOrEmpty(ext) || ext.Length > 5) ext = ".jpg";
                            string fileName = $"{id}{ext}";
                            localPath = Path.Combine(PostersDir, fileName);

                            byte[] bytes = await downloadClient.GetByteArrayAsync(imageUrl);
                            await File.WriteAllBytesAsync(localPath, bytes);
                        }

                        newItems.Add(new MediaItem
                        {
                            Id = id,
                            Type = type,
                            Title = title,
                            Content = content,
                            ImageUrl = imageUrl,
                            LocalPath = localPath,
                            ValidFrom = validFrom,
                            ValidTo = validTo
                        });
                    }

                    lock (syncLock)
                    {
                        // Eski afiş dosyalarından artık kullanılmayanları yerel diskten temizle
                        HashSet<string> currentFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                        foreach (var it in newItems)
                        {
                            if (!string.IsNullOrEmpty(it.LocalPath)) currentFiles.Add(it.LocalPath);
                        }

                        if (Directory.Exists(PostersDir))
                        {
                            foreach (var f in Directory.GetFiles(PostersDir))
                            {
                                if (!currentFiles.Contains(f))
                                {
                                    try { File.Delete(f); } catch { }
                                }
                            }
                        }

                        currentManifest.Items = newItems;
                        currentManifest.ActiveMediaId = id;
                        currentManifest.PackageTitle = packageTitle;
                        currentManifest.PackageVersion = packageVersion;
                        currentManifest.ValidFrom = validFrom;
                        currentManifest.ValidTo = validTo;
                        SaveManifest();
                    }

                    return true;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ProcessDispatchAsync error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Mevcut yayın paketinin süresini uzatmak veya kısaltmak için çağrılır.
        /// Görseller tekrar indirilmez; sadece geçerlilik tarihleri güncellenir.
        /// </summary>
        public static bool UpdateDuration(string jsonPayload)
        {
            try
            {
                using (JsonDocument doc = JsonDocument.Parse(jsonPayload))
                {
                    var root = doc.RootElement;
                    DateTime validFrom = DateTime.MinValue;
                    if (root.TryGetProperty("valid_from", out var propFrom))
                    {
                        string sFrom = propFrom.GetString() ?? "";
                        if (DateTimeOffset.TryParse(sFrom, out var dtoFrom)) validFrom = dtoFrom.LocalDateTime;
                        else if (DateTime.TryParse(sFrom, out var dtFrom)) validFrom = dtFrom;
                    }

                    DateTime validTo = DateTime.MaxValue;
                    if (root.TryGetProperty("valid_to", out var propTo))
                    {
                        string sTo = propTo.GetString() ?? "";
                        if (DateTimeOffset.TryParse(sTo, out var dtoTo)) validTo = dtoTo.LocalDateTime;
                        else if (DateTime.TryParse(sTo, out var dtTo)) validTo = dtTo;
                    }

                    lock (syncLock)
                    {
                        currentManifest.ValidFrom = validFrom;
                        currentManifest.ValidTo = validTo;
                        foreach (var item in currentManifest.Items)
                        {
                            item.ValidFrom = validFrom;
                            item.ValidTo = validTo;
                        }
                        SaveManifest();
                    }
                    return true;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"UpdateDuration error: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Yönetici tarafından tahta afiş/duyurusu sıfırlandığında çağrılır.
        /// </summary>
        public static void ResetToDefault()
        {
            lock (syncLock)
            {
                currentManifest.ActiveMediaId = "DEFAULT";
                // Yerel özel afiş dosyalarını temizle
                foreach (var item in currentManifest.Items)
                {
                    try
                    {
                        if (!string.IsNullOrEmpty(item.LocalPath) && File.Exists(item.LocalPath))
                        {
                            File.Delete(item.LocalPath);
                        }
                    }
                    catch { }
                }
                currentManifest.Items.Clear();
                SaveManifest();
            }
        }

        /// <summary>
        /// Şu an geçerli olan afişlerin yerel dosya yollarını döner.
        /// Eğer aktif ve süresi geçerli bir afiş yoksa DEFAULT afişleri döner.
        /// </summary>
        public static List<string> GetActivePosterFilePaths()
        {
            var now = DateTime.Now;
            var list = new List<string>();

            lock (syncLock)
            {
                foreach (var item in currentManifest.Items)
                {
                    if (item.Type == "poster" && !string.IsNullOrEmpty(item.LocalPath) && File.Exists(item.LocalPath))
                    {
                        // 15 dakika geriye tolerans ile anında gösterim sağla
                        if (now >= item.ValidFrom.AddMinutes(-15) && now <= item.ValidTo)
                        {
                            list.Add(item.LocalPath);
                        }
                    }
                }
            }

            // Eğer geçerli özel afiş yoksa varsayılan klasöründeki afişleri ekle
            if (list.Count == 0 && Directory.Exists(DefaultDir))
            {
                list.AddRange(Directory.GetFiles(DefaultDir, "*.jpg"));
                list.AddRange(Directory.GetFiles(DefaultDir, "*.png"));
            }

            return list;
        }

        /// <summary>
        /// Şu an geçerli olan duyuruları döner.
        /// Eğer aktif duyuru yoksa varsayılan duyuruları döner.
        /// </summary>
        public static List<MediaItem> GetActiveAnnouncements()
        {
            var now = DateTime.Now;
            var list = new List<MediaItem>();

            lock (syncLock)
            {
                foreach (var item in currentManifest.Items)
                {
                    if (item.Type == "announcement")
                    {
                        if (now >= item.ValidFrom.AddMinutes(-15) && now <= item.ValidTo)
                        {
                            list.Add(item);
                        }
                    }
                }
            }

            if (list.Count == 0)
            {
                // Varsayılan zengin duyuru listesi
                list.Add(new MediaItem
                {
                    Id = "default_ann_1",
                    Type = "announcement",
                    Title = "Ders Zili ve Sınıf Düzeni",
                    Content = "Ders zili çaldığında sınıfta yerimizi alalım, ders araç gereçlerimizi hazırlayalım.",
                    ValidFrom = DateTime.MinValue,
                    ValidTo = DateTime.MaxValue
                });

                list.Add(new MediaItem
                {
                    Id = "default_ann_2",
                    Type = "announcement",
                    Title = "Akıllı Tahta Kullanımı",
                    Content = "Akıllı tahtalarımızı temiz ve özenli kullanalım, ders bitiminde kilitlendiğini kontrol edelim.",
                    ValidFrom = DateTime.MinValue,
                    ValidTo = DateTime.MaxValue
                });

                list.Add(new MediaItem
                {
                    Id = "default_ann_3",
                    Type = "announcement",
                    Title = "Sınıf360 Aktif",
                    Content = "Sınıf360 Akıllı Tahta Güvenlik ve Yönetim Sistemi okul ağınızda kesintisiz aktiftir.",
                    ValidFrom = DateTime.MinValue,
                    ValidTo = DateTime.MaxValue
                });
            }

            return list;
        }

        /// <summary>
        /// Tahtanın şu an hangi afiş/duyuruda olduğunu raporlamak için ID döner (veya 'DEFAULT').
        /// Panelde "Hangi tahta hangi afişte?", "Eski afişte kalanlar" kontrolü bu ID ile yapılır.
        /// </summary>
        public static string GetActiveMediaId()
        {
            var now = DateTime.Now;
            lock (syncLock)
            {
                foreach (var item in currentManifest.Items)
                {
                    if (now >= item.ValidFrom.AddMinutes(-15) && now <= item.ValidTo)
                    {
                        return item.Id;
                    }
                }
            }
            return "DEFAULT";
        }
    }
}
