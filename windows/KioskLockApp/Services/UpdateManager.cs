using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace KioskLockApp.Services
{
    public static class UpdateManager
    {
        public static async Task CheckAndApplyUpdatesAsync()
        {
            try
            {
                var (hasUpdate, downloadUrl, newVersion) = await SecureSupabase.CheckForUpdatesAsync();

                if (hasUpdate && !string.IsNullOrEmpty(downloadUrl))
                {
                    string tempFolder = Path.GetTempPath();
                    string tempZipPath = Path.Combine(tempFolder, $"TahtaUpdate_{newVersion}.zip");

                    // Dosyayı İndir
                    using (HttpClient client = new HttpClient())
                    {
                        var response = await client.GetAsync(downloadUrl);
                        response.EnsureSuccessStatusCode();

                        using (var fs = new FileStream(tempZipPath, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            await response.Content.CopyToAsync(fs);
                        }
                    }

                    string appFolder = AppDomain.CurrentDomain.BaseDirectory;
                    string updaterPath = Path.Combine(appFolder, "TahtaUpdater.exe");

                    if (File.Exists(updaterPath))
                    {
                        // Updater'ı çalıştır
                        ProcessStartInfo startInfo = new ProcessStartInfo(updaterPath)
                        {
                            Arguments = $"\"{tempZipPath}\" \"{appFolder}\"",
                            UseShellExecute = true,
                            CreateNoWindow = true // CMD ekranını gizler
                        };
                        Process.Start(startInfo);

                        // Updater'ın çalışıp Mutex'i alabilmesi için 1 saniye mola ver
                        await Task.Delay(1000);

                        // Kendini kapat ki dosyalar ezilebilsin
                        Environment.Exit(0);
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine("Sessiz güncelleme başarısız: " + ex.Message);
            }
        }
    }
}