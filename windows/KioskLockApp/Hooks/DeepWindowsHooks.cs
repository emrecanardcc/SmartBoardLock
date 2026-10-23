using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace KioskLockApp.Hooks
{
    public static class DeepWindowsHooks
    {
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_SYSKEYDOWN = 0x0104;

        private static LowLevelProc _keyboardProc = KeyboardHookCallback;
        private static IntPtr _keyboardHookID = IntPtr.Zero;

        public static bool IsLocked = false;

        public static void InitializeHooks()
        {
            if (_keyboardHookID == IntPtr.Zero)
            {
                _keyboardHookID = SetHook(_keyboardProc, WH_KEYBOARD_LL);
            }
        }

        private static IntPtr SetHook(LowLevelProc proc, int idHook)
        {
            try
            {
                IntPtr hMod = IntPtr.Zero;
                try
                {
                    using (Process curProcess = Process.GetCurrentProcess())
                    {
                        var mod = curProcess.MainModule;
                        if (mod != null && !string.IsNullOrEmpty(mod.ModuleName))
                        {
                            hMod = GetModuleHandle(mod.ModuleName);
                        }
                    }
                }
                catch { }

                if (hMod == IntPtr.Zero)
                {
                    hMod = GetModuleHandle(null);
                }

                return SetWindowsHookEx(idHook, proc, hMod, 0);
            }
            catch
            {
                return IntPtr.Zero;
            }
        }

        private delegate IntPtr LowLevelProc(int nCode, IntPtr wParam, IntPtr lParam);

        private static IntPtr KeyboardHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN))
            {
                int vkCode = Marshal.ReadInt32(lParam);

                bool altPressed = (GetKeyState(0xA4) & 0x8000) != 0 || (GetKeyState(0xA5) & 0x8000) != 0 || (GetKeyState(0x12) & 0x8000) != 0;
                bool ctrlPressed = (GetKeyState(0xA2) & 0x8000) != 0 || (GetKeyState(0xA3) & 0x8000) != 0 || (GetKeyState(0x11) & 0x8000) != 0;
                bool shiftPressed = (GetKeyState(0xA0) & 0x8000) != 0 || (GetKeyState(0xA1) & 0x8000) != 0 || (GetKeyState(0x10) & 0x8000) != 0;
                bool winPressed = (GetKeyState(0x5B) & 0x8000) != 0 || (GetKeyState(0x5C) & 0x8000) != 0;

                // =========================================================================
                // 1. MUTLAK KURAL: GÖREV YÖNETİCİSİ KISAYOLU (Ctrl + Shift + Esc)
                // Kilitli veya kilitsiz HİÇBİR KOŞULDA AÇILAMAZ!
                // =========================================================================
                if (ctrlPressed && shiftPressed && vkCode == 0x1B) // VK_ESCAPE
                {
                    return (IntPtr)1; // Görev Yöneticisi doğrudan kısayolunu yut
                }

                // =========================================================================
                // 2. KİLİT EKRANINDA ENGELLENECEK SİSTEM TUŞLARI
                // =========================================================================
                if (IsLocked)
                {
                    // LWIN (0x5B), RWIN (0x5C), Menu/Apps (0x5D)
                    if (vkCode == 0x5B || vkCode == 0x5C || vkCode == 0x5D)
                    {
                        return (IntPtr)1;
                    }

                    // Alt + Tab, Alt + Esc, Alt + F4, Alt + Space
                    if (altPressed && (vkCode == 0x09 || vkCode == 0x1B || vkCode == 0x73 || vkCode == 0x20))
                    {
                        return (IntPtr)1;
                    }

                    // Ctrl + Esc (Başlat menüsü açma)
                    if (ctrlPressed && vkCode == 0x1B)
                    {
                        return (IntPtr)1;
                    }

                    // Ctrl + Alt + Del (Yazılımsal yakalama)
                    if (ctrlPressed && altPressed && vkCode == 0x2E) // VK_DELETE
                    {
                        return (IntPtr)1;
                    }

                    // Windows Tuşu Kombinasyonları: Win+R (Çalıştır), Win+X (Hızlı Menü), Win+E (Explorer), Win+D, Win+S, Win+L
                    if (winPressed || ((GetKeyState(0x5B) & 0x8000) != 0) || ((GetKeyState(0x5C) & 0x8000) != 0))
                    {
                        if (vkCode == 0x52 || // 'R' (Run)
                            vkCode == 0x58 || // 'X' (Power Menu)
                            vkCode == 0x45 || // 'E' (Explorer)
                            vkCode == 0x44 || // 'D' (Desktop)
                            vkCode == 0x53 || // 'S' (Search)
                            vkCode == 0x51 || // 'Q' (Search)
                            vkCode == 0x4C)   // 'L' (Lock)
                        {
                            return (IntPtr)1;
                        }
                    }
                }
            }
            return CallNextHookEx(_keyboardHookID, nCode, wParam, lParam);
        }

        [DllImport("user32.dll")] private static extern short GetKeyState(int nVirtKey);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)][return: MarshalAs(UnmanagedType.Bool)] public static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern IntPtr GetModuleHandle(string? lpModuleName);
    }
}
