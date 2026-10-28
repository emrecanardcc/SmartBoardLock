using System;
using System.Diagnostics;
using System.IO;
using KioskLockApp.Core;
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
                FolderSecurityHelper.RestoreSystemPolicies();
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

            // 2. Korumayı aktifleştir (NTFS DENY + Kernel Lock)
            FolderSecurityHelper.EnsureProtected(_testDir, synchronous: true);

            // 3. Dosyanın hala okunabilir olduğunu doğrula (Uygulama çalışabilmeli)
            Assert.IsTrue(File.Exists(testFile));
            string readContent = File.ReadAllText(testFile);
            Assert.AreEqual("Protected binary content", readContent);

            // 4. Kernel kilit aktifken dosyanın silinmeye çalışılması engellenmeli (Sharing violation veya UnauthorizedAccess)
            bool deleteBlocked = false;
            try
            {
                File.Delete(testFile);
            }
            catch (Exception)
            {
                deleteBlocked = true;
            }
            Assert.IsTrue(deleteBlocked, "Kilitli çekirdek dosyası silinememeli!");

            // 5. Klasörün kilit açma (Unlock) metodunu test et
            FolderSecurityHelper.UnlockFolder(_testDir);

            // 6. Kilit kalktıktan sonra dosyanın sorunsuz silinebildiğini doğrula
            File.Delete(testFile);
            Assert.IsFalse(File.Exists(testFile));
        }

        [TestMethod]
        public void Test_ProcessSecurity_ProtectAndUnprotect()
        {
            // DACL korumasını uygula
            bool protectedOk = ProcessSecurity.ProtectCurrentProcess();
            Assert.IsTrue(protectedOk, "ProcessSecurity.ProtectCurrentProcess başarılı olmalı");
            Assert.IsTrue(ProcessSecurity.IsProtected);

            // DACL korumasını kaldır
            bool unprotectedOk = ProcessSecurity.UnprotectCurrentProcess();
            Assert.IsTrue(unprotectedOk, "ProcessSecurity.UnprotectCurrentProcess başarılı olmalı");
            Assert.IsFalse(ProcessSecurity.IsProtected);
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

        [TestMethod]
        public void Test_SingleInstance_Mutex_BlocksSecondInstance()
        {
            string mutexName = "Global\\TestSingleInstanceMutex_" + Guid.NewGuid().ToString("N");

            // Birinci örnek mutex'i alır
            using (var firstMutex = new System.Threading.Mutex(true, mutexName, out bool createdFirst))
            {
                Assert.IsTrue(createdFirst, "İlk örnek mutex'i başarıyla almalıdır");

                // İkinci örnek aynı mutex'i almaya çalışır
                using (var secondMutex = new System.Threading.Mutex(true, mutexName, out bool createdSecond))
                {
                    Assert.IsFalse(createdSecond, "İkinci kopya mutex'i alamamalı (çifte açılma engellenmeli)");
                }
            }
        }

        [TestMethod]
        public void Test_EnforceSystemPolicies_ExecutesSafelyWithoutException()
        {
            // Metodun kısıtlı veya tam yetkili ortamlarda istisna fırlatmadan güvenle çalıştığını doğrula
            Exception? caughtEx = null;
            try
            {
                FolderSecurityHelper.EnforceSystemPolicies();
            }
            catch (Exception ex)
            {
                caughtEx = ex;
            }
            finally
            {
                FolderSecurityHelper.RestoreSystemPolicies();
            }

            Assert.IsNull(caughtEx, $"EnforceSystemPolicies istisna fırlatmamalıdır: {caughtEx?.Message}");
        }

        [TestMethod]
        public void Test_EnforceAndRestoreSystemPolicies_ManagesHKCURegistryKeys()
        {
            string testSubKeyPath = @"Software\SmartBoardLock_Test_" + Guid.NewGuid().ToString("N");
            using (var testRoot = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(testSubKeyPath))
            {
                try
                {
                    // 1. Politikaları test kovanına zorla uygula
                    FolderSecurityHelper.EnforceSystemPolicies(testRoot);

                    // 2. Değerlerin ve türlerinin başarıyla yazıldığını doğrula
                    using (var rkSys = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System"))
                    {
                        Assert.IsNotNull(rkSys, "Policies\\System anahtarı mevcut olmalı");
                        Assert.AreEqual(1, rkSys.GetValue("DisableTaskMgr"), "DisableTaskMgr 1 olmalı");
                        Assert.AreEqual(Microsoft.Win32.RegistryValueKind.DWord, rkSys.GetValueKind("DisableTaskMgr"));
                        Assert.AreEqual(1, rkSys.GetValue("DisableLockWorkstation"), "DisableLockWorkstation 1 olmalı");
                        Assert.AreEqual(Microsoft.Win32.RegistryValueKind.DWord, rkSys.GetValueKind("DisableLockWorkstation"));
                    }

                    using (var rkExp = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"))
                    {
                        Assert.IsNotNull(rkExp, "Policies\\Explorer anahtarı mevcut olmalı");
                        Assert.AreEqual(1, rkExp.GetValue("NoRun"), "NoRun 1 olmalı");
                        Assert.AreEqual(Microsoft.Win32.RegistryValueKind.DWord, rkExp.GetValueKind("NoRun"));
                    }

                    using (var rkAd = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"))
                    {
                        Assert.IsNotNull(rkAd, "Policies\\ActiveDesktop anahtarı mevcut olmalı");
                        Assert.AreEqual(1, rkAd.GetValue("NoChangingWallPaper"), "NoChangingWallPaper 1 olmalı");
                        Assert.AreEqual(Microsoft.Win32.RegistryValueKind.DWord, rkAd.GetValueKind("NoChangingWallPaper"));
                    }

                    // 3. Politikaları temizle (Restore)
                    FolderSecurityHelper.RestoreSystemPolicies(testRoot);

                    // 4. Değerlerin temizlendiğini doğrula
                    using (var rkSys = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System"))
                    {
                        Assert.IsNull(rkSys?.GetValue("DisableTaskMgr"), "DisableTaskMgr silinmiş olmalı");
                        Assert.IsNull(rkSys?.GetValue("DisableLockWorkstation"), "DisableLockWorkstation silinmiş olmalı");
                    }

                    using (var rkExp = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"))
                    {
                        Assert.IsNull(rkExp?.GetValue("NoRun"), "NoRun silinmiş olmalı");
                    }

                    using (var rkAd = testRoot.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"))
                    {
                        Assert.IsNull(rkAd?.GetValue("NoChangingWallPaper"), "NoChangingWallPaper silinmiş olmalı");
                    }

                    // 5. Canlı sistem çağrısının da istisnasız güvenle tamamlandığını doğrula
                    FolderSecurityHelper.EnforceSystemPolicies();
                    FolderSecurityHelper.RestoreSystemPolicies();
                }
                finally
                {
                    try { Microsoft.Win32.Registry.CurrentUser.DeleteSubKeyTree(testSubKeyPath, false); } catch { }
                    FolderSecurityHelper.RestoreSystemPolicies();
                }
            }
        }
    }
}
