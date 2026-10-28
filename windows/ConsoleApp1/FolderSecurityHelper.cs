using System;
using System.Runtime.Versioning;
using Microsoft.Win32;

namespace WatchdogService
{
    [SupportedOSPlatform("windows")]
    internal static class FolderSecurityHelper
    {
        /// <summary>
        /// Kritik Windows sistem politikalarını hem HKCU hem de HKLM düzeyinde kayıt defterine yazar:
        /// 1. Policies\System\DisableTaskMgr = 1 (Görev Yöneticisi açılmasını engeller)
        /// 2. Policies\System\DisableLockWorkstation = 1 (Win+L kilit ekranını engeller)
        /// 3. Policies\Explorer\NoRun = 1 (Win+R / Çalıştır iletişim kutusunu engeller)
        /// 4. Policies\ActiveDesktop\NoChangingWallPaper = 1 (Masaüstü duvar kâğıdı değiştirilmesini engeller)
        /// </summary>
        public static void EnforceSystemPolicies()
        {
            // 1. Policies\System (HKCU)
            try
            {
                using var rkSys = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSys?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSys?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 2. Policies\System (HKLM)
            try
            {
                using var rkSysLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System");
                rkSysLm?.SetValue("DisableTaskMgr", 1, RegistryValueKind.DWord);
                rkSysLm?.SetValue("DisableLockWorkstation", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 3. Policies\Explorer (HKCU)
            try
            {
                using var rkExp = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExp?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 4. Policies\Explorer (HKLM)
            try
            {
                using var rkExpLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer");
                rkExpLm?.SetValue("NoRun", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 5. Policies\ActiveDesktop (HKCU)
            try
            {
                using var rkAd = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAd?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 6. Policies\ActiveDesktop (HKLM)
            try
            {
                using var rkAdLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop");
                rkAdLm?.SetValue("NoChangingWallPaper", 1, RegistryValueKind.DWord);
            }
            catch { }

            // 7. Policies\EdgeUI (HKCU & HKLM) - Touchscreen Edge Swipe Block
            try
            {
                using var rkEdge = Registry.CurrentUser.CreateSubKey(@"Software\Policies\Microsoft\Windows\EdgeUI");
                rkEdge?.SetValue("AllowEdgeSwipe", 0, RegistryValueKind.DWord);
            }
            catch { }

            try
            {
                using var rkEdgeLm = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Policies\Microsoft\Windows\EdgeUI");
                rkEdgeLm?.SetValue("AllowEdgeSwipe", 0, RegistryValueKind.DWord);
            }
            catch { }
        }

        public static void RestoreSystemPolicies()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\System", true);
                key?.DeleteValue("DisableTaskMgr", false);
                key?.DeleteValue("DisableLockWorkstation", false);
            }
            catch { }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", true);
                key?.DeleteValue("NoRun", false);
            }
            catch { }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true);
                key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", true);
                key?.DeleteValue("DisableTaskMgr", false);
                key?.DeleteValue("DisableLockWorkstation", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", true);
                key?.DeleteValue("NoRun", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop", true);
                key?.DeleteValue("NoChangingWallPaper", false);
            }
            catch { }

            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Policies\Microsoft\Windows\EdgeUI", true);
                key?.DeleteValue("AllowEdgeSwipe", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Policies\Microsoft\Windows\EdgeUI", true);
                key?.DeleteValue("AllowEdgeSwipe", false);
            }
            catch { }

            try
            {
                using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", true);
                key?.SetValue("Shell", "explorer.exe", RegistryValueKind.String);
            }
            catch { }

            try
            {
                using var keyCu = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon", true);
                keyCu?.DeleteValue("Shell", false);
            }
            catch { }
        }
    }
}
