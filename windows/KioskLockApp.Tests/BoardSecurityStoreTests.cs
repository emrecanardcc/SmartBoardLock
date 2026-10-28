using System;
using KioskLockApp.Services;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Win32;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class BoardSecurityStoreTests
    {
        private RegistryKey? _testRootKey;
        private string _subKeyPath = @"Software\SmartBoardTest_Security_" + Guid.NewGuid().ToString("N");

        [TestInitialize]
        public void Setup()
        {
            _testRootKey = Registry.CurrentUser.CreateSubKey(_subKeyPath);
            BoardSecurityStore.ClearPassword(_testRootKey);
        }

        [TestCleanup]
        public void Cleanup()
        {
            try
            {
                BoardSecurityStore.ClearPassword(_testRootKey);
                _testRootKey?.Close();
                Registry.CurrentUser.DeleteSubKeyTree(_subKeyPath, false);
            }
            catch { }
        }

        [TestMethod]
        public void SavePassword_WithInvalidInput_ReturnsFalse()
        {
            bool res1 = BoardSecurityStore.SavePassword("", _testRootKey);
            Assert.IsFalse(res1);

            bool res2 = BoardSecurityStore.SavePassword("   ", _testRootKey);
            Assert.IsFalse(res2);
        }

        [TestMethod]
        public void VerifyPassword_WithCorrectPassword_ReturnsTrue()
        {
            string pass = "MudurSecretPass2026!";
            bool saved = BoardSecurityStore.SavePassword(pass, _testRootKey);
            Assert.IsTrue(saved);

            bool verified = BoardSecurityStore.VerifyPassword(pass, _testRootKey);
            Assert.IsTrue(verified);
        }

        [TestMethod]
        public void VerifyPassword_WithWrongPassword_ReturnsFalse()
        {
            string pass = "CorrectPass123";
            BoardSecurityStore.SavePassword(pass, _testRootKey);

            bool verified = BoardSecurityStore.VerifyPassword("WrongPass456", _testRootKey);
            Assert.IsFalse(verified);
        }

        [TestMethod]
        public void VerifyPassword_WhenNoPasswordStored_AcceptsDefaultFallbacks()
        {
            BoardSecurityStore.ClearPassword(_testRootKey);

            Assert.IsTrue(BoardSecurityStore.VerifyPassword("360360", _testRootKey));
            Assert.IsTrue(BoardSecurityStore.VerifyPassword("123456", _testRootKey));
            Assert.IsFalse(BoardSecurityStore.VerifyPassword("random_wrong_password", _testRootKey));
        }

        [TestMethod]
        public void AuthorizedSession_ActiveWithinTimeWindow()
        {
            BoardSecurityStore.ClearAuthorizedSession();
            Assert.IsFalse(BoardSecurityStore.IsAuthorizedSessionActive());

            // 5 dakika oturum ver
            BoardSecurityStore.SetAuthorizedSession(TimeSpan.FromMinutes(5));
            Assert.IsTrue(BoardSecurityStore.IsAuthorizedSessionActive());

            // Sıfırla
            BoardSecurityStore.ClearAuthorizedSession();
            Assert.IsFalse(BoardSecurityStore.IsAuthorizedSessionActive());
        }
    }
}
