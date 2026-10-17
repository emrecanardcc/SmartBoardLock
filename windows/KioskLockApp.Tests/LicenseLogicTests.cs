using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class LicenseLogicTests
    {
        // Tahta ve Web/Mobil uygulamalarında kullanılan lisans hesaplama mantığı
        public static (bool isValid, int remainingDays, string statusBadge) EvaluateLicense(bool isLicensedFlag, DateTime? expiresAt, DateTime nowUtc)
        {
            if (!isLicensedFlag)
            {
                return (false, 0, "Lisans Devre Dışı");
            }

            if (!expiresAt.HasValue)
            {
                // Tarih yoksa ama lisanslıysa aktif kabul edilir
                return (true, 365, "Aktif");
            }

            DateTime expUtc = expiresAt.Value.ToUniversalTime();
            if (nowUtc > expUtc)
            {
                return (false, 0, "Süresi Doldu");
            }

            int days = (int)Math.Max(0, (expUtc - nowUtc).TotalDays);
            if (days <= 15)
            {
                return (true, days, $"Son {days} Gün");
            }

            return (true, days, "Aktif");
        }

        [TestMethod]
        public void Test_License_ExpiredDate_EvaluatesToInvalid()
        {
            DateTime nowUtc = new DateTime(2026, 10, 17, 12, 0, 0, DateTimeKind.Utc);
            DateTime pastDate = new DateTime(2026, 10, 16, 12, 0, 0, DateTimeKind.Utc);

            var (isValid, remainingDays, statusBadge) = EvaluateLicense(true, pastDate, nowUtc);

            Assert.IsFalse(isValid, "Geçmiş tarihli lisans geçersiz olmalı");
            Assert.AreEqual(0, remainingDays, "Süresi dolan lisansın kalan günü 0 olmalı");
            Assert.AreEqual("Süresi Doldu", statusBadge);
        }

        [TestMethod]
        public void Test_License_FlagFalse_AlwaysEvaluatesToInvalid()
        {
            DateTime nowUtc = new DateTime(2026, 10, 17, 12, 0, 0, DateTimeKind.Utc);
            DateTime futureDate = new DateTime(2027, 10, 17, 12, 0, 0, DateTimeKind.Utc);

            // is_licensed = false ise tarih gelecekte olsa bile lisans geçersiz olmalıdır
            var (isValid, remainingDays, statusBadge) = EvaluateLicense(false, futureDate, nowUtc);

            Assert.IsFalse(isValid, "is_licensed false iken lisans geçersiz olmalı");
            Assert.AreEqual("Lisans Devre Dışı", statusBadge);
        }

        [TestMethod]
        public void Test_License_WarningWindow_Last15Days()
        {
            DateTime nowUtc = new DateTime(2026, 10, 17, 12, 0, 0, DateTimeKind.Utc);
            DateTime soonDate = nowUtc.AddDays(10);

            var (isValid, remainingDays, statusBadge) = EvaluateLicense(true, soonDate, nowUtc);

            Assert.IsTrue(isValid, "Son 15 gün içindeki lisans hala geçerlidir");
            Assert.AreEqual(10, remainingDays);
            Assert.AreEqual("Son 10 Gün", statusBadge);
        }

        [TestMethod]
        public void Test_License_ActiveOneYear_AccurateDays()
        {
            DateTime nowUtc = new DateTime(2026, 10, 17, 12, 0, 0, DateTimeKind.Utc);
            DateTime oneYearLater = nowUtc.AddDays(365);

            var (isValid, remainingDays, statusBadge) = EvaluateLicense(true, oneYearLater, nowUtc);

            Assert.IsTrue(isValid);
            Assert.AreEqual(365, remainingDays);
            Assert.AreEqual("Aktif", statusBadge);
        }
    }
}
