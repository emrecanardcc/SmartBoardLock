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
        private static void EnsureDefaultAssets()
        {
            try
            {
                string poster1 = Path.Combine(DefaultDir, "default_poster_1.jpg");
                if (!File.Exists(poster1))
                {
                    using (Bitmap bmp = new Bitmap(900, 1200))
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                        // Şık arka plan gradyanı (Lacivert - Mavi)
                        using (LinearGradientBrush bg = new LinearGradientBrush(
                            new Rectangle(0, 0, 900, 1200),
                            Color.FromArgb(15, 23, 42),
                            Color.FromArgb(30, 58, 138),
                            LinearGradientMode.Vertical))
                        {
                            g.FillRectangle(bg, 0, 0, 900, 1200);
                        }

                        // Üst Logo / Başlık
                        using (Font fontLogo = new Font("Segoe UI", 36, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("SINIF 360", fontLogo, brushWhite, new RectangleF(0, 100, 900, 80), sfCenter);
                        }

                        using (Font fontSub = new Font("Segoe UI", 18, FontStyle.Regular))
                        using (Brush brushLight = new SolidBrush(Color.FromArgb(191, 219, 254)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Akıllı Tahta Yönetim ve Güvenlik Sistemi", fontSub, brushLight, new RectangleF(0, 180, 900, 50), sfCenter);
                        }

                        // Ortadaki İllüstrasyon / Kart
                        Rectangle cardRect = new Rectangle(100, 280, 700, 600);
                        using (Brush cardBg = new SolidBrush(Color.FromArgb(40, 255, 255, 255)))
                        using (Pen cardBorder = new Pen(Color.FromArgb(80, 255, 255, 255), 2))
                        {
                            g.FillRectangle(cardBg, cardRect);
                            g.DrawRectangle(cardBorder, cardRect);
                        }

                        using (Font fontIcon = new Font("Segoe UI", 72))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("🎓", fontIcon, brushWhite, new RectangleF(100, 340, 700, 120), sfCenter);
                        }

                        using (Font fontQuote = new Font("Segoe UI", 24, FontStyle.Bold))
                        using (Brush brushYellow = new SolidBrush(Color.FromArgb(253, 224, 71)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("\"Hayatta en hakiki mürşit ilimdir, fendir.\"", fontQuote, brushYellow, new RectangleF(120, 500, 660, 100), sfCenter);
                        }

                        using (Font fontAuthor = new Font("Segoe UI", 18, FontStyle.Italic))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Gazi Mustafa Kemal ATATÜRK", fontAuthor, brushWhite, new RectangleF(120, 620, 660, 50), sfCenter);
                        }

                        // Alt Bilgilendirme
                        using (Font fontFooter = new Font("Segoe UI", 16, FontStyle.Regular))
                        using (Brush brushGray = new SolidBrush(Color.FromArgb(203, 213, 225)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Tüm öğretmen ve öğrencilerimize başarılı, verimli bir ders dileriz.", fontFooter, brushGray, new RectangleF(50, 950, 800, 60), sfCenter);
                        }

                        bmp.Save(poster1, ImageFormat.Jpeg);
                    }
                }

                string poster2 = Path.Combine(DefaultDir, "default_poster_2.jpg");
                if (!File.Exists(poster2))
                {
                    using (Bitmap bmp = new Bitmap(900, 1200))
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        g.SmoothingMode = SmoothingMode.AntiAlias;
                        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                        using (LinearGradientBrush bg = new LinearGradientBrush(
                            new Rectangle(0, 0, 900, 1200),
                            Color.FromArgb(185, 28, 28),
                            Color.FromArgb(127, 29, 29),
                            LinearGradientMode.Vertical))
                        {
                            g.FillRectangle(bg, 0, 0, 900, 1200);
                        }

                        using (Font fontIcon = new Font("Segoe UI", 90))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("🇹🇷", fontIcon, brushWhite, new RectangleF(0, 140, 900, 150), sfCenter);
                        }

                        using (Font fontTitle = new Font("Segoe UI", 32, FontStyle.Bold))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("TÜRKİYE YÜZYILI", fontTitle, brushWhite, new RectangleF(0, 320, 900, 80), sfCenter);
                        }

                        using (Font fontSub = new Font("Segoe UI", 20, FontStyle.Regular))
                        using (Brush brushLight = new SolidBrush(Color.FromArgb(254, 202, 202)))
                        using (StringFormat sfCenter = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        {
                            g.DrawString("Eğitimde ve Bilimde İleriye!", fontSub, brushLight, new RectangleF(0, 410, 900, 50), sfCenter);
                        }

                        // Kural / İpucu Kartı
                        Rectangle tipRect = new Rectangle(100, 520, 700, 420);
                        using (Brush cardBg = new SolidBrush(Color.FromArgb(40, 0, 0, 0)))
                        using (Pen cardBorder = new Pen(Color.FromArgb(80, 255, 255, 255), 2))
                        {
                            g.FillRectangle(cardBg, tipRect);
                            g.DrawRectangle(cardBorder, tipRect);
                        }

                        using (Font fontRuleTitle = new Font("Segoe UI", 22, FontStyle.Bold))
                        using (Font fontRuleText = new Font("Segoe UI", 16, FontStyle.Regular))
                        using (Brush brushWhite = new SolidBrush(Color.White))
                        using (Brush brushLight = new SolidBrush(Color.FromArgb(254, 226, 226)))
                        {
                            g.DrawString("📌 Sınıf ve Tahta Kuralları", fontRuleTitle, brushWhite, new PointF(130, 550));
                            g.DrawString("1. Ders zili çaldığında sınıfta yerimizi alalım.\n2. Tahtayı sadece ders amaçlı ve temiz kullanalım.\n3. Nöbetçi öğretmen ve görevli uyarılarına uyalım.\n4. Ders bitiminde tahtanın kilitlendiğinden emin olalım.", fontRuleText, brushLight, new RectangleF(130, 620, 640, 300));
                        }

                        bmp.Save(poster2, ImageFormat.Jpeg);
                    }
                }
            }
            catch { }
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
