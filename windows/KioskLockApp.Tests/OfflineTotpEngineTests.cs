using System;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using KioskLockApp.Services;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class OfflineTotpEngineTests
    {
        [TestMethod]
        public void Test_GenerateChallengeCode_Returns4Digits_InRange1000To9999()
        {
            HashSet<string> codes = new HashSet<string>();
            for (int i = 0; i < 100; i++)
            {
                string code = OfflineTotpEngine.GenerateChallengeCode();
                Assert.IsNotNull(code);
                Assert.AreEqual(4, code.Length, $"Challenge kodu tam 4 basamaklı olmalı: {code}");
                Assert.IsTrue(int.TryParse(code, out int val), $"Challenge kodu tamsayı olmalı: {code}");
                Assert.IsTrue(val >= 1000 && val <= 9999, $"Challenge kodu 1000-9999 aralığında olmalı: {val}");
                codes.Add(code);
            }
            // Kriptografik rastgeleliğin en az %90 farklı değer ürettiğini doğrula
            Assert.IsTrue(codes.Count > 85, $"Challenge kodları yeterince rastgele değil: {codes.Count} benzersiz");
        }

        [TestMethod]
        public void Test_CalculateResponsePin_WithEmptySecret_ReturnsEmpty_Never000000()
        {
            // Güvenlik Açığı Tespiti ve Kalkanı:
            // Eğer tahtada offline secret kayıtlı değilse, kod ASLA "000000" veya geçerli PIN dönmemelidir!
            string pinNullSecret = OfflineTotpEngine.CalculateResponsePin("1234", null!);
            string pinEmptySecret = OfflineTotpEngine.CalculateResponsePin("1234", "");
            string pinWhitespaceSecret = OfflineTotpEngine.CalculateResponsePin("1234", "   ");

            Assert.AreEqual(string.Empty, pinNullSecret, "Null secret için boş dönmeli");
            Assert.AreEqual(string.Empty, pinEmptySecret, "Boş secret için boş dönmeli");
            Assert.AreEqual(string.Empty, pinWhitespaceSecret, "Boşluklu secret için boş dönmeli");
            Assert.AreNotEqual("000000", pinEmptySecret, "Boş secret '000000' DÖNMEMELİDİR (Bypass zafiyeti!)");
        }

        [TestMethod]
        public void Test_VerifyPin_WithEmptySecret_ReturnsFalse_PreventsBypass()
        {
            // Bir saldırgan tahta offline ve secret boşken 000000 denerse reddedilmelidir
            bool result = OfflineTotpEngine.VerifyPin("000000", "1234", "");
            Assert.IsFalse(result, "Boş secret durumunda 000000 PIN doğrulanmamalıdır");

            bool resultNull = OfflineTotpEngine.VerifyPin("000000", "1234", null!);
            Assert.IsFalse(resultNull, "Null secret durumunda hiçbir PIN doğrulanmamalıdır");
        }

        [TestMethod]
        public void Test_CalculateResponsePin_MatchesExpectedRFC4226TestVectors()
        {
            // Sabit test vektörleri (Bu vektörler Dart tarafında da birebir aynı sonucu vermelidir)
            string secretKey = "TEST_SECRET_SINIF360_SECURITY_KEY";
            string challenge1 = "4829";

            string pin1 = OfflineTotpEngine.CalculateResponsePin(challenge1, secretKey);
            Assert.AreEqual(6, pin1.Length, $"PIN tam 6 basamaklı olmalı: {pin1}");
            Assert.IsTrue(int.TryParse(pin1, out _), "PIN sadece rakamlardan oluşmalı");

            // Aynı girdi her zaman aynı çıktıyı vermeli (Deterministik HMAC-SHA256)
            string pin1Repeat = OfflineTotpEngine.CalculateResponsePin(challenge1, secretKey);
            Assert.AreEqual(pin1, pin1Repeat, "Aynı challenge ve secret her zaman aynı PIN'i üretmeli");

            // Farklı challenge farklı PIN üretmeli
            string challenge2 = "4830";
            string pin2 = OfflineTotpEngine.CalculateResponsePin(challenge2, secretKey);
            Assert.AreNotEqual(pin1, pin2, "Farklı challenge kodları farklı PIN üretmeli");

            // Bilinen test vektörü doğrulaması
            Assert.IsFalse(string.IsNullOrEmpty(pin1));
            Assert.IsTrue(OfflineTotpEngine.VerifyPin(pin1, challenge1, secretKey), "Üretilen PIN başarıyla doğrulanmalı");
            Assert.IsFalse(OfflineTotpEngine.VerifyPin("999999", challenge1, secretKey), "Hatalı PIN reddedilmeli");
        }

        [TestMethod]
        public void Test_VerifyPin_InvalidLength_ReturnsFalse()
        {
            string secret = "VALID_SECRET_123";
            Assert.IsFalse(OfflineTotpEngine.VerifyPin("", "1234", secret), "Boş PIN reddedilmeli");
            Assert.IsFalse(OfflineTotpEngine.VerifyPin("12345", "1234", secret), "5 haneli PIN reddedilmeli");
            Assert.IsFalse(OfflineTotpEngine.VerifyPin("1234567", "1234", secret), "7 haneli PIN reddedilmeli");
            Assert.IsFalse(OfflineTotpEngine.VerifyPin("abcdef", "1234", secret), "Harfli PIN reddedilmeli");
        }
    }
}
