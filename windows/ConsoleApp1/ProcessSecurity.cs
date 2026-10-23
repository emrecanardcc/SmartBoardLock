using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace WatchdogService
{
    /// <summary>
    /// WatchdogService Çekirdek Süreç Koruması (Win32 DACL Shield).
    /// Sürecin DACL'ını güncelleyerek Yöneticiler (Administrators) dahil hiç kimsenin
    /// Görev Yöneticisi veya taskkill ile bekçiyi sonlandırmasına izin vermez.
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

        public static bool ProtectCurrentProcess()
        {
            try
            {
                // Everyone ve Administrators için PROCESS_TERMINATE (0x0001) ve PROCESS_SUSPEND_RESUME (0x0800) açıkça DENY
                // Bilgi sorgulama (0x121410) serbest
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

        public static bool UnprotectCurrentProcess()
        {
            try
            {
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
