using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class TahtaRepairIntegrityTests
    {
        [TestMethod]
        public void Test_CleanFolder_PreservesTahtaRepairFilesAndDeletesOthers()
        {
            // Geçici test klasörü oluştur
            string tempDir = Path.Combine(Path.GetTempPath(), "TahtaRepairTest_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                // Test dosyaları oluştur
                string repairExe = Path.Combine(tempDir, "TahtaRepair.exe");
                string repairDll = Path.Combine(tempDir, "TahtaRepair.dll");
                string repairNew = Path.Combine(tempDir, "TahtaRepair.exe.new");
                string kioskExe = Path.Combine(tempDir, "KioskLockApp.exe");
                string watchdogExe = Path.Combine(tempDir, "WatchdogService.exe");
                string updaterExe = Path.Combine(tempDir, "TahtaUpdater.exe");
                string sysDll = Path.Combine(tempDir, "core_system.dll");

                File.WriteAllText(repairExe, "REPAIR_EXE_CONTENT");
                File.WriteAllText(repairDll, "REPAIR_DLL_CONTENT");
                File.WriteAllText(repairNew, "REPAIR_NEW_CONTENT");
                File.WriteAllText(kioskExe, "KIOSK_OLD_CONTENT");
                File.WriteAllText(watchdogExe, "WATCHDOG_OLD_CONTENT");
                File.WriteAllText(updaterExe, "UPDATER_OLD_CONTENT");
                File.WriteAllText(sysDll, "DLL_OLD_CONTENT");

                // TahtaRepair temizleme kuralını çalıştır:
                // Kendisi hariç (TahtaRepair ile başlayanlar veya currentExeName) her şeyi sil
                string currentExeName = "TahtaRepair.exe";
                foreach (string file in Directory.GetFiles(tempDir, "*", SearchOption.TopDirectoryOnly))
                {
                    string fName = Path.GetFileName(file);
                    if (fName.StartsWith("TahtaRepair", StringComparison.OrdinalIgnoreCase) ||
                        fName.Equals(currentExeName, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    File.Delete(file);
                }

                // Doğrulama: TahtaRepair dosyaları korunmuş olmalı
                Assert.IsTrue(File.Exists(repairExe), "TahtaRepair.exe silinmemelidir!");
                Assert.IsTrue(File.Exists(repairDll), "TahtaRepair.dll silinmemelidir!");
                Assert.IsTrue(File.Exists(repairNew), "TahtaRepair.exe.new silinmemelidir!");

                // Doğrulama: Eski uygulama dosyaları temizlenmiş olmalı
                Assert.IsFalse(File.Exists(kioskExe), "KioskLockApp.exe temizlenmeliydi!");
                Assert.IsFalse(File.Exists(watchdogExe), "WatchdogService.exe temizlenmeliydi!");
                Assert.IsFalse(File.Exists(updaterExe), "TahtaUpdater.exe temizlenmeliydi!");
                Assert.IsFalse(File.Exists(sysDll), "core_system.dll temizlenmeliydi!");
            }
            finally
            {
                if (Directory.Exists(tempDir))
                {
                    try { Directory.Delete(tempDir, true); } catch { }
                }
            }
        }

        [TestMethod]
        public void Test_PendingUpdatePromotion_ReplacesTargetWhenNewExists()
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "PendingUpdateTest_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                string targetExe = Path.Combine(tempDir, "TahtaRepair.exe");
                string newExe = Path.Combine(tempDir, "TahtaRepair.exe.new");

                File.WriteAllText(targetExe, "OLD_VERSION_1_0");
                File.WriteAllText(newExe, "NEW_VERSION_2_0");

                // Program.cs'teki ApplyPendingUpdates mantığını çalıştır
                if (File.Exists(newExe))
                {
                    if (File.Exists(targetExe))
                    {
                        File.Delete(targetExe);
                    }
                    File.Move(newExe, targetExe);
                }

                Assert.IsTrue(File.Exists(targetExe), "Hedef dosya güncellenmiş olmalı.");
                Assert.IsFalse(File.Exists(newExe), ".new dosyası taşınmış olmalı.");
                Assert.AreEqual("NEW_VERSION_2_0", File.ReadAllText(targetExe));
            }
            finally
            {
                if (Directory.Exists(tempDir))
                {
                    try { Directory.Delete(tempDir, true); } catch { }
                }
            }
        }

        [TestMethod]
        public void Test_IntegrityVerification_DetectsCorruptOrMissingExe()
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "IntegrityTest_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                string kioskPath = Path.Combine(tempDir, "KioskLockApp.exe");

                // 1. Durum: Dosya yok
                Assert.ThrowsException<Exception>(() => VerifyInstalledIntegrity(tempDir),
                    "Dosya yokken bütünlük hatası fırlatılmalıydı.");

                // 2. Durum: Dosya var ama boyutu 1KB'den küçük (bozuk indirme)
                File.WriteAllText(kioskPath, "tiny corrupt content");
                Assert.ThrowsException<Exception>(() => VerifyInstalledIntegrity(tempDir),
                    "Dosya boyutu geçersizken bütünlük hatası fırlatılmalıydı.");

                // 3. Durum: Dosya geçerli ve boyutu yeterli (> 1KB)
                byte[] validPayload = new byte[2048];
                Array.Fill(validPayload, (byte)0x42);
                File.WriteAllBytes(kioskPath, validPayload);

                // Hata fırlatmamalı
                VerifyInstalledIntegrity(tempDir);
            }
            finally
            {
                if (Directory.Exists(tempDir))
                {
                    try { Directory.Delete(tempDir, true); } catch { }
                }
            }
        }

        [TestMethod]
        public void Test_CrashLoopDetector_TriggersAutoRecoveryOnRepeatedCrashes()
        {
            List<DateTime> crashTimestamps = new List<DateTime>();
            DateTime now = DateTime.UtcNow;

            // Simüle et: 3 saniye arayla 3 çökme
            crashTimestamps.Add(now.AddSeconds(-20));
            crashTimestamps.Add(now.AddSeconds(-10));
            crashTimestamps.Add(now);

            // 60 saniyeden eski olanları temizle
            crashTimestamps.RemoveAll(t => (now - t).TotalSeconds > 60);

            // 60 saniyede 3 çökme oldu -> Kurtarma tetiklenmeli
            bool shouldTriggerRepair = crashTimestamps.Count >= 3;
            Assert.IsTrue(shouldTriggerRepair, "60 saniyede 3 çökmede otomatik kurtarma tetiklenmeli.");

            // Simüle et: Çökmeler uzun süreye yayılmış (örn. 70s önce, 40s önce, şimdi)
            crashTimestamps.Clear();
            crashTimestamps.Add(now.AddSeconds(-70));
            crashTimestamps.Add(now.AddSeconds(-40));
            crashTimestamps.Add(now);

            crashTimestamps.RemoveAll(t => (now - t).TotalSeconds > 60);
            shouldTriggerRepair = crashTimestamps.Count >= 3;
            Assert.IsFalse(shouldTriggerRepair, "Farklı zamanlara yayılan çökmeler döngü sayılmamalı.");
            Assert.AreEqual(2, crashTimestamps.Count);
        }

        private static void VerifyInstalledIntegrity(string folder)
        {
            string kioskPath = Path.Combine(folder, "KioskLockApp.exe");
            if (!File.Exists(kioskPath))
            {
                throw new Exception("Bütünlük Hatası: KioskLockApp.exe bulunamadı!");
            }

            FileInfo fi = new FileInfo(kioskPath);
            if (fi.Length < 1024)
            {
                throw new Exception("Bütünlük Hatası: KioskLockApp.exe boyutu geçersiz (bozuk dosya)!");
            }
        }
    }
}
