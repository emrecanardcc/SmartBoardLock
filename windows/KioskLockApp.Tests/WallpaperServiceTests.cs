using System;
using System.IO;
using System.Threading.Tasks;
using KioskLockApp.Services;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Win32;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class WallpaperServiceTests
    {
        private RegistryKey? _testRootKey;
        private string _subKeyPath = @"Software\SmartBoardTest_Wallpaper_" + Guid.NewGuid().ToString("N");

        [TestInitialize]
        public void Setup()
        {
            _testRootKey = Registry.CurrentUser.CreateSubKey(_subKeyPath);
        }

        [TestCleanup]
        public void Cleanup()
        {
            try
            {
                _testRootKey?.Close();
                Registry.CurrentUser.DeleteSubKeyTree(_subKeyPath, false);
            }
            catch { }
        }

        [TestMethod]
        public void ApplyWallpaper_WithInvalidPath_ReturnsFalse()
        {
            bool res1 = WallpaperService.ApplyWallpaper("");
            Assert.IsFalse(res1);

            bool res2 = WallpaperService.ApplyWallpaper(@"C:\non_existent_folder_xyz\dummy_wallpaper.jpg");
            Assert.IsFalse(res2);
        }

        [TestMethod]
        public void SetWallpaperStyleRegistry_MapsStylesCorrectly()
        {
            using var testDesk = _testRootKey!.CreateSubKey("Desktop");

            // Fill (Varsayılan Aspect-Fill / Center-Crop)
            WallpaperService.SetWallpaperStyleRegistry("fill", testDesk);
            Assert.AreEqual("10", testDesk.GetValue("WallpaperStyle"));
            Assert.AreEqual("0", testDesk.GetValue("TileWallpaper"));

            // Fit
            WallpaperService.SetWallpaperStyleRegistry("fit", testDesk);
            Assert.AreEqual("6", testDesk.GetValue("WallpaperStyle"));
            Assert.AreEqual("0", testDesk.GetValue("TileWallpaper"));

            // Stretch
            WallpaperService.SetWallpaperStyleRegistry("stretch", testDesk);
            Assert.AreEqual("2", testDesk.GetValue("WallpaperStyle"));
            Assert.AreEqual("0", testDesk.GetValue("TileWallpaper"));

            // Tile
            WallpaperService.SetWallpaperStyleRegistry("tile", testDesk);
            Assert.AreEqual("0", testDesk.GetValue("WallpaperStyle"));
            Assert.AreEqual("1", testDesk.GetValue("TileWallpaper"));

            // Center
            WallpaperService.SetWallpaperStyleRegistry("center", testDesk);
            Assert.AreEqual("0", testDesk.GetValue("WallpaperStyle"));
            Assert.AreEqual("0", testDesk.GetValue("TileWallpaper"));
        }

        [TestMethod]
        public void SetWallpaperPolicyLocked_SetsAndRemovesNoChangingWallPaper()
        {
            // Kilitle
            WallpaperService.SetWallpaperPolicyLocked(true, _testRootKey);
            using (var key = _testRootKey!.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"))
            {
                Assert.IsNotNull(key);
                Assert.AreEqual(1, key.GetValue("NoChangingWallPaper"));
            }

            // Kilidi kaldır (güncelleme esnası)
            WallpaperService.SetWallpaperPolicyLocked(false, _testRootKey);
            using (var key = _testRootKey!.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop"))
            {
                Assert.IsNull(key?.GetValue("NoChangingWallPaper"));
            }
        }

        [TestMethod]
        public async Task ProcessWallpaperCommandAsync_WithInvalidPayload_ReturnsFalse()
        {
            bool res1 = await WallpaperService.ProcessWallpaperCommandAsync("");
            Assert.IsFalse(res1);

            bool res2 = await WallpaperService.ProcessWallpaperCommandAsync("{}");
            Assert.IsFalse(res2);

            bool res3 = await WallpaperService.ProcessWallpaperCommandAsync("invalid-not-json");
            Assert.IsFalse(res3);
        }
    }
}
