using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace KioskLockApp.Services
{
    /// <summary>
    /// Okul müdürü güvenlik şifresini (PIN) yerel kasada DPAPI (Data Protection API) ile şifreleyerek saklar
    /// ve doğrulama süreçlerini yönetir.
    /// Kurulum / kaldırma koruması (msiexec, setup.exe, install.exe, unins*.exe) bu kasa üzerinden doğrulanır.
    /// </summary>
    public static class BoardSecurityStore
    {
        private static readonly byte[] Entropy = new byte[]
        {
            0x53, 0x69, 0x6E, 0x69, 0x66, 0x33, 0x36, 0x30,
            0x5F, 0x53, 0x65, 0x63, 0x5F, 0x50, 0x49, 0x4E
        }; // "Sinif360_Sec_PIN"

        private const string ShadowVaultPath = @"C:\ProgramData\Microsoft\Crypto\Keys\Sinif360_Vault\board_sec.vault";

        private static string? _memoryCachedPassword = null;
        private static DateTime _authorizedUntil = DateTime.MinValue;
        private static readonly object _lockObj = new object();

        // Test izolasyonu için in-memory override
        private static string? _testOverrideEncrypted = null;

        /// <summary>
        /// Müdür şifresini DPAPI ile şifreleyip Registry ve yerel gölge kasaya kaydeder.
        /// </summary>
        public static bool SavePassword(string plainPassword, RegistryKey? testKey = null)
        {
            if (string.IsNullOrWhiteSpace(plainPassword)) return false;

            plainPassword = plainPassword.Trim();

            lock (_lockObj)
            {
                _memoryCachedPassword = plainPassword;

                try
                {
                    string cipherBase64;
                    if (OperatingSystem.IsWindows() && testKey == null)
                    {
                        byte[] plainBytes = Encoding.UTF8.GetBytes(plainPassword);
                        byte[] cipherBytes;
                        try
                        {
                            cipherBytes = ProtectedData.Protect(plainBytes, Entropy, DataProtectionScope.LocalMachine);
                        }
                        catch
                        {
                            cipherBytes = ProtectedData.Protect(plainBytes, Entropy, DataProtectionScope.CurrentUser);
                        }
                        cipherBase64 = Convert.ToBase64String(cipherBytes);
                    }
                    else
                    {
                        // Test veya cross-platform: SHA-256 tabanlı güvenli simülasyon
                        using var sha = SHA256.Create();
                        byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(plainPassword + ":sinif360_salt"));
                        cipherBase64 = "HASH:" + Convert.ToBase64String(hash);
                    }

                    if (testKey != null)
                    {
                        testKey.SetValue("BoardAdminPasswordVault", cipherBase64, RegistryValueKind.String);
                        _testOverrideEncrypted = cipherBase64;
                        return true;
                    }

                    // 1. Registry'ye yaz (HKCU)
                    SecureSupabase.SetRegistryValue("BoardAdminPasswordVault", cipherBase64);

                    // 2. Gölge kasaya yaz
                    try
                    {
                        string? dir = Path.GetDirectoryName(ShadowVaultPath);
                        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                        {
                            Directory.CreateDirectory(dir);
                        }
                        File.WriteAllText(ShadowVaultPath, cipherBase64);
                    }
                    catch { }

                    return true;
                }
                catch
                {
                    return false;
                }
            }
        }

        /// <summary>
        /// Girilen şifrenin kayıtlı müdür şifresi ile eşleşip eşleşmediğini doğrular.
        /// Henüz şifre tanımlanmamışsa varsayılan müdür şifreleri ("360360", "123456") geçerli sayılır.
        /// </summary>
        public static bool VerifyPassword(string inputPassword, RegistryKey? testKey = null)
        {
            if (string.IsNullOrWhiteSpace(inputPassword)) return false;

            inputPassword = inputPassword.Trim();

            lock (_lockObj)
            {
                // Önce bellek önbelleği
                if (!string.IsNullOrEmpty(_memoryCachedPassword))
                {
                    if (string.Equals(inputPassword, _memoryCachedPassword, StringComparison.Ordinal))
                        return true;
                }

                string? storedCipher = null;
                if (testKey != null)
                {
                    storedCipher = testKey.GetValue("BoardAdminPasswordVault") as string ?? _testOverrideEncrypted;
                }
                else
                {
                    storedCipher = SecureSupabase.GetRegistryValue("BoardAdminPasswordVault");
                    if (string.IsNullOrEmpty(storedCipher) && File.Exists(ShadowVaultPath))
                    {
                        try { storedCipher = File.ReadAllText(ShadowVaultPath).Trim(); } catch { }
                    }
                }

                // Henüz web üzerinden şifre belirlenmemişse varsayılan fallback PIN
                if (string.IsNullOrEmpty(storedCipher))
                {
                    return inputPassword == "360360" || inputPassword == "123456";
                }

                // Test veya HASH formatı kontrolü
                if (storedCipher.StartsWith("HASH:"))
                {
                    string expectedHash = storedCipher.Substring("HASH:".Length);
                    using var sha = SHA256.Create();
                    byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(inputPassword + ":sinif360_salt"));
                    string computedHash = Convert.ToBase64String(hash);
                    return string.Equals(expectedHash, computedHash, StringComparison.Ordinal);
                }

                // DPAPI ile çöz
                if (OperatingSystem.IsWindows())
                {
                    try
                    {
                        byte[] cipherBytes = Convert.FromBase64String(storedCipher);
                        byte[] plainBytes;
                        try
                        {
                            plainBytes = ProtectedData.Unprotect(cipherBytes, Entropy, DataProtectionScope.LocalMachine);
                        }
                        catch
                        {
                            plainBytes = ProtectedData.Unprotect(cipherBytes, Entropy, DataProtectionScope.CurrentUser);
                        }

                        string decrypted = Encoding.UTF8.GetString(plainBytes).Trim();
                        _memoryCachedPassword = decrypted;
                        return string.Equals(inputPassword, decrypted, StringComparison.Ordinal);
                    }
                    catch
                    {
                        return false;
                    }
                }

                return false;
            }
        }

        /// <summary>
        /// Kasada kayıtlı bir müdür şifresi olup olmadığını kontrol eder.
        /// </summary>
        public static bool HasStoredPassword(RegistryKey? testKey = null)
        {
            if (!string.IsNullOrEmpty(_memoryCachedPassword)) return true;

            if (testKey != null)
            {
                var val = testKey.GetValue("BoardAdminPasswordVault") as string ?? _testOverrideEncrypted;
                return !string.IsNullOrEmpty(val);
            }

            string storedCipher = SecureSupabase.GetRegistryValue("BoardAdminPasswordVault");
            if (!string.IsNullOrEmpty(storedCipher)) return true;

            return File.Exists(ShadowVaultPath);
        }

        /// <summary>
        /// Testler veya sıfırlama için kasayı temizler.
        /// </summary>
        public static void ClearPassword(RegistryKey? testKey = null)
        {
            lock (_lockObj)
            {
                _memoryCachedPassword = null;
                _testOverrideEncrypted = null;
                _authorizedUntil = DateTime.MinValue;

                if (testKey != null)
                {
                    try { testKey.DeleteValue("BoardAdminPasswordVault", false); } catch { }
                    return;
                }

                try
                {
                    using var key = Registry.CurrentUser.OpenSubKey(@"Software\SmartBoardLock", true);
                    key?.DeleteValue("BoardAdminPasswordVault", false);
                }
                catch { }

                try
                {
                    if (File.Exists(ShadowVaultPath)) File.Delete(ShadowVaultPath);
                }
                catch { }
            }
        }

        /// <summary>
        /// Doğru şifre girildiğinde geçici bir yetkilendirme penceresi (örn. 5 dakika) başlatır.
        /// Kurulum sürecinde art arda açılan alt işlemler için müdüre tekrar tekrar şifre sormaz.
        /// </summary>
        public static void SetAuthorizedSession(TimeSpan duration)
        {
            lock (_lockObj)
            {
                _authorizedUntil = DateTime.UtcNow.Add(duration);
            }
        }

        /// <summary>
        /// Şu an geçerli bir müdür yetkilendirme oturumu aktif mi?
        /// </summary>
        public static bool IsAuthorizedSessionActive()
        {
            lock (_lockObj)
            {
                return DateTime.UtcNow < _authorizedUntil;
            }
        }

        /// <summary>
        /// Yetkilendirme oturumunu derhal sonlandırır.
        /// </summary>
        public static void ClearAuthorizedSession()
        {
            lock (_lockObj)
            {
                _authorizedUntil = DateTime.MinValue;
            }
        }
    }
}
