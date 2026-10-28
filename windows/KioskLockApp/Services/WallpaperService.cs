using System;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    /// <summary>
    /// Akıllı tahtalarda uzaktan masaüstü duvar kâğıdı yönetimi ve zırh entegrasyonu.
    /// Web panelinden gelen SET_WALLPAPER komutunu işler, görseli yerel diske indirir,
    /// NoChangingWallPaper politikasını geçici açarak Win32 SystemParametersInfo(SPI_SETDESKWALLPAPER)
    /// ile masaüstü duvar kâğıdını günceller ve ardından politikayı tekrar kilitler.
    /// </summary>
    public static class WallpaperService
    {
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SystemParametersInfo(uint uAction, uint uParam, string lpvParam, uint fuWinIni);

        public const uint SPI_SETDESKWALLPAPER = 0x0014;
        public const uint SPIF_UPDATEINIFILE = 0x01;
        public const uint SPIF_SENDCHANGE = 0x02;

        public static string GetWallpaperCacheDir()
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string mediaDir = Path.Combine(baseDir, "Media");
            if (Directory.Exists(mediaDir)) return mediaDir;

            string programData = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "AkilliTahtaKilitSistemi",
                "Media");
            if (!Directory.Exists(programData))
            {
                try { Directory.CreateDirectory(programData); } catch { }
            }
            return Directory.Exists(programData) ? programData : Path.GetTempPath();
        }

        /// <summary>
        /// Masaüstü duvar kâğıdını Windows Shell API üzerinden uygular.
        /// NoChangingWallPaper politikasını geçici olarak açıp duvar kâğıdını günceller ve anında geri kilitler.
        /// </summary>
        public static bool ApplyWallpaper(string localFilePath, string style = "fill", RegistryKey? testDeskKey = null, RegistryKey? testPolicyKey = null)
        {
            if (string.IsNullOrWhiteSpace(localFilePath) || !File.Exists(localFilePath))
            {
                return false;
            }

            try
            {
                // 1. Duvar kâğıdı koruma politikasını (NoChangingWallPaper) geçici olarak devre dışı bırak
                SetWallpaperPolicyLocked(false, testPolicyKey);

                // 2. WallpaperStyle ve TileWallpaper ayarlarını kayıt defterine uygula
                SetWallpaperStyleRegistry(style, testDeskKey);

                // 3. Windows Shell API üzerinden masaüstü duvar kâğıdını uygula (Win32 API)
                bool success = true;
                if (OperatingSystem.IsWindows() && testDeskKey == null)
                {
                    success = SystemParametersInfo(
                        SPI_SETDESKWALLPAPER,
                        0,
                        localFilePath,
                        SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                }

                // 4. Politika zırhını HEMEN geri kilitle (Kullanıcılar manuel değiştiremez)
                SetWallpaperPolicyLocked(true, testPolicyKey);
                return success;
            }
            catch
            {
                SetWallpaperPolicyLocked(true, testPolicyKey);
                return false;
            }
        }

        /// <summary>
        /// Windows Duvar Kâğıdı Yerleşim Stilini ayarlar:
        /// "10" = Fill (Aspect-Fill / Doldur, merkezden kırpma - varsayılan)
        /// "6"  = Fit (Ekrana sığdır)
        /// "2"  = Stretch (Uzat / Yay)
        /// "0"  = Center / Tile
        /// </summary>
        public static void SetWallpaperStyleRegistry(string style, RegistryKey? testKey = null)
        {
            string wpStyle = "10";
            string tileWp = "0";

            switch (style.ToLowerInvariant())
            {
                case "fit":
                    wpStyle = "6";
                    tileWp = "0";
                    break;
                case "stretch":
                    wpStyle = "2";
                    tileWp = "0";
                    break;
                case "tile":
                    wpStyle = "0";
                    tileWp = "1";
                    break;
                case "center":
                    wpStyle = "0";
                    tileWp = "0";
                    break;
                case "fill":
                default:
                    wpStyle = "10";
                    tileWp = "0";
                    break;
            }

            try
            {
                if (testKey != null)
                {
                    testKey.SetValue("WallpaperStyle", wpStyle, RegistryValueKind.String);
                    testKey.SetValue("TileWallpaper", tileWp, RegistryValueKind.String);
                    return;
                }

                if (OperatingSystem.IsWindows())
                {
                    using var key = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop", true);
                    key?.SetValue("WallpaperStyle", wpStyle, RegistryValueKind.String);
                    key?.SetValue("TileWallpaper", tileWp, RegistryValueKind.String);
                }
            }
            catch { }
        }

        /// <summary>
        /// NoChangingWallPaper politikasını HKCU ve HKLM seviyelerinde kilitler veya açar.
        /// </summary>
        public static void SetWallpaperPolicyLocked(bool locked, RegistryKey? testRootKey = null)
        {
            if (testRootKey != null)
            {
                try
                {
                    using var key = testRootKey.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                    if (locked) key?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
                    else key?.DeleteValue("NoChangingWallPaper", false);
                }
                catch { }
                return;
            }

            if (!OperatingSystem.IsWindows()) return;

            // HKCU
            try
            {
                using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                if (locked) key?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
                else key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }

            // HKLM
            try
            {
                using var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                if (locked) key?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
                else key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }
        }

        /// <summary>
        /// SET_WALLPAPER komutunun JSON gövdesini ayrıştırıp görseli indirir ve uygular.
        /// Örnek: SET_WALLPAPER:{"url":"https://.../wallpaper.jpg","style":"fill"}
        /// </summary>
        public static async Task<bool> ProcessWallpaperCommandAsync(string payloadJson)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(payloadJson)) return false;

                string? url = null;
                string style = "fill";

                try
                {
                    using var doc = JsonDocument.Parse(payloadJson);
                    if (doc.RootElement.TryGetProperty("url", out var urlEl))
                        url = urlEl.GetString();
                    if (doc.RootElement.TryGetProperty("style", out var styleEl))
                        style = styleEl.GetString() ?? "fill";
                }
                catch
                {
                    if (payloadJson.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
                        payloadJson.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                    {
                        url = payloadJson.Trim();
                    }
                }

                if (string.IsNullOrWhiteSpace(url)) return false;

                string cacheDir = GetWallpaperCacheDir();
                string extension = ".jpg";
                try
                {
                    var uri = new Uri(url);
                    string ext = Path.GetExtension(uri.AbsolutePath);
                    if (!string.IsNullOrEmpty(ext) && (ext.Equals(".png", StringComparison.OrdinalIgnoreCase) ||
                                                       ext.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                                                       ext.Equals(".jpeg", StringComparison.OrdinalIgnoreCase) ||
                                                       ext.Equals(".bmp", StringComparison.OrdinalIgnoreCase)))
                    {
                        extension = ext;
                    }
                }
                catch { }

                string localFile = Path.Combine(cacheDir, $"desktop_wallpaper_{DateTime.UtcNow.Ticks}{extension}");

                // Görseli indir
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(25) };
                var imageBytes = await client.GetByteArrayAsync(url);
                if (imageBytes == null || imageBytes.Length == 0) return false;

                await File.WriteAllBytesAsync(localFile, imageBytes);

                // Duvar kâğıdını uygula
                bool applied = ApplyWallpaper(localFile, style);
                if (applied)
                {
                    SecureSupabase.SetRegistryValue("LastWallpaperUrl", url);
                    SecureSupabase.SetRegistryValue("LastWallpaperPath", localFile);

                    // Eski geçici duvar kâğıdı dosyalarını temizle
                    try
                    {
                        string currentFileName = Path.GetFileName(localFile);
                        var dir = new DirectoryInfo(cacheDir);
                        foreach (var file in dir.GetFiles("desktop_wallpaper_*"))
                        {
                            if (!string.Equals(file.Name, currentFileName, StringComparison.OrdinalIgnoreCase))
                            {
                                try { file.Delete(); } catch { }
                            }
                        }
                    }
                    catch { }
                }
                return applied;
            }
            catch
            {
                return false;
            }
        }
    }
}
