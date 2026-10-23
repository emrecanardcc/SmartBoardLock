using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace KioskLockApp.Core
{
    /// <summary>
    /// Sınıf360 Çekirdek Süreç Koruması (Win32 DACL Shield).
    /// Sürecin DACL'ını (Discretionary Access Control List) güncelleyerek
    /// Yöneticiler (Administrators) ve standart kullanıcılar dahil hiç kimsenin
    /// Görev Yöneticisi, taskkill veya harici araçlarla süreci sonlandırmasına (PROCESS_TERMINATE)
    /// veya askıya almasına (PROCESS_SUSPEND_RESUME) izin vermez.
    /// Görev Yöneticisi "Görevi Sonlandır" dendiğinde "Erişim Engellendi (Access Denied)" hatası verir.
    /// Sürecin kendi kendine modüllerini ve bilgilerini okuyabilmesi için PROCESS_QUERY_INFORMATION
    /// ve PROCESS_VM_READ izinleri güvenle korunur.
    /// </summary>
    public static class ProcessSecurity
    {
        private const int DACL_SECURITY_INFORMATION = 0x00000004;

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(
            string StringSecurityDescriptor,
            uint StringSDRevision,
            out IntPtr SecurityDescriptor,
            out uint SecurityDescriptorSize);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool SetKernelObjectSecurity(
            IntPtr Handle,
            int SecurityInformation,
            IntPtr pSecurityDescriptor);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr hMem);

        private static bool _isProtected = false;

        /// <summary>
        /// Mevcut süreci Görev Yöneticisi ve taskkill sonlandırmalarına karşı korumaya alır.
        /// </summary>
        public static bool ProtectCurrentProcess()
        {
            try
            {
                // SDDL Açıklaması:
                // D:P -> DACL, Protected (üst nesnelerden izin miras almayı engeller)
                // (D;;0x0801;;;WD) -> Everyone için PROCESS_TERMINATE (0x0001) ve PROCESS_SUSPEND_RESUME (0x0800) açıkça DENY
                // (D;;0x0801;;;BA) -> Administrators için PROCESS_TERMINATE (0x0001) ve PROCESS_SUSPEND_RESUME (0x0800) açıkça DENY
                // (A;;GA;;;SY) -> SYSTEM tam yetki (Generic All)
                // (A;;0x121410;;;WD) -> Everyone için:
                //      SYNCHRONIZE (0x100000), READ_CONTROL (0x20000),
                //      PROCESS_QUERY_LIMITED_INFORMATION (0x1000),
                //      PROCESS_QUERY_INFORMATION (0x0400),
                //      PROCESS_VM_READ (0x0010)
                // Bu sayede .NET çalışma zamanı ve UI kancaları "Erişim Engellendi" hatası almaz,
                // ancak Görev Yöneticisi sonlandırma yapamaz!
                string sddl = "D:P(D;;0x0801;;;WD)(D;;0x0801;;;BA)(A;;GA;;;SY)(A;;0x121410;;;WD)";

                if (!ConvertStringSecurityDescriptorToSecurityDescriptor(sddl, 1, out IntPtr pSd, out _))
                {
                    return false;
                }

                bool result = SetKernelObjectSecurity(GetCurrentProcess(), DACL_SECURITY_INFORMATION, pSd);
                LocalFree(pSd);

                _isProtected = result;
                return result;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Güncelleme veya yetkili kaldırma sırasında sürecin DACL korumasını kaldırır.
        /// </summary>
        public static bool UnprotectCurrentProcess()
        {
            try
            {
                // Standart tam erişim SDDL'i: Everyone ve Administrators Tam Yetki
                string sddl = "D:(A;;GA;;;WD)(A;;GA;;;BA)(A;;GA;;;SY)";

                if (!ConvertStringSecurityDescriptorToSecurityDescriptor(sddl, 1, out IntPtr pSd, out _))
                {
                    return false;
                }

                bool result = SetKernelObjectSecurity(GetCurrentProcess(), DACL_SECURITY_INFORMATION, pSd);
                LocalFree(pSd);

                _isProtected = false;
                return result;
            }
            catch
            {
                return false;
            }
        }

        public static bool IsProtected => _isProtected;
    }
}
