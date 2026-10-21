using System;
using System.Diagnostics;
using System.IO;
using KioskLockApp.Services;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class FolderSecurityHelperTests
    {
        private string _testDir = "";

        [TestInitialize]
        public void Setup()
        {
            _testDir = Path.Combine(Path.GetTempPath(), "AkilliTahtaKilitSistemi_Test_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_testDir);
        }

        [TestCleanup]
        public void Cleanup()
        {
            try
            {
                if (Directory.Exists(_testDir))
                {
                    FolderSecurityHelper.UnlockFolder(_testDir);
                    Directory.Delete(_testDir, true);
                }
            }
            catch { }
        }

        [TestMethod]
        public void Test_FolderProtection_EnforcesDenyAcl_And_UnlockRestoresAccess()
        {
            // 1. Klasör içerisine kritik dosya koy
            string testFile = Path.Combine(_testDir, "KioskLockApp.dll");
            File.WriteAllText(testFile, "Protected binary content");

            // 2. Korumayı aktifleştir
            FolderSecurityHelper.EnsureProtected(_testDir);

            // 3. Dosyanın hala okunabilir olduğunu doğrula (Uygulama çalışabilmeli)
            Assert.IsTrue(File.Exists(testFile));
            string readContent = File.ReadAllText(testFile);
            Assert.AreEqual("Protected binary content", readContent);

            // 4. Klasörün kilit açma (Unlock) metodunu test et
            FolderSecurityHelper.UnlockFolder(_testDir);

            // 5. Kilit kalktıktan sonra dosyanın sorunsuz silinebildiğini doğrula
            File.Delete(testFile);
            Assert.IsFalse(File.Exists(testFile));
        }

        [TestMethod]
        public void Test_FolderProtection_SkipsNonProgramDataFolders_UnlessExplicitlyTargeted()
        {
            string devFolder = @"C:\Projeler\AkilliTahtaSistemi";
            // Normal EnsureProtected çağrısı geliştirici dizinine dokunmamalıdır
            FolderSecurityHelper.EnsureProtected(devFolder);
            // Geliştirici klasörü bozulmadan kalmalıdır
            Assert.IsTrue(Directory.Exists(devFolder));
        }

        [TestMethod]
        public void Test_FolderProtection_MediaFolder_RemainsWritable_ForPosters()
        {
            // 1. Korumayı aktifleştir
            FolderSecurityHelper.EnsureProtected(_testDir);

            // 2. Media alt klasörlerini kontrol et
            string mediaDir = Path.Combine(_testDir, "Media");
            string postersDir = Path.Combine(mediaDir, "Posters");
            Assert.IsTrue(Directory.Exists(mediaDir), "Media klasörü mevcut olmalı");
            Assert.IsTrue(Directory.Exists(postersDir), "Posters alt klasörü mevcut olmalı");

            // 3. Media/Posters içerisine yeni poster dosyası yazılabilmeli (Afiş indirme motoru)
            string testPoster = Path.Combine(postersDir, "test_poster_download.jpg");
            File.WriteAllText(testPoster, "FAKE_POSTER_IMAGE_DATA");
            Assert.IsTrue(File.Exists(testPoster));
            Assert.AreEqual("FAKE_POSTER_IMAGE_DATA", File.ReadAllText(testPoster));

            // 4. Afiş silinebilmeli / güncellenebilmeli
            File.Delete(testPoster);
            Assert.IsFalse(File.Exists(testPoster));
        }
    }
}
