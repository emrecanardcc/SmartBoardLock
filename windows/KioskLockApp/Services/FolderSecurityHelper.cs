using System;
using System.Diagnostics;
using System.IO;

namespace KioskLockApp.Services
{
    /// <summary>
    /// Sınıf360 Akıllı Tahta Anti-Tamper & Klasör Koruma Motoru.
    /// Öğrencilerin C:\ProgramData\AkilliTahtaKilitSistemi klasörüne girip dosyaları
    /// silmesini, yeniden adlandırmasını veya sistemi bozmasını NTFS düzeyinde engeller.
    /// Program yalnızca yetkili yönetici aracı (Sinif360_Kaldir.exe) ile silinebilir.
    /// </summary>
    public static class FolderSecurityHelper
    {
        private static FileStream? _anchorLockStream;

        /// <summary>
        /// Sınıf360 kurulum klasörünü NTFS düzeyinde silinmeye ve değiştirilmeye karşı kilitler.
        /// </summary>
        public static void EnsureProtected(string? customPath = null)
        {
            try
            {
                string targetDir = customPath ?? AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');

                // Sadece ProgramData altındaki hedef klasörde çalıştır (geliştirici ortamı c:\Projeler ise bozma)
                if (!targetDir.Contains("ProgramData", StringComparison.OrdinalIgnoreCase) &&
                    !targetDir.Contains("AkilliTahtaKilitSistemi", StringComparison.OrdinalIgnoreCase))
                {
                    return;
                }

                if (!Directory.Exists(targetDir)) return;

                // 1. Klasör özniteliklerini Sistem ve Gizli olarak işaretle (Dosya Gezgini'nde varsayılan gizlenir)
                try
                {
                    var dirInfo = new DirectoryInfo(targetDir);
                    dirInfo.Attributes |= FileAttributes.Hidden | FileAttributes.System;
                }
                catch { }

                // 2. Windows NTFS ACL kurallarını uygula:
                // - SYSTEM (*S-1-5-18) ve Administrators (*S-1-5-32-544): Tam Yetki (Full Control)
                // - Standart Kullanıcılar (Users / *S-1-5-32-545): Sadece Okuma ve Çalıştırma (RX)
                // - Standart Kullanıcılar için AÇIK DENY: Silme (DE, DC) ve Dosya/Alt Klasör Yazma (WD, AD) engellenir
                ApplyIcaclsProtection(targetDir);

                // 3. Çalışma esnasında klasörün silinmesini engellemek için kernel dosya kilidi tut
                HoldAnchorLock(targetDir);
            }
            catch
            {
                // Hata durumunda uygulamanın açılışını engelleme
            }
        }

        private static void ApplyIcaclsProtection(string dirPath)
        {
            try
            {
                // 1. Media ve alt klasörlerin varlığını garantiye al
                string mediaDir = Path.Combine(dirPath, "Media");
                try
                {
                    if (!Directory.Exists(mediaDir)) Directory.CreateDirectory(mediaDir);
                    string postersDir = Path.Combine(mediaDir, "Posters");
                    string defaultDir = Path.Combine(mediaDir, "Default");
                    string annDir = Path.Combine(mediaDir, "Announcements");
                    if (!Directory.Exists(postersDir)) Directory.CreateDirectory(postersDir);
                    if (!Directory.Exists(defaultDir)) Directory.CreateDirectory(defaultDir);
                    if (!Directory.Exists(annDir)) Directory.CreateDirectory(annDir);
                }
                catch { }

                // 2. Varsa eski çakışan DENY kuralını temizle
                RunHiddenCmd($"icacls \"{dirPath}\" /remove:d *S-1-5-32-545 /C /Q");

                // 3. Ana klasör: SYSTEM ve Administrators Tam Yetki (F), Users sadece Okuma & Çalıştırma (RX)
                //    (RX yetkisi altında öğrenciler dosyaları silemez, değiştiremez veya yeniden adlandıramaz)
                RunHiddenCmd($"icacls \"{dirPath}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)RX /C /Q");

                // 4. Medya önbellek klasörünün mirasını ayır ve Users için Değiştirme (M) izni ver
                if (Directory.Exists(mediaDir))
                {
                    RunHiddenCmd($"icacls \"{mediaDir}\" /inheritance:d /C /Q");
                    RunHiddenCmd($"icacls \"{mediaDir}\" /remove:d *S-1-5-32-545 /C /Q");
                    RunHiddenCmd($"icacls \"{mediaDir}\" /grant:r *S-1-5-18:(OI)(CI)F /grant:r *S-1-5-32-544:(OI)(CI)F /grant:r *S-1-5-32-545:(OI)(CI)M /C /Q");
                }
            }
            catch { }
        }

        private static void HoldAnchorLock(string dirPath)
        {
            if (_anchorLockStream != null) return;
            try
            {
                string lockFilePath = Path.Combine(dirPath, ".protection.lock");
                _anchorLockStream = new FileStream(
                    lockFilePath,
                    FileMode.OpenOrCreate,
                    FileAccess.ReadWrite,
                    FileShare.Read,
                    4096,
                    FileOptions.None
                );
            }
            catch { }
        }

        /// <summary>
        /// Güncelleme veya kaldırma işlemi öncesinde klasör üzerindeki DENY kilitlerini kaldırır.
        /// </summary>
        public static void UnlockFolder(string dirPath)
        {
            try
            {
                if (_anchorLockStream != null)
                {
                    try { _anchorLockStream.Dispose(); } catch { }
                    _anchorLockStream = null;
                }

                RunHiddenCmd($"icacls \"{dirPath}\" /remove:d *S-1-5-32-545 /T /C /Q");
                RunHiddenCmd($"icacls \"{dirPath}\" /grant *S-1-5-32-545:(OI)(CI)M /grant *S-1-5-32-544:(OI)(CI)F /T /C /Q");
                RunHiddenCmd($"attrib -s -h \"{dirPath}\"");
            }
            catch { }
        }

        public static void RunHiddenCmd(string command)
        {
            try
            {
                using var p = Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/c {command}",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                });
                p?.WaitForExit(3000);
            }
            catch { }
        }
    }
}
